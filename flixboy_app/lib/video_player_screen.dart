import 'app_transitions.dart';
import 'firebase_service.dart'; 
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


class SubtitleEntry {
  final Duration start;
  final Duration end;
  final String   text;
  const SubtitleEntry({required this.start, required this.end, required this.text});
}

class SubtitleTrack {
  final String label;
  final String language;
  final String url;
  const SubtitleTrack({required this.label, required this.language, required this.url});
}

// ══════════════════════════════════════════════════════════════
//  PARSER .srt / .vtt
// ══════════════════════════════════════════════════════════════

class SubtitleParser {
  static List<SubtitleEntry> parse(String content) =>
      content.contains('WEBVTT') ? _parseVtt(content) : _parseSrt(content);

  static Duration _dur(String s) {
    s = s.trim().replaceAll(',', '.');
    final p = s.split(':');
    if (p.length == 3) {
      final sm = p[2].split('.');
      return Duration(
        hours:        int.parse(p[0]),
        minutes:      int.parse(p[1]),
        seconds:      int.parse(sm[0]),
        milliseconds: sm.length > 1 ? int.parse(sm[1].padRight(3,'0').substring(0,3)) : 0,
      );
    }
    return Duration.zero;
  }

  static List<SubtitleEntry> _parseSrt(String content) {
    final entries = <SubtitleEntry>[];
    for (final block in content.trim().split(RegExp(r'\n\s*\n'))) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;
      final tl = lines.firstWhere((l) => l.contains('-->'), orElse: () => '');
      if (tl.isEmpty) continue;
      final times = tl.split('-->');
      if (times.length < 2) continue;
      final text = lines.sublist(lines.indexOf(tl) + 1).join('\n').trim();
      entries.add(SubtitleEntry(start: _dur(times[0]), end: _dur(times[1]), text: text));
    }
    return entries;
  }

  static List<SubtitleEntry> _parseVtt(String content) {
    final entries = <SubtitleEntry>[];
    final lines = content.split('\n');
    int i = 0;
    while (i < lines.length) {
      if (lines[i].contains('-->')) {
        final times = lines[i].split('-->');
        if (times.length >= 2) {
          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty && !lines[i].contains('-->')) {
            textLines.add(lines[i].trim());
            i++;
          }
          if (textLines.isNotEmpty) {
            entries.add(SubtitleEntry(
              start: _dur(times[0]),
              end:   _dur(times[1].split(' ')[0]),
              text:  textLines.join('\n'),
            ));
          }
          continue;
        }
      }
      i++;
    }
    return entries;
  }
}

// ══════════════════════════════════════════════════════════════
//  VIDEO PLAYER SCREEN
// ══════════════════════════════════════════════════════════════

class VideoPlayerScreen extends StatefulWidget {
  final String       videoUrl;
  final String       title;
  final ContentModel content;

  // Subtítulos opcionales
  final List<SubtitleTrack> subtitleTracks;

  // Skip intro / recap (timestamps opcionales)
  final Duration? introStart;
  final Duration? introEnd;
  final Duration? recapEnd;

