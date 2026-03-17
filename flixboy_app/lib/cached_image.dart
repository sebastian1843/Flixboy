// lib/cached_image.dart
//
// Widget unificado de imágenes con caché para Flixboy.
// Uso:
//   FlixImage(url: content.imagenUrl, width: 120, height: 160)
//
// Requiere en pubspec.yaml:
//   cached_network_image: ^3.3.1

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'main.dart'; // genreColor + cloudinaryOptimized

// ─────────────────────────────────────────────────────────────
//  Widget principal
// ─────────────────────────────────────────────────────────────

class FlixImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Genre se usa solo para el placeholder de color.
  final String genre;

  /// Tipo: 'Serie' o 'Película' — para el ícono del placeholder.
  final String type;

  const FlixImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit          = BoxFit.cover,
    this.borderRadius,
    this.genre        = '',
    this.type         = 'Película',
  });

  @override
  Widget build(BuildContext context) {
    final optimizedUrl = url.isNotEmpty
        ? cloudinaryOptimized(
            url,
            w: width?.toInt()  ?? 300,
            h: height?.toInt() ?? 450,
          )
        : '';

    Widget image;

    if (optimizedUrl.isEmpty) {
      image = _Placeholder(
          genre: genre, type: type, width: width, height: height);
    } else {
      image = CachedNetworkImage(
        imageUrl:    optimizedUrl,
        width:       width,
        height:      height,
        fit:         fit,
        // ── Shimmer mientras carga ──
        placeholder: (_, __) => _Shimmer(width: width, height: height),
        // ── Placeholder si falla ──
        errorWidget: (_, __, ___) =>
            _Placeholder(genre: genre, type: type, width: width, height: height),
        // Fade suave al aparecer
        fadeInDuration:  const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 150),
        // Caché en memoria y disco
        memCacheWidth:  width  != null ? (width!  * 1.5).toInt() : null,
        memCacheHeight: height != null ? (height! * 1.5).toInt() : null,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

// ─────────────────────────────────────────────────────────────
//  Shimmer animado
// ─────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double? width;
  final double? height;
  const _Shimmer({this.width, this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end:   Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF2A2A2A),
                Color(0xFF1A1A1A),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Placeholder de color por género
// ─────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final String genre;
  final String type;
  final double? width;
  final double? height;

  const _Placeholder({
    required this.genre,
    required this.type,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final color = genre.isNotEmpty ? genreColor(genre) : const Color(0xFF424242);
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.3),
            const Color(0xFF111111),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          type.toLowerCase().contains('serie')
              ? Icons.tv_rounded
              : Icons.movie_rounded,
          size:  (width ?? 120) * 0.25,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}