// lib/app_transitions.dart
//
// Animaciones y transiciones profesionales para Flixboy.
// Incluye:
//   • Transiciones de página personalizadas (fade, slide, scale)
//   • Hero compartido para pósters → DetailScreen
//   • Animaciones de entrada para listas (stagger)
//   • Micro-interacciones para botones
//   • Transición especial para el reproductor

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  TRANSICIONES DE PÁGINA
// ══════════════════════════════════════════════════════════════

class AppRoute {
  // Fade suave — para pantallas principales
  static PageRoute fade(Widget page) => PageRouteBuilder(
    pageBuilder:       (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );

  // Slide desde abajo — para bottom sheets y detalles
  static PageRoute slideUp(Widget page) => PageRouteBuilder(
    pageBuilder:       (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, anim, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: anim,
        child:   SlideTransition(position: offset, child: child),
      );
    },
  );

  // Scale + fade — para DetailScreen desde tarjeta
  static PageRoute scaleDetail(Widget page) => PageRouteBuilder(
    pageBuilder:       (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (_, anim, __, child) {
      final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child:   ScaleTransition(scale: scale, child: child),
      );
    },
  );

  // Slide horizontal — para navegación lateral
  static PageRoute slideRight(Widget page) => PageRouteBuilder(
    pageBuilder:       (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, anim, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1.0, 0),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );

  // Reproductor — fade a negro
  static PageRoute playerFade(Widget page) => PageRouteBuilder(
    pageBuilder:       (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 500),
    barrierColor:       Colors.black,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

// ══════════════════════════════════════════════════════════════
//  HERO COMPARTIDO — póster → DetailScreen
// ══════════════════════════════════════════════════════════════

// Envuelve la imagen del póster con este widget.
// En DetailScreen también debes envolver la imagen con
// Hero(tag: 'poster_${content.id}', child: ...)
//
// Uso en tarjeta:
//   HeroPoster(
//     contentId: content.id,
//     imageUrl:  content.imagenUrl,
//     width:     120, height: 160,
//   )

class HeroPoster extends StatelessWidget {
  final String contentId;
  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const HeroPoster({
    super.key,
    required this.contentId,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'poster_$contentId',
    flightShuttleBuilder: (_, anim, __, ___, ____) => AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.lerp(
          borderRadius ?? BorderRadius.circular(6),
          BorderRadius.zero,
          anim.value,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(imageUrl,
              width: width, height: height, fit: BoxFit.cover)
          : Container(width: width, height: height,
              color: const Color(0xFF1A1A1A)),
    ),
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: imageUrl.isNotEmpty
          ? Image.network(imageUrl,
              width: width, height: height, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: width, height: height,
                  color: const Color(0xFF1A1A1A)))
          : Container(width: width, height: height,
              color: const Color(0xFF1A1A1A)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  STAGGER ANIMATION — entrada en cascada para listas
// ══════════════════════════════════════════════════════════════

// Uso:
//   StaggerList(
//     children: items.map((item) => MyCard(item)).toList(),
//   )

class StaggerList extends StatefulWidget {
  final List<Widget> children;
  final Duration     itemDelay;
  final Duration     itemDuration;
  final Axis         direction;

  const StaggerList({
    super.key,
    required this.children,
    this.itemDelay    = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.direction    = Axis.vertical,
  });

  @override
  State<StaggerList> createState() => _StaggerListState();
}

class _StaggerListState extends State<StaggerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: widget.itemDuration +
          widget.itemDelay * widget.children.length,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: widget.children.asMap().entries.map((e) {
      final i     = e.key;
      final start = (widget.itemDelay.inMilliseconds * i) /
          _ctrl.duration!.inMilliseconds;
      final end   = start +
          widget.itemDuration.inMilliseconds /
              _ctrl.duration!.inMilliseconds;

      final fade = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
              parent: _ctrl,
              curve:  Interval(start, end.clamp(0, 1),
                  curve: Curves.easeOut)));

      final slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end:   Offset.zero,
      ).animate(CurvedAnimation(
          parent: _ctrl,
          curve:  Interval(start, end.clamp(0, 1),
              curve: Curves.easeOutCubic)));

      return FadeTransition(
        opacity: fade,
        child:   SlideTransition(position: slide, child: e.value),
      );
    }).toList(),
  );
}

// ══════════════════════════════════════════════════════════════
//  MICRO-INTERACCIONES — botones con feedback táctil
// ══════════════════════════════════════════════════════════════

class TapScale extends StatefulWidget {
  final Widget   child;
  final double   scale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TapScale({
    super.key,
    required this.child,
    this.scale       = 0.95,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:       (_) => _ctrl.forward(),
    onTapUp:         (_) { _ctrl.reverse(); widget.onTap?.call(); },
    onTapCancel:     ()  => _ctrl.reverse(),
    onLongPress:     widget.onLongPress,
    child: AnimatedBuilder(
      animation: _scale,
      builder:   (_, child) => Transform.scale(
          scale: _scale.value, child: child),
      child: widget.child,
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  SHIMMER PULSE — para elementos que están cargando
// ══════════════════════════════════════════════════════════════

class PulseWidget extends StatefulWidget {
  final Widget child;
  const PulseWidget({super.key, required this.child});

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _anim, child: widget.child);
}

// ══════════════════════════════════════════════════════════════
//  CÓMO USAR — resumen rápido
// ══════════════════════════════════════════════════════════════

// 1. TRANSICIONES — reemplaza MaterialPageRoute por AppRoute:
//
//    // Antes:
//    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(...)));
//
//    // Después:
//    Navigator.push(context, AppRoute.scaleDetail(DetailScreen(...)));
//    Navigator.push(context, AppRoute.slideRight(SearchScreen(...)));
//    Navigator.push(context, AppRoute.playerFade(VideoPlayerScreen(...)));
//    Navigator.push(context, AppRoute.fade(ProfileScreen(...)));

// 2. HERO POSTER — en tarjetas (preview_card.dart o _contentCard):
//
//    HeroPoster(
//      contentId:    content.id,
//      imageUrl:     content.imagenUrl,
//      width:        120, height: 160,
//      borderRadius: BorderRadius.circular(6),
//    )
//
//    Y en DetailScreen, envuelve la imagen del SliverAppBar:
//    Hero(tag: 'poster_${c.id}', child: Image.network(...))

// 3. TAP SCALE — en tarjetas para feedback táctil:
//
//    TapScale(
//      onTap: () => Navigator.push(...),
//      child: _contentCard(item),
//    )

// 4. STAGGER — en listas al cargar resultados de búsqueda:
//
//    StaggerList(
//      children: _results.map((item) => _searchItem(item)).toList(),
//    )