  // Metadatos de episodio (para series)
  final int?    seasonNum;
  final int?    episodeNum;
  final String? episodeTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.content,
    this.subtitleTracks = const [],
    this.introStart,
    this.introEnd,
    this.recapEnd,
    this.seasonNum,
    this.episodeNum,
    this.episodeTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {

  late final Player          _player;
  late final VideoController _controller;

  // ── UI ──────────────────────────────────────────────────────
  bool   _showControls = true;
  Timer? _hideTimer;
  Timer? _progressTimer;

  // ── Progreso ────────────────────────────────────────────────
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double   _volume   = 1.0;
  double   _speed    = 1.0;
  bool     _isMuted  = false;
  bool     _isFullscreen = false;

  // ── Subtítulos ──────────────────────────────────────────────
  List<SubtitleEntry> _subtitles      = [];
  SubtitleTrack?      _activeTrack;
  String              _currentSub     = '';
  bool                _showSubs       = true;
  double              _subSize        = 16.0;

  // ── Skip ────────────────────────────────────────────────────
  bool _showSkipIntro = false;
  bool _showSkipRecap = false;

  // ── Red ─────────────────────────────────────────────────────
  String               _netQuality    = 'HD';
  StreamSubscription?  _connectSub;

  // ── NEXT EPISODE ────────────────────────────────────────────
  ContentModel? _nextEpisode;
  bool          _overlayShown = false;

  static const _accentColor  = Color(0xFFE50914);
  static const _progressKey  = 'flixboy_progress_';

  // ════════════════════════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
    _loadNextEpisode();
    _checkConnectivity();
    WakelockPlus.enable();
    _setLandscape();
  }

  Future<void> _initPlayer() async {
    _player     = Player();
    _controller = VideoController(_player);

    final prefs   = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt('$_progressKey${widget.content.id}') ?? 0;

    await _player.open(Media(widget.videoUrl));

    // Reanudar desde donde quedó
    if (savedMs > 10000) {
      await Future.delayed(const Duration(milliseconds: 800));
      await _player.seek(Duration(milliseconds: savedMs));
    }

    // Listeners
    _player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        _updateSub(pos);
        _checkSkip(pos);
        _checkNextEpisode(pos);     // ← lógica de autoplay
      });
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    // Guardar progreso cada 5s
    _progressTimer = Timer.periodic(
      const Duration(seconds: 5), (_) => _saveProgress(),
    );

    // Subtítulo inicial
    if (widget.subtitleTracks.isNotEmpty) {
      _loadSubtitleTrack(widget.subtitleTracks.first);
    }

    _startHideTimer();
  }

  // ── Carga episodio siguiente ─────────────────────────────────
