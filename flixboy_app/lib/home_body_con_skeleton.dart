// ══════════════════════════════════════════════════════════════
//  PASO 3 COMPLETO — Reemplaza el build() de _HomeScreenState
//  en main.dart con este código.
//  Solo cambia la sección "body:" del Scaffold.
// ══════════════════════════════════════════════════════════════

// Asegúrate de tener el import al inicio de main.dart:
//   import 'skeleton_loading.dart';

// ── Reemplaza desde "body: _loadingContent" hasta el cierre
//    del Stack principal (antes del cierre del Scaffold) ───────

body: Stack(children: [

  // ── Scroll principal ──
  CustomScrollView(
    controller: _scrollCtrl,
    slivers: [

      // ── SKELETON: mientras carga muestra layout animado ──
      if (_loadingContent)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: HomeSkeletonScreen(),
        )

      // ── CONTENIDO REAL: una vez cargado ──
      else ...[
        if (_allContent.isNotEmpty)
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: _bannerOpacity,
              duration: const Duration(milliseconds: 100),
              child: _buildHeroBanner(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        if (_trending.isNotEmpty)
          ..._buildSection('Tendencias ahora', _trending),

        if (myList.isNotEmpty)
          ..._buildSection(
            'Mi Lista',
            myList.map((m) => ContentModel(
              id:          m['id']          ?? '',
              title:       m['title']       ?? '',
              genre:       m['genre']       ?? '',
              year:        m['year']        ?? '',
              duration:    m['duration']    ?? '',
              type:        m['type']        ?? '',
              description: m['description'] ?? '',
              videoUrl:    m['videoUrl']    ?? '',
              imagenUrl:   m['imagenUrl']   ?? '',
            )).toList(),
          ),

        ..._allGenres.expand((genre) {
          final items = _allContent.where((c) => c.genre == genre).toList();
          if (items.isEmpty) return <Widget>[];
          return _buildSection(_gi(genre), items);
        }),

        if (_upcoming.isNotEmpty)
          ..._buildUpcomingSection(),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    ],
  ),

  // ── Zona de swipe para abrir sidebar ──
  if (!_sidebarVisible)
    Positioned(
      left: 0, top: 0, bottom: 0, width: 30,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          if (d.delta.dx > 3) setState(() => _sidebarVisible = true);
        },
        behavior: HitTestBehavior.translucent,
      ),
    ),

  // ── Overlay oscuro al abrir sidebar ──
  if (_sidebarVisible)
    GestureDetector(
      onTap: () => setState(() => _sidebarVisible = false),
      child: Container(color: Colors.black.withValues(alpha: 0.6)),
    ),

  // ── Sidebar animado ──
  AnimatedPositioned(
    duration: const Duration(milliseconds: 280),
    curve:    Curves.easeInOut,
    left:     _sidebarVisible ? 0 : -220,
    top: 0, bottom: 0, width: 220,
    child: _buildSidebar(),
  ),

]),