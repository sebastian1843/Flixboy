// lib/home_screen.dart
// Pantalla principal (Home) de Flixboy.
import 'package:flutter/material.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'profile_manager.dart';
import 'screens.dart';
import 'video_player_screen.dart';
import 'skeleton_loading.dart';
import 'continue_watching.dart';
import 'responsive.dart';
import 'auth_screens.dart';
import 'profile_screens.dart';
import 'content_screens.dart';
import 'account_screens.dart';
//  PANTALLA 11: HOME SCREEN
// ══════════════════════════════════════════════════════════════


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int    _currentIndex   = 0;
  double _bannerOpacity  = 1.0;
  bool   _sidebarVisible = false;

  final ScrollController _scrollCtrl = ScrollController();

  List<ContentModel> _allContent = [];
  List<ContentModel> _trending   = [];
  List<ContentModel> _upcoming   = [];
  bool _loadingContent = true;
  bool _loadError      = false;

  final _sectionPaginators = <String, ContentPaginator>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _loadContent();
  }

  void _onScroll() {
    final opacity = (1.0 - (_scrollCtrl.offset / 200)).clamp(0.0, 1.0);
    if ((opacity - _bannerOpacity).abs() > 0.01) {
      setState(() => _bannerOpacity = opacity);
    }
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMoreVisible();
    }
  }

  bool _loadMoreVisible() {
    bool changed = false;
    for (final p in _sectionPaginators.values) {
      if (p.loadMore()) changed = true;
    }
    if (changed) setState(() {});
    return changed;
  }

  Future<void> _loadContent() async {
    setState(() { _loadingContent = true; _loadError = false; });
    try {
      // Carga en paralelo para mayor velocidad
      final results = await Future.wait([
        ContentService.getAllContent(),
        ContentService.getTrending(),
        ContentService.getUpcoming(),
      ]);
      final all      = results[0] as List<ContentModel>;
      final trending = results[1] as List<ContentModel>;
      final upcoming = results[2] as List<ContentModel>;

      // Excluir próximos estrenos del home — filtro triple para cubrir
      // cualquier variante usada en Firestore
      final filtered = ProfileManager.filterForProfile(all).where((c) {
        final g = c.genre.toLowerCase()
            .replaceAll('ó', 'o').replaceAll('é', 'e')
            .replaceAll('á', 'a').replaceAll('í', 'i').replaceAll('ú', 'u');
        return !c.isUpcoming &&
               !g.contains('proximo') &&
               !g.contains('upcoming');
      }).toList();

      _sectionPaginators.clear();
      final genres = <String>{};
      for (final c in filtered) {
        if (c.genre != 'Proximo estreno') genres.add(c.genre);
      }
      for (final g in genres) {
        final p = ContentPaginator(pageSize: 10);
        p.setAll(filtered.where((c) => c.genre == g).toList());
        _sectionPaginators[g] = p;
      }
      final trendingFiltered = trending.isNotEmpty
          ? ProfileManager.filterForProfile(trending)
          : filtered.take(6).toList();
      _sectionPaginators['__trending__'] = ContentPaginator(pageSize: 10)
        ..setAll(trendingFiltered);

      // Próximos estrenos: usa lo que devuelva el backend; si viene vacío,
      // cae a lo que haya marcado como "próximo estreno" dentro de "all".
      var upcomingFinal = upcoming.isNotEmpty
          ? upcoming
          : all.where((c) => c.isUpcoming).toList();

      if (upcomingFinal.isEmpty) {
        upcomingFinal = all.where((c) {
          final g = c.genre.toLowerCase()
              .replaceAll('ó', 'o').replaceAll('é', 'e')
              .replaceAll('á', 'a').replaceAll('í', 'i').replaceAll('ú', 'u');
          return g.contains('proximo') || g.contains('upcoming');
        }).toList();
      }

      if (mounted) {
        setState(() {
          _allContent     = filtered;
          _trending       = trendingFiltered;
          _upcoming       = upcomingFinal;
          _loadingContent = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingContent = false; _loadError = true; });
      await ApiErrorHandler.handle(e, context, onRetry: _loadContent);
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !AuthService.isLoggedIn && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        Navigator.push(context,
            AppRoute.slideRight(SearchScreen(allContent: _allContent)))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 2:
        Navigator.push(context,
            AppRoute.slideRight(ProximamenteScreen(content: _upcoming)))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 3:
        Navigator.push(context, AppRoute.slideRight(const SeriesScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 4:
        Navigator.push(context, AppRoute.slideUp(const WatchlistScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 5:
        Navigator.push(context, AppRoute.slideRight(const ProfileScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
    }
  }

  List<String> get _allGenres {
    final g = <String>{};
    for (final c in _allContent) {
      if (c.genre != 'Proximo estreno' && !c.isUpcoming) g.add(c.genre);
    }
    return g.toList()..sort();
  }

 @override
Widget build(BuildContext context) {
  final r = FlixResponsive.of(context);

  // ── TV / Laptop: sidebar fijo a la izquierda, sin overlay ni swipe ──
  if (r.hasPersistentSidebar) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Row(children: [
        SizedBox(width: r.sidebarWidth, child: _buildSidebar()),
        Container(width: 1, color: const Color(0xFF1A1A1A)),
        Expanded(child: Column(children: [
          _buildTopBar(showMenuButton: false),
          Expanded(child: _buildContentScrollView()),
        ])),
      ]),
    );
  }

  // ── Tablet / Móvil: sidebar deslizable (comportamiento original) ──
  return Scaffold(
    backgroundColor: const Color(0xFF080808),
    extendBodyBehindAppBar: true,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: _buildTopBar(showMenuButton: true),
    ),
    body: Stack(children: [
      _buildContentScrollView(),
      if (!_sidebarVisible) Positioned(
        left: 0, top: 0, bottom: 0, width: 30,
        child: GestureDetector(
          onHorizontalDragUpdate: (d) {
            if (d.delta.dx > 3) setState(() => _sidebarVisible = true);
          },
          behavior: HitTestBehavior.translucent,
        ),
      ),
      if (_sidebarVisible) GestureDetector(
        onTap: () => setState(() => _sidebarVisible = false),
        child: Container(color: Colors.black.withValues(alpha: 0.6)),
      ),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        left: _sidebarVisible ? 0 : -220,
        top: 0, bottom: 0, width: 220,
        child: _buildSidebar(),
      ),
    ]),
  );
}     // cierre del build

  // ── Barra superior: hamburguesa (solo tablet/móvil) + logo + notificaciones + avatar ──
  // Se comparte entre el layout con sidebar deslizable y el de sidebar fijo.
  Widget _buildTopBar({required bool showMenuButton}) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: (!showMenuButton || _bannerOpacity < 0.5)
          ? const Color(0xFF080808)
          : Colors.transparent,
    ),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        // Hamburguesa — solo cuando el sidebar es deslizable (tablet/móvil)
        if (showMenuButton) ...[
          GestureDetector(
            onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _sidebarVisible
                    ? const Color(0xFFE50914).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _bl(_sidebarVisible, top: true),
                const SizedBox(height: 5),
                _bl(_sidebarVisible, mid: true),
                const SizedBox(height: 5),
                _bl(_sidebarVisible, bottom: true),
              ]),
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Logo
        const Text('FLIXBOY', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            color: Color(0xFFE50914), letterSpacing: 3)),
        const Spacer(),
        // Notificaciones
        StatefulBuilder(builder: (ctx, setLocal) {
          final count = NotificationsManager.unreadCount;
          return Stack(children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 22),
              onPressed: () async {
                await Navigator.push(ctx,
                    AppRoute.slideUp(const NotificationsScreen()));
                setLocal(() {});
              },
            ),
            if (count > 0) Positioned(right: 2, top: 2,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                    color: Color(0xFFE50914), shape: BoxShape.circle),
                child: Center(child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.bold))))),
          ]);
        }),
        const SizedBox(width: 4),
        // Avatar
        GestureDetector(
          onTap: () => Navigator.push(
              context, AppRoute.fade(const ProfileSelectScreen())),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              ProfileManager.activeProfile?.image
                  ?? 'assets/images/profile1.jpg',
              width: 30, height: 30, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 15, backgroundColor: Color(0xFFE50914),
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ]),
    )),
  );

  // ── Contenido con scroll (hero, secciones, etc.) — compartido entre layouts ──
  Widget _buildContentScrollView() => CustomScrollView(controller: _scrollCtrl, slivers: [
    if (_loadingContent)
      const SliverFillRemaining(
          hasScrollBody: false, child: HomeSkeletonScreen())
    else if (_loadError)
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, size: 60, color: Color(0xFF444444)),
          const SizedBox(height: 16),
          const Text('No se pudo cargar el contenido',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadContent, child: const Text('Reintentar')),
        ])),
      )
    else ...[
      if (_allContent.isNotEmpty)
        SliverToBoxAdapter(child: AnimatedOpacity(
          opacity: _bannerOpacity,
          duration: const Duration(milliseconds: 100),
          child: _buildHeroBanner(),
        )),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      const SliverToBoxAdapter(child: ContinueWatchingSection()),
      if (_trending.isNotEmpty)
        ..._buildSection('Top 10 en Flixboy',
            _sectionPaginators['__trending__']?.visible ?? _trending,
            isTop10: true),
      SliverToBoxAdapter(child: WatchlistBuilder(
        builder: (_, wl) {
          if (wl.isEmpty) return const SizedBox();
          final items = wl.map((m) => ContentModel(
            id:          m['id']          ?? '',
            title:       m['title']        ?? '',
            genre:       m['genre']        ?? '',
            year:        m['year']         ?? '',
            duration:    m['duration']     ?? '',
            type:        m['type']         ?? '',
            description: m['description']  ?? '',
            videoUrl:    m['videoUrl']     ?? '',
            imagenUrl:   m['imagenUrl']    ?? '',
            trailerUrl:  m['trailerUrl']   ?? '',
          )).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildSection('Mi Lista', items)
                  .map((w) => w is SliverToBoxAdapter
                      ? (w.child ?? const SizedBox())
                      : const SizedBox()),
            ],
          );
        },
      )),
      ..._allGenres.expand((genre) {
        final paginator = _sectionPaginators[genre];
        if (paginator == null || paginator.visible.isEmpty) return <Widget>[];
        return _buildSection(genre, paginator.visible);
      }),
      if (_upcoming.isNotEmpty) ...[
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Próximamente', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(
              onPressed: () => Navigator.push(context,
                  AppRoute.slideRight(ProximamenteScreen(content: _upcoming))),
              child: const Text('Ver todo',
                  style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
            ),
          ]),
        )),
        SliverToBoxAdapter(child: SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12, top: 10),
            itemCount: _upcoming.length,
            itemBuilder: (_, i) => _upcomingCard(_upcoming[i]),
          ),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      SliverToBoxAdapter(
        child: _sectionPaginators.values.any((p) => p.hasMore)
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Color(0xFFE50914), strokeWidth: 1.5),
                )),
              )
            : const SizedBox(height: 32),
      ),
    ],
  ]);

  Widget _navTab(String label, int index) {
  final isActive = _currentIndex == index;
  return GestureDetector(
    onTap: () => _onNavTap(index),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE50914) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF999999),
          fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

  Widget _buildSidebar() => GestureDetector(
    onHorizontalDragUpdate: (d) {
      if (d.delta.dx < -5) setState(() => _sidebarVisible = false);
    },
    child: Container(
      decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20, spreadRadius: 5)]),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        ...[
          {'icon': Icons.home_rounded,       'label': 'Inicio',         'index': 0},
          {'icon': Icons.search_rounded,     'label': 'Buscar',         'index': 1},
          {'icon': Icons.tv_rounded,         'label': 'Series',         'index': 2},
          {'icon': Icons.movie_rounded,      'label': 'Películas',      'index': 3},
          {'icon': Icons.add_circle_outline, 'label': 'Mi Lista',       'index': 4},
          {'icon': Icons.upcoming_outlined,  'label': 'Próximamente',   'index': 20},
          {'icon': Icons.explore_rounded,    'label': 'Explorar',       'index': 6},
          {'icon': Icons.settings_outlined,  'label': 'Configuración',  'index': 7},
        ].map((item) {
  final isActive = item['index'] == _currentIndex;
  return GestureDetector(
    onTap: () {
      setState(() => _sidebarVisible = false);
      final idx = item['index'] as int;
      if (idx == 7) {
        Navigator.push(context, AppRoute.slideRight(const SettingsScreen()));
      } else if (idx == 20) {
        // Próximamente — navega directo con el contenido ya cargado
        Navigator.push(
          context,
          AppRoute.slideRight(ProximamenteScreen(content: _upcoming)),
        );
      } else {
        _onNavTap(idx);
      }
    },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFE50914).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isActive
                    ? Border.all(
                        color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 1)
                    : null,
              ),
              child: Row(children: [
                Icon(item['icon'] as IconData,
                    color: isActive ? const Color(0xFFE50914) : Colors.white70, size: 24),
                const SizedBox(width: 14),
                Text(item['label'] as String, style: TextStyle(
                  color: isActive ? const Color(0xFFE50914) : Colors.white70,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                )),
              ]),
            ),
          );
        }).toList(),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            setState(() => _sidebarVisible = false);
            await PushNotificationService.onLogout();
            await AuthService.logout();
            await LocalSessionManager.clear();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            }
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.logout, color: Color(0xFFE50914), size: 20),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(
                  color: Color(0xFFE50914), fontSize: 13,
                  fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ])),
    ),
  );

  Widget _bl(bool active, {bool top = false, bool mid = false, bool bottom = false}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: mid ? (active ? 14 : 20) : 20, height: 2.2,
        margin: EdgeInsets.only(left: mid ? (active ? 3 : 0) : 0),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE50914) : Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeroBanner() {
    if (_allContent.isEmpty) return const SizedBox();
    final featured = _allContent.first;
    final screenW  = MediaQuery.of(context).size.width.toInt();
    final screenH  = (MediaQuery.of(context).size.height * 0.65).toInt();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Stack(fit: StackFit.expand, children: [
        FlixImage(
          url: cloudinaryOptimized(featured.imagenUrl, w: screenW, h: screenH),
          fit: BoxFit.cover,
          errorWidget: (_) => _heroBannerFallback(),
        ),
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.transparent, Colors.black],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        )),
        Positioned(
          bottom: 40, left: 20, right: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(featured.title, style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star, color: Color(0xFFE50914), size: 16),
              const SizedBox(width: 5),
              const Text('7.3 IMDb', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(featured.year,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(featured.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () {
                  HistoryManager.add(featured);
                  Navigator.push(context, AppRoute.playerFade(
                      VideoPlayerScreen(videoUrl: featured.videoUrl,
                          title: featured.title, content: featured)));
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ver ahora'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white),
              ),
              const SizedBox(width: 10),
              WatchlistBuilder(builder: (_, __) => OutlinedButton.icon(
                onPressed: () async => WatchlistManager.toggle(featured.toMap()),
                icon: Icon(WatchlistManager.isInWatchlist(featured.title)
                    ? Icons.check : Icons.add),
                label: const Text('Mi lista'),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    foregroundColor: Colors.white),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _heroBannerFallback() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1A0A0A), Color(0xFF2D0505),
          Color(0xFF1A0A0A), Color(0xFF080808)],
        stops: [0.0, 0.3, 0.7, 1.0]),
  ));

  List<Widget> _buildSection(String title, List<ContentModel> items,
      {bool isTop10 = false}) {
    return [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          if (isTop10) GestureDetector(
            onTap: () => Navigator.push(context,
                AppRoute.slideRight(Top10Screen(content: items))),
            child: const Text('Ver todo',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
          ),
        ]),
      )),
      SliverToBoxAdapter(child: SizedBox(
        height: isTop10 ? 200 : 170,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          itemBuilder: (_, i) {
            final c = items[i];
            return GestureDetector(
              onTap: () => Navigator.push(context,
                  AppRoute.scaleDetail(DetailScreen(content: c))),
              child: isTop10
                  ? _top10Card(c, i + 1)
                  : Container(
                      width: 120,
                      margin: const EdgeInsets.only(left: 12, top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FlixImage(
                          url: cloudinaryOptimized(c.imagenUrl, w: 120, h: 170),
                          width: 120, height: 170,
                          errorWidget: (_) => _cardPlaceholder(c),
                        ),
                      ),
                    ),
            );
          },
        ),
      )),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

   Widget _top10Card(ContentModel c, int rank) => GestureDetector(
    onTap: () => Navigator.push(context,
        AppRoute.scaleDetail(DetailScreen(content: c))),
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(left: 12, top: 10),
      child: Stack(children: [
        // Imagen
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlixImage(
            url: cloudinaryOptimized(c.imagenUrl, w: 140, h: 190),
            width: 140,
            height: 190,
            errorWidget: (_) => _cardPlaceholder(c),
          ),
        ),
 
        // Número con borde (stroke) — SIN 'color', solo 'foreground'
        Positioned(
          bottom: 0,
          left: 0,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              // SOLO foreground, sin color
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.white24,
            ),
          ),
        ),
 
        // Número relleno blanco encima — SIN foreground, solo color
        Positioned(
          bottom: 0,
          left: 0,
          child: Text(
            '$rank',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: Colors.white, // solo color, sin foreground
            ),
          ),
        ),
      ]),
    ),
  );

   Widget _upcomingCard(ContentModel c) => GestureDetector(
    onTap: () => Navigator.push(context,
        AppRoute.scaleDetail(DetailScreen(content: c))),
    child: Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlixImage(
              url: cloudinaryOptimized(c.imagenUrl, w: 130, h: 160),
              width: 130,
              errorWidget: (_) => _cardPlaceholder(c),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(c.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500)),
        Text(c.year,
            style: const TextStyle(
                color: Color(0xFF999999), fontSize: 10)),
      ]),
    ),
  );

  Widget _cardPlaceholder(ContentModel c) => Container(
    color: genreColor(c.genre).withValues(alpha: 0.3),
    child: Center(
      child: Icon(
        c.type == 'Serie' ? Icons.tv_rounded : Icons.movie_rounded,
        color: Colors.white24, size: 32,
      ),
    ),
  );

} // ← cierre de _HomeScreenState