Future<void> _loadNextEpisode() async {
    try {
      if (widget.content.type != 'Serie') return;

      final seriesId = widget.content.seriesId.isNotEmpty
          ? widget.content.seriesId
          : widget.content.id;

      final episodes = await ContentService.getEpisodes(seriesId);

      final idx = episodes.indexWhere((e) => e.videoUrl == widget.videoUrl);
      if (idx >= 0 && idx < episodes.length - 1) {
        if (mounted) setState(() => _nextEpisode = episodes[idx + 1]);
      }
    } catch (_) {}
  }
  // ── Dispara el overlay cuando el video llega al 90% o ≤30s ──
  void _checkNextEpisode(Duration pos) {
    if (_duration.inSeconds == 0) return;
    if (_nextEpisode == null)     return;
    if (_overlayShown)            return;

    final pct = pos.inSeconds / _duration.inSeconds;

    if (pct >= 0.985) {
      setState(() => _overlayShown = true);
    }
  }

  // ── Navega al siguiente episodio ─────────────────────────────
  void _playNextEpisode(ContentModel next) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      AppRoute.playerFade(
        VideoPlayerScreen(
          videoUrl: next.videoUrl,
          title:    next.title,
          content:  next.copyWith(seriesId: widget.content.seriesId),
        ),
      ),
    );
  }

  // ── Subtítulos ───────────────────────────────────────────────
  Future<void> _loadSubtitleTrack(SubtitleTrack track) async {
    setState(() { _activeTrack = track; _subtitles = []; });
    try {
      final client = HttpClient();
      final req    = await client.getUrl(Uri.parse(track.url));
      final res    = await req.close();
      final raw    = await res.transform(const SystemEncoding().decoder).join();
      final parsed = SubtitleParser.parse(raw);
      if (mounted) setState(() => _subtitles = parsed);
    } catch (e) { debugPrint('Subtitle error: $e'); }
  }

  void _updateSub(Duration pos) {
    if (_subtitles.isEmpty) { _currentSub = ''; return; }
    _currentSub = _subtitles
        .where((s) => pos >= s.start && pos <= s.end)
        .firstOrNull?.text ?? '';
  }

  // ── Skip intro / recap ────────────────────────────────────────
  void _checkSkip(Duration pos) {
    if (widget.introStart != null && widget.introEnd != null) {
      _showSkipIntro = pos >= widget.introStart! && pos < widget.introEnd!;
    }
    if (widget.recapEnd != null) {
      _showSkipRecap = pos < widget.recapEnd!;
    }
  }

  // ── Conectividad ─────────────────────────────────────────────
  void _checkConnectivity() {
    _connectSub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      setState(() => _netQuality =
          result.contains(ConnectivityResult.wifi) ? 'HD' : 'SD');
    });
  }

  // ── Progreso ─────────────────────────────────────────────────
  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_progressKey${widget.content.id}',
      _position.inMilliseconds,
    );
  }

  // ── Controles ────────────────────────────────────────────────
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_overlayShown) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  // ── Orientación ──────────────────────────────────────────────
  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
      _saveProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _connectSub?.cancel();
    _saveProgress();
    _player.dispose();
    WakelockPlus.disable();
    _restorePortrait();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  double get _progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          d.globalPosition.dx < w / 2
              ? _player.seek(_position - const Duration(seconds: 10))
              : _player.seek(_position + const Duration(seconds: 10));
        },
        child: Stack(children: [

          // ── VIDEO ─────────────────────────────────────────
          Positioned.fill(child: Video(controller: _controller, fill: Colors.black)),

          // ── SUBTÍTULOS ────────────────────────────────────
          if (_showSubs && _currentSub.isNotEmpty)
            Positioned(
              bottom: _showControls ? 110 : 40,
              left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_currentSub,
                  style: TextStyle(color: Colors.white, fontSize: _subSize, height: 1.4,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
                  textAlign: TextAlign.center),
              ),
            ),

          // ── SKIP INTRO ───────────────────────────────────
          if (_showSkipIntro)
            Positioned(
              bottom: _showControls ? 120 : 36,
              right: 24,
              child: _SkipButton(
                label: 'Saltar intro',
                onTap: () { _player.seek(widget.introEnd!); setState(() => _showSkipIntro = false); },
              ),
            ),

          // ── SKIP RECAP ───────────────────────────────────
          if (_showSkipRecap && !_showSkipIntro)
            Positioned(
              bottom: _showControls ? 120 : 36,
              right: 24,
              child: _SkipButton(
                label: 'Saltar recapitulación',
                onTap: () { _player.seek(widget.recapEnd!); setState(() => _showSkipRecap = false); },
              ),
            ),

          // ── CONTROLES ────────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildControls(),
          ),

          // ── BADGE CALIDAD ─────────────────────────────────
          if (_showControls)
            Positioned(
              top: 56, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(_netQuality,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),

          // ════════════════════════════════════════════════
          //  NEXT EPISODE OVERLAY ← NETFLIX STYLE
          // ════════════════════════════════════════════════
          if (_overlayShown && _nextEpisode != null)
            _NextEpisodeOverlay(
              nextEpisode:      _nextEpisode!,
              countdownSeconds: 10,
              onPlayNext:       () => _playNextEpisode(_nextEpisode!),
              onCancel:         () => setState(() => _overlayShown = false),
            ),

        ]),
      ),
    );
  }

  // ── CONTROLES OVERLAY ────────────────────────────────────────
  Widget _buildControls() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
        stops: [0.0, 0.25, 0.75, 1.0],
      ),
    ),
    child: SafeArea(child: Column(children: [

      // ── TOP BAR ────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
              if (widget.seasonNum != null)
                Text('T${widget.seasonNum} · E${widget.episodeNum}${widget.episodeTitle != null ? ' · ${widget.episodeTitle}' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          )),
          // PiP
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
            onPressed: () {},
          ),
          // Subtítulos
          IconButton(
            icon: Icon(Icons.subtitles_outlined,
                color: _showSubs ? _accentColor : Colors.white),
            onPressed: _showSubtitleSheet,
          ),
          // Velocidad
          GestureDetector(
            onTap: _showSpeedSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _speed != 1.0 ? _accentColor.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _speed != 1.0 ? _accentColor : Colors.white38),
              ),
              child: Text('${_speed}x',
                style: TextStyle(
                  color: _speed != 1.0 ? _accentColor : Colors.white,
                  fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
        ]),
      ),

      const Spacer(),

      // ── PLAY / PAUSE + SEEK ──────────────────────────────
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _SeekBtn(icon: Icons.replay_10,
            onTap: () => _player.seek(_position - const Duration(seconds: 10))),
        const SizedBox(width: 28),
        StreamBuilder<bool>(
          stream: _player.stream.playing,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return GestureDetector(
              onTap: () => playing ? _player.pause() : _player.play(),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 38),
              ),
            );
          },
        ),
        const SizedBox(width: 28),
        _SeekBtn(icon: Icons.forward_10,
            onTap: () => _player.seek(_position + const Duration(seconds: 10))),
      ]),

      const Spacer(),

      // ── BOTTOM BAR ──────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(_fmt(_duration), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   _accentColor,
              inactiveTrackColor: Colors.white24,
              thumbColor:         Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _progress,
              onChanged: (v) => _player.seek(
                  Duration(milliseconds: (v * _duration.inMilliseconds).round())),
              onChangeStart: (_) => _hideTimer?.cancel(),
              onChangeEnd:   (_) => _startHideTimer(),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            IconButton(
              icon: Icon(_isMuted || _volume == 0
                  ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white, size: 22),
              onPressed: () {
                setState(() => _isMuted = !_isMuted);
                _player.setVolume(_isMuted ? 0 : _volume * 100);
              },
            ),
            
             
            IconButton(
              icon: Icon(_isFullscreen
                  ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white, size: 26),
              onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
            ),
          ]),
        ]),
      ),

    ])),
  );

  // ── SHEET VELOCIDAD ─────────────────────────────────────────
  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Velocidad de reproducción',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ListTile(
          title: Text('${s}x', style: TextStyle(
              color: s == _speed ? _accentColor : Colors.white,
              fontWeight: s == _speed ? FontWeight.bold : FontWeight.normal)),
          trailing: s == _speed
              ? const Icon(Icons.check, color: _accentColor) : null,
          onTap: () {
            _player.setRate(s);
            setState(() => _speed = s);
            Navigator.pop(context);
          },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── SHEET SUBTÍTULOS ─────────────────────────────────────────
  void _showSubtitleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Subtítulos',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Mostrar subtítulos', style: TextStyle(color: Colors.white)),
            value: _showSubs, activeColor: _accentColor,
            onChanged: (v) { setState(() => _showSubs = v); setLocal(() {}); },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              const Text('Tamaño', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Expanded(child: Slider(
                value: _subSize, min: 12, max: 24, divisions: 6,
                activeColor: _accentColor,
                onChanged: (v) { setState(() => _subSize = v); setLocal(() {}); },
              )),
              Text('${_subSize.toInt()}px', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          if (widget.subtitleTracks.isNotEmpty) ...[
            const Divider(color: Color(0xFF333333)),
            ListTile(
              title: const Text('Sin subtítulos', style: TextStyle(color: Colors.white)),
              trailing: _activeTrack == null
                  ? const Icon(Icons.check, color: _accentColor) : null,
              onTap: () {
                setState(() { _activeTrack = null; _subtitles = []; _currentSub = ''; });
                Navigator.pop(context);
              },
            ),
            ...widget.subtitleTracks.map((t) => ListTile(
              title: Text(t.label, style: TextStyle(
                  color: _activeTrack?.language == t.language ? _accentColor : Colors.white)),
              subtitle: Text(t.language,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: _activeTrack?.language == t.language
                  ? const Icon(Icons.check, color: _accentColor) : null,
              onTap: () { _loadSubtitleTrack(t); Navigator.pop(context); },
            )),
          ],
          const SizedBox(height: 16),
        ],
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  NEXT EPISODE OVERLAY — estilo Netflix
// ══════════════════════════════════════════════════════════════

class _NextEpisodeOverlay extends StatefulWidget {
  final ContentModel nextEpisode;
  final VoidCallback onPlayNext;
  final VoidCallback onCancel;
  final int          countdownSeconds;

  const _NextEpisodeOverlay({
    required this.nextEpisode,
    required this.onPlayNext,
    required this.onCancel,
    this.countdownSeconds = 5,
  });

  @override
  State<_NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<_NextEpisodeOverlay>
    with SingleTickerProviderStateMixin {

  late AnimationController _animCtrl;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;

  Timer? _timer;
  late int _secs;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _secs = widget.countdownSeconds;

    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fade  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _animCtrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secs--);
      if (_secs <= 0) { t.cancel(); _trigger(widget.onPlayNext); }
    });
  }

  Future<void> _trigger(VoidCallback cb) async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    await _animCtrl.reverse();
    cb();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      right:  16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [

              // Etiqueta "A continuación"
              Padding(
                padding: const EdgeInsets.only(bottom: 5, right: 4),
                child: Text('A continuación',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
              ),

              // Tarjeta
              Container(
                width: 270,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  Row(children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                      child: SizedBox(
                        width: 105, height: 62,
                        child: widget.nextEpisode.imagenUrl.isNotEmpty
                            ? Image.network(
                                widget.nextEpisode.imagenUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbFallback(),
                              )
                            : _thumbFallback(),
                      ),
                    ),

                    // Info + botones
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Episodio siguiente',
                                style: TextStyle(color: Colors.grey, fontSize: 9)),
                            const SizedBox(height: 2),
                            Text(widget.nextEpisode.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w500, height: 1.3)),
                            const SizedBox(height: 8),
                            Row(children: [
                              // Botón "Reproducir (X)"
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _trigger(widget.onPlayNext),
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.play_arrow_rounded,
                                            color: Colors.black, size: 15),
                                        const SizedBox(width: 3),
                                        Text('Reproducir ($_secs)',
                                          style: const TextStyle(color: Colors.black,
                                              fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Botón cancelar
                              GestureDetector(
                                onTap: () => _trigger(widget.onCancel),
                                child: Container(
                                  height: 28,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.45)),
                                  ),
                                  child: const Center(
                                    child: Text('Cancelar',
                                        style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ]),

                  // Barra de progreso del countdown (roja, se vacía)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 0.0),
                      duration: Duration(seconds: widget.countdownSeconds),
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFE50914)),
                      ),
                    ),
                  ),

                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
    color: const Color(0xFF2A2A2A),
    child: const Icon(Icons.play_circle_outline, color: Colors.white30, size: 26),
  );
}

// ══════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════

class _SeekBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _SeekBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color:  Colors.white.withValues(alpha: 0.1),
        shape:  BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    ),
  );
}

class _SkipButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _SkipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  EJEMPLO DE USO desde DetailScreen
// ══════════════════════════════════════════════════════════════
//
//  Navigator.push(context, AppRoute.playerFade(
//    VideoPlayerScreen(
//      videoUrl: content.videoUrl,
//      title:    content.title,
//      content:  content,
//      subtitleTracks: [
//        SubtitleTrack(label: 'Español', language: 'es',
//            url: 'https://tustorage.com/subs/pelicula-es.vtt'),
//      ],
//      introStart: const Duration(seconds: 90),
//      introEnd:   const Duration(seconds: 210),
//      seasonNum:  1,
//      episodeNum: 3,
//      episodeTitle: 'El umbral',
//    ),
//  ));