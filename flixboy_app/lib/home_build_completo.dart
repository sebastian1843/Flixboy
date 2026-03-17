// ══════════════════════════════════════════════════════════════
//  REEMPLAZA el método build() completo de _HomeScreenState
//  en main.dart con este código.
//
//  Imports necesarios al inicio de main.dart:
//    import 'skeleton_loading.dart';
//    import 'continue_watching.dart';
//    import 'progress_service.dart';
// ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final myList = WatchlistManager.watchlist;
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _bannerOpacity < 0.5
                ? const Color(0xFF080808)
                : Colors.transparent,
            gradient: _bannerOpacity >= 0.5
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8 * (1 - _bannerOpacity)),
                      Colors.transparent,
                    ])
                : null,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _sidebarVisible
                              ? const Color(0xFFE50914).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bl(_sidebarVisible, top: true),
                            const SizedBox(height: 5),
                            _bl(_sidebarVisible, mid: true),
                            const SizedBox(height: 5),
                            _bl(_sidebarVisible, bottom: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedOpacity(
                      opacity: _bannerOpacity < 0.3 ? 1.0 : 0.85,
                      duration: const Duration(milliseconds: 200),
                      child: const Text('FLIXBOY',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE50914),
                              letterSpacing: 4)),
                    ),
                  ]),
                  Row(children: [
                    StatefulBuilder(builder: (ctx, setLocal) {
                      final count = NotificationsManager.unreadCount;
                      return Stack(children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white),
                          onPressed: () async {
                            await Navigator.push(ctx,
                                MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen()));
                            setLocal(() {});
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 6, top: 6,
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFE50914),
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ]);
                    }),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE50914),
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),

      // ── BODY ──────────────────────────────────────────────
      body: Stack(children: [

        CustomScrollView(
          controller: _scrollCtrl,
          slivers: [

            // ── SKELETON: mientras carga ──
            if (_loadingContent)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: HomeSkeletonScreen(),
              )

            // ── CONTENIDO REAL ──
            else ...[

              // Hero banner
              if (_allContent.isNotEmpty)
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: _bannerOpacity,
                    duration: const Duration(milliseconds: 100),
                    child: _buildHeroBanner(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Continuar viendo ──
              const SliverToBoxAdapter(
                child: ContinueWatchingSection(),
              ),

              // ── Tendencias ──
              if (_trending.isNotEmpty)
                ..._buildSection('Tendencias ahora', _trending),

              // ── Mi Lista ──
              if (myList.isNotEmpty)
                ..._buildSection(
                  'Mi Lista',
                  myList.map((m) => ContentModel(
                    id:          m['id']          ?? '',
                    title:       m['title']        ?? '',
                    genre:       m['genre']        ?? '',
                    year:        m['year']         ?? '',
                    duration:    m['duration']     ?? '',
                    type:        m['type']         ?? '',
                    description: m['description']  ?? '',
                    videoUrl:    m['videoUrl']      ?? '',
                    imagenUrl:   m['imagenUrl']     ?? '',
                  )).toList(),
                ),

              // ── Por género ──
              ..._allGenres.expand((genre) {
                final items = _allContent
                    .where((c) => c.genre == genre)
                    .toList();
                if (items.isEmpty) return <Widget>[];
                return _buildSection(_gi(genre), items);
              }),

              // ── Próximos estrenos ──
              if (_upcoming.isNotEmpty)
                ..._buildUpcomingSection(),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),

        // ── Zona swipe para abrir sidebar ──
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

        // ── Overlay oscuro del sidebar ──
        if (_sidebarVisible)
          GestureDetector(
            onTap: () => setState(() => _sidebarVisible = false),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // ── Sidebar animado ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          left: _sidebarVisible ? 0 : -220,
          top: 0, bottom: 0, width: 220,
          child: _buildSidebar(),
        ),

      ]),
    );
  }