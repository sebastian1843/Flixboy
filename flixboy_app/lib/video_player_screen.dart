// lib/video_player_screen.dart
//
// Reproductor profesional Flixboy — Fase 2
// Funcionalidades:
//   • Continuar viendo (retoma desde el punto guardado)
//   • Guarda progreso cada 5 segundos en Firestore
//   • Pantalla completa real (landscape + immersive)
//   • Auto-ocultar controles tras 3 segundos
//   • Gesto horizontal para seek
//   • Slider de progreso con preview de tiempo
//   • Soporte para episodios de series
//   • Animación suave de controles (fade + slide)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'firebase_service.dart';
import 'progress_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String       videoUrl;
  final String       title;
  final ContentModel content;

  // Opcionales para series
  final int?    seasonNum;
  final int?    episodeNum;
  final String? episodeTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.content,
    this.seasonNum,
    this.episodeNum,
    this.episodeTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;

  bool _isInitialized = false;
  bool _showControls  = true;
  bool _isFullscreen  = false;
  bool _isDragging    = false;

  Timer? _hideTimer;
  Timer? _saveTimer;    // guarda progreso cada 5 segundos

  // Seek por gesto
  double   _dragStartX    = 0;
  Duration _dragStartPos  = Duration.zero;
  Duration? _seekPreview;

  // Animaciones de controles
  late AnimationController _ctrlAnim;
  late Animation<double>   _ctrlFade;
  late Animation<Offset>   _topSlide;
  late Animation<Offset>   _bottomSlide;

  // ── Ciclo de vida ────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ctrlAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _ctrlFade    = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrlAnim, curve: Curves.easeOut));
    _topSlide    = Tween<Offset>(
            begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrlAnim, curve: Curves.easeOut));
    _bottomSlide = Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrlAnim, curve: Curves.easeOut));
    _ctrlAnim.forward();

    _enterFullscreen();
    _initPlayer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _saveProgress(); // guardar al salir
    _ctrlAnim.dispose();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _exitFullscreen();
    super.dispose();
  }

  // ── Inicializar reproductor ───────────────────────────────

  Future<void> _initPlayer() async {
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _controller.initialize();
    if (!mounted) return;

    // Retomar desde donde quedó
    final saved = await ProgressService.get(widget.content.id);
    if (saved != null && saved.isStarted && !saved.isFinished) {
      await _controller.seekTo(Duration(seconds: saved.position));
    }

    _controller.addListener(_videoListener);
    await _controller.play();

    setState(() => _isInitialized = true);
    _scheduleHide();

    // Guardar progreso cada 5 segundos
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_controller.value.isPlaying) _saveProgress();
    });
  }

  // ── Guardar progreso en Firestore ─────────────────────────

  Future<void> _saveProgress() async {
    if (!_isInitialized) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inSeconds == 0) return;

    await ProgressService.save(
      content:      widget.content,
      position:     pos,
      duration:     dur,
      seasonNum:    widget.seasonNum,
      episodeNum:   widget.episodeNum,
      episodeTitle: widget.episodeTitle,
    );
  }

  // ── Listener de video ─────────────────────────────────────

  void _videoListener() {
    if (!mounted) return;
    final val = _controller.value;
    // Al terminar mostrar controles permanentemente
    if (val.position >= val.duration && val.duration > Duration.zero) {
      _saveProgress();
      _showControlsTemporarily(forever: true);
    }
    setState(() {});
  }

  // ── Pantalla completa ────────────────────────────────────

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void _toggleFullscreen() =>
      _isFullscreen ? _exitFullscreen() : _enterFullscreen();

  // ── Controles: mostrar / ocultar ─────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying && !_isDragging) {
        _hideControls();
      }
    });
  }

  void _showControlsTemporarily({bool forever = false}) {
    if (!_showControls) {
      setState(() => _showControls = true);
      _ctrlAnim.forward();
    }
    if (!forever) _scheduleHide();
  }

  void _hideControls() {
    _ctrlAnim.reverse().then((_) {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    if (_showControls) {
      _hideControls();
      _hideTimer?.cancel();
    } else {
      _showControlsTemporarily();
    }
  }

  // ── Play / Pause ─────────────────────────────────────────

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _showControlsTemporarily();
  }

  // ── Seek ─────────────────────────────────────────────────

  void _seekBy(Duration delta) {
    final pos    = _controller.value.position + delta;
    final dur    = _controller.value.duration;
    final newPos = pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos);
    _controller.seekTo(newPos);
    _showControlsTemporarily();
  }

  // ── Gestos horizontales ───────────────────────────────────

  void _onHDragStart(DragStartDetails d) {
    _dragStartX   = d.globalPosition.dx;
    _dragStartPos = _controller.value.position;
    _isDragging   = true;
    _hideTimer?.cancel();
    _showControlsTemporarily(forever: true);
  }

 void _onHDragUpdate(DragUpdateDetails d) {
  final w = MediaQuery.of(context).size.width;
  final delta = d.globalPosition.dx - _dragStartX;
  final secs = (delta / w * 120).round();

  final dur = _controller.value.duration;
  var newPos = _dragStartPos + Duration(seconds: secs);

  if (newPos < Duration.zero) {
    newPos = Duration.zero;
  }

  if (newPos > dur) {
    newPos = dur;
  }

  setState(() => _seekPreview = newPos);
}

  void _onHDragEnd(DragEndDetails _) {
    if (_seekPreview != null) {
      _controller.seekTo(_seekPreview!);
      _seekPreview = null;
    }
    _isDragging = false;
    _scheduleHide();
  }

  // ── Formato de tiempo ─────────────────────────────────────

  String _fmt(Duration d) {
    final h  = d.inHours;
    final m  = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Título a mostrar en el reproductor ────────────────────

  String get _displayTitle {
    if (widget.seasonNum != null && widget.episodeNum != null) {
      final ep = widget.episodeTitle ?? '';
      return '${widget.title}  ·  T${widget.seasonNum} E${widget.episodeNum}${ep.isNotEmpty ? " — $ep" : ""}';
    }
    return widget.title;
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      onTap: _onTap,
      onHorizontalDragStart: _onHDragStart,
      onHorizontalDragUpdate: _onHDragUpdate,
      onHorizontalDragEnd: _onHDragEnd,
      child: Stack(children: [

        // ── Video — ocupa toda la pantalla ──
        if (_isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:  _controller.value.size.width,
                height: _controller.value.size.height,
                child:  VideoPlayer(_controller),
              ),
            ),
          ),

        // ── Buffering ──
        if (_isInitialized && _controller.value.isBuffering)
          const Center(child: CircularProgressIndicator(
              color: Color(0xFFE50914), strokeWidth: 2.5)),

        // ── Cargando inicial ──
        if (!_isInitialized)
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                color: Color(0xFFE50914), strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(widget.title,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
          ])),

        // ── Preview seek ──
        if (_seekPreview != null)
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_fmt(_seekPreview!),
                style: const TextStyle(
                    color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()])),
          )),

        // ── Controles ──
        if (_showControls) ...[

          // Gradientes
          FadeTransition(opacity: _ctrlFade,
            child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.25, 0.65, 1.0],
              ),
            ))),

          // ── Top bar ──
          Positioned(top: 0, left: 0, right: 0,
            child: SlideTransition(position: _topSlide,
              child: FadeTransition(opacity: _ctrlFade,
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
                      onPressed: () {
                        _saveProgress();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(child: Text(_displayTitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center)),
                    IconButton(
                      icon: Icon(
                        _isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white, size: 24,
                      ),
                      onPressed: _toggleFullscreen,
                    ),
                  ]),
                )),
              ),
            ),
          ),

          // ── Centro: controles ──
          Center(child: FadeTransition(opacity: _ctrlFade,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _SeekButton(icon: Icons.replay_10_rounded,
                  onPressed: () => _seekBy(const Duration(seconds: -10))),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: _togglePlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.4),
                      blurRadius: 20, spreadRadius: 2,
                    )],
                  ),
                  child: Icon(
                    _isInitialized && _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white, size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              _SeekButton(icon: Icons.forward_10_rounded,
                  onPressed: () => _seekBy(const Duration(seconds: 10))),
            ]),
          )),

          // ── Bottom bar ──
          Positioned(bottom: 0, left: 0, right: 0,
            child: SlideTransition(position: _bottomSlide,
              child: FadeTransition(opacity: _ctrlFade,
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (_, value, __) {
                      final pos = _seekPreview ?? value.position;
                      final dur = value.duration;
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                            activeTrackColor: const Color(0xFFE50914),
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.25),
                            thumbColor: const Color(0xFFE50914),
                            overlayColor: const Color(0xFFE50914)
                                .withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: dur.inMilliseconds > 0
                                ? pos.inMilliseconds.toDouble()
                                    .clamp(0, dur.inMilliseconds.toDouble())
                                : 0,
                            max: dur.inMilliseconds > 0
                                ? dur.inMilliseconds.toDouble()
                                : 1,
                            onChangeStart: (_) {
                              _isDragging = true;
                              _hideTimer?.cancel();
                            },
                            onChanged: (v) => setState(() =>
                                _seekPreview =
                                    Duration(milliseconds: v.toInt())),
                            onChangeEnd: (v) {
                              _controller.seekTo(
                                  Duration(milliseconds: v.toInt()));
                              _seekPreview = null;
                              _isDragging  = false;
                              _scheduleHide();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              Text(_fmt(dur),
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ]);
                    },
                  ),
                )),
              ),
            ),
          ),
        ],
      ]),
    ),
  );
}

// ── Botón seek ────────────────────────────────────────────────

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _SeekButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(32),
      splashColor: Colors.white.withValues(alpha: 0.15),
      child: Padding(padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 36)),
    ),
  );
}