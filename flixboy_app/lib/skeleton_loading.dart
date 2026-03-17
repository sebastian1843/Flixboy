// lib/skeleton_loading.dart
//
// Skeleton loading para Flixboy.
// Reemplaza el CircularProgressIndicator del HomeScreen
// con tarjetas animadas que imitan el layout real.
//
// Uso en HomeScreen:
//   if (_loadingContent) const HomeSkeletonScreen()
//   else ... (tu contenido actual)

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Bloque base: rectángulo animado con shimmer
// ─────────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
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
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end:   Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFF1C1C1C),
                Color(0xFF2C2C2C),
                Color(0xFF1C1C1C),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Skeleton del hero banner
// ─────────────────────────────────────────────────────────────

class _HeroBannerSkeleton extends StatelessWidget {
  const _HeroBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.62;
    final w = MediaQuery.of(context).size.width;

    return SizedBox(
      height: h,
      width:  w,
      child: Stack(children: [
        // Imagen de fondo
        _SkeletonBox(width: w, height: h, radius: 0),

        // Gradiente inferior
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF080808)],
                stops: [0.5, 1.0],
              ),
            ),
          ),
        ),

        // Texto inferior
        Positioned(
          bottom: 40, left: 20, right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge tipo
              _SkeletonBox(width: 80, height: 22, radius: 4),
              const SizedBox(height: 12),
              // Título
              _SkeletonBox(width: w * 0.65, height: 34, radius: 6),
              const SizedBox(height: 8),
              _SkeletonBox(width: w * 0.45, height: 34, radius: 6),
              const SizedBox(height: 12),
              // Descripción
              _SkeletonBox(width: w * 0.85, height: 14, radius: 4),
              const SizedBox(height: 6),
              _SkeletonBox(width: w * 0.70, height: 14, radius: 4),
              const SizedBox(height: 20),
              // Botones
              Row(children: [
                _SkeletonBox(width: 130, height: 44, radius: 6),
                const SizedBox(width: 10),
                _SkeletonBox(width: 110, height: 44, radius: 6),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Skeleton de una fila de tarjetas
// ─────────────────────────────────────────────────────────────

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: _SkeletonBox(width: 140, height: 18, radius: 4),
          ),
          // Tarjetas horizontales
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Póster
                    _SkeletonBox(width: 120, height: 160, radius: 6),
                    const SizedBox(height: 6),
                    // Título
                    _SkeletonBox(width: 100, height: 12, radius: 3),
                    const SizedBox(height: 4),
                    // Género + año
                    Row(children: [
                      _SkeletonBox(width: 10, height: 10, radius: 5),
                      const SizedBox(width: 4),
                      _SkeletonBox(width: 55, height: 10, radius: 3),
                      const SizedBox(width: 8),
                      _SkeletonBox(width: 30, height: 10, radius: 3),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  Pantalla completa de skeleton (reemplaza al spinner)
// ─────────────────────────────────────────────────────────────

class HomeSkeletonScreen extends StatelessWidget {
  const HomeSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            // Hero banner
            _HeroBannerSkeleton(),
            SizedBox(height: 24),
            // 3 filas de contenido
            _RowSkeleton(),
            _RowSkeleton(),
            _RowSkeleton(),
            SizedBox(height: 32),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Skeleton para SearchScreen (lista de resultados cargando)
// ─────────────────────────────────────────────────────────────

class SearchSkeletonList extends StatelessWidget {
  const SearchSkeletonList({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: _SkeletonBox(width: 90, height: 90, radius: 0),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 160, height: 14, radius: 4),
                      const SizedBox(height: 8),
                      Row(children: [
                        _SkeletonBox(width: 55, height: 18, radius: 4),
                        const SizedBox(width: 8),
                        _SkeletonBox(width: 40, height: 12, radius: 3),
                      ]),
                      const SizedBox(height: 6),
                      _SkeletonBox(width: 100, height: 11, radius: 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),
      );
}