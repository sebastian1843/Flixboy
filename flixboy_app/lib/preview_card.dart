// lib/preview_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'firebase_service.dart';
import 'main.dart';

class PreviewCard extends StatefulWidget {
  final ContentModel content;
  final double width;
  final double height;
  final VoidCallback onTap;

  const PreviewCard({
    super.key,
    required this.content,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard>
    with SingleTickerProviderStateMixin {
  Player? _player;
  VideoController? _controller;
  bool _isPlaying   = false;
  bool _isBuffering = false;

  Timer? _pressTimer;
  bool _pressing = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _player?.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Listener de bajo nivel para no competir con el scroll ──
  void _onPointerDown(PointerDownEvent e) {
    if (widget.content.trailerUrl.isEmpty) return;
    _pressing = true;
    _pressTimer = Timer(const Duration(milliseconds: 800), () {
      if (_pressing && mounted) _startPreview();
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    _pressing = false;
    _pressTimer?.cancel();
    if (!_isPlaying) return;
    _stopPreview();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pressing = false;
    _pressTimer?.cancel();
    _stopPreview();
  }

  Future<void> _startPreview() async {
    if (_isPlaying || !mounted) return;
    setState(() => _isBuffering = true);

    try {
      _player = Player();
      _controller = VideoController(_player!);

      await _player!.open(Media(widget.content.trailerUrl));
      await _player!.setVolume(0);   // silencioso — solo preview visual

      if (!mounted) {
        _player?.dispose();
        return;
      }

      setState(() { _isPlaying = true; _isBuffering = false; });
      _fadeCtrl.forward();
    } catch (e) {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  void _stopPreview() {
    if (!_isPlaying && !_isBuffering) return;
    _fadeCtrl.reverse().then((_) {
      _player?.dispose();
      _player = null;
      _controller = null;
      if (mounted) setState(() { _isPlaying = false; _isBuffering = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final imgUrl = c.imagenUrl.isNotEmpty
        ? cloudinaryOptimized(c.imagenUrl,
            w: widget.width.toInt(), h: widget.height.toInt())
        : '';

    return Listener(
      onPointerDown:   _onPointerDown,
      onPointerUp:     _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(fit: StackFit.expand, children: [

              // ── Póster ──
              imgUrl.isNotEmpty
                  ? Image.network(imgUrl, fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) =>
                          prog == null ? child : _placeholder(c),
                      errorBuilder: (_, __, ___) => _placeholder(c))
                  : _placeholder(c),

              // ── Video preview ──
              if (_isPlaying && _controller != null)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Video(
                    controller: _controller!,
                    fit: BoxFit.cover,
                    controls: NoVideoControls, // sin controles en preview
                  ),
                ),

              // ── Buffering ──
              if (_isBuffering)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Color(0xFFE50914), strokeWidth: 2)))),

              // ── Ícono play (indica que tiene trailer) ──
              if (!_isPlaying && !_isBuffering && c.trailerUrl.isNotEmpty)
                Positioned(bottom: 6, right: 6,
                  child: Container(width: 22, height: 22,
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 1)),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 14))),

              // ── Badge S/P ──
              Positioned(top: 5, left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3)),
                  child: Text(c.type == 'Serie' ? 'S' : 'P',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.bold)))),

              // ── Badge PRO ──
              if (c.isPremium)
                Positioned(top: 5, right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF57C00),
                        borderRadius: BorderRadius.circular(3)),
                    child: const Text('PRO',
                        style: TextStyle(color: Colors.white,
                            fontSize: 7, fontWeight: FontWeight.bold)))),

              // ── Borde rojo al reproducir ──
              if (_isPlaying)
                Positioned.fill(child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFE50914), width: 2)),
                )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ContentModel c) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          genreColor(c.genre).withOpacity(0.85),
          genreColor(c.genre).withOpacity(0.3),
          const Color(0xFF111111),
        ],
      ),
    ),
    child: Center(child: Icon(
        c.type == 'Serie' ? Icons.tv_rounded : Icons.movie_rounded,
        size: 28, color: Colors.white.withOpacity(0.2))),
  );
}