// lib/content_screens.dart
// Pantallas de contenido: seguir viendo, próximamente, top10, categorías, búsqueda, detalle.
import 'package:flutter/material.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'app_transitions.dart';
import 'screens.dart';
import 'video_player_screen.dart';
import 'filters_and_ratings.dart';
import 'account_screens.dart';
//  PANTALLA 12: SEGUIR VIENDO (ContinueWatchingSection)
//  Implementada como widget embebido en HomeScreen (via continue_watching.dart)
//  Esta es la pantalla de vista completa de seguir viendo
// ══════════════════════════════════════════════════════════════

class ContinueWatchingScreen extends StatelessWidget {
  const ContinueWatchingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Seguir viendo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        TextButton(
          onPressed: () {},
          child: const Text('Limpiar todo',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
        ),
      ],
    ),
    body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: HistoryManager.all.length,
      itemBuilder: (context, i) {
        final item = HistoryManager.all[i];
        final content = item['content'] as ContentModel?;
        if (content == null) return const SizedBox();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              child: FlixImage(
                url: cloudinaryOptimized(content.imagenUrl, w: 120, h: 80),
                width: 120, height: 80,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(content.title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              if ((item['episode'] as String).isNotEmpty)
                Text(item['episode'] as String,
                    style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
              const SizedBox(height: 6),
              // Barra de progreso
              Container(
                height: 3,
                decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ])),
            IconButton(
              icon: const Icon(Icons.play_circle_fill,
                  color: Color(0xFFE50914), size: 36),
              onPressed: () => Navigator.push(context, AppRoute.playerFade(
                  VideoPlayerScreen(videoUrl: content.videoUrl,
                      title: content.title, content: content))),
            ),
          ]),
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 13: PRÓXIMAMENTE
// ══════════════════════════════════════════════════════════════

class ProximamenteScreen extends StatefulWidget {
  final List<ContentModel> content;
  const ProximamenteScreen({super.key, required this.content});
  @override State<ProximamenteScreen> createState() => _ProximamenteScreenState();
}

class _ProximamenteScreenState extends State<ProximamenteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Próximamente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context,
                AppRoute.slideUp(const NotificationsScreen()))),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF666666),
        indicatorColor: const Color(0xFFE50914),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'Todos'),
          Tab(text: 'Series'),
          Tab(text: 'Películas'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabCtrl,
      children: [
        _buildList(widget.content),
        _buildList(widget.content.where((c) => c.type == 'Serie').toList()),
        _buildList(widget.content.where((c) => c.type == 'Película').toList()),
      ],
    ),
  );

  Widget _buildList(List<ContentModel> items) {
    if (items.isEmpty) return const Center(
      child: Text('Sin contenido próximo', style: TextStyle(color: Color(0xFF999999))));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(children: [
                FlixImage(url: cloudinaryOptimized(c.imagenUrl, w: 400, h: 200),
                    height: 180, fit: BoxFit.cover),
                Container(height: 180,
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        ))),
                Positioned(bottom: 12, left: 12,
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(c.year, style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(c.type, style: const TextStyle(
                          color: Colors.white, fontSize: 12))),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('16 de junio', style: TextStyle(
                      color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: genreColor(c.genre).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: genreColor(c.genre).withValues(alpha: 0.5))),
                    child: Text(c.genre, style: TextStyle(
                        color: genreColor(c.genre), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(c.title, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (c.type == 'Serie')
                  const Text('Temporada 3',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
                const SizedBox(height: 8),
                Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF999999), fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined,
                      color: Color(0xFFE50914), size: 16),
                  label: const Text('Recordarme',
                      style: TextStyle(color: Color(0xFFE50914))),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE50914)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 14: TOP 10
// ══════════════════════════════════════════════════════════════

class Top10Screen extends StatefulWidget {
  final List<ContentModel> content;
  const Top10Screen({super.key, required this.content});
  @override State<Top10Screen> createState() => _Top10ScreenState();
}

class _Top10ScreenState extends State<Top10Screen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final top10 = widget.content.take(10).toList();
    final series  = top10.where((c) => c.type == 'Serie').toList();
    final movies  = top10.where((c) => c.type != 'Serie').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Top 10 en Flixboy',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Text('Hoy', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF666666),
          indicatorColor: const Color(0xFFE50914),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'Series'), Tab(text: 'Películas')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildRankList(series), _buildRankList(movies)],
      ),
    );
  }

  Widget _buildRankList(List<ContentModel> items) => ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: items.length,
    itemBuilder: (context, i) {
      final c = items[i];
      return GestureDetector(
        onTap: () => Navigator.push(context,
            AppRoute.scaleDetail(DetailScreen(content: c))),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            // Número de ranking grande
            SizedBox(
              width: 60,
              child: Center(
                child: Text('${i + 1}',
                  style: TextStyle(
                    fontSize: i < 3 ? 48 : 36,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = const Color(0xFFE50914),
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlixImage(
                url: cloudinaryOptimized(c.imagenUrl, w: 70, h: 100),
                width: 70, height: 100,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star_rounded, color: Color(0xFFE50914), size: 14),
                const SizedBox(width: 4),
                const Text('7.3', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: genreColor(c.genre).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(c.genre, style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 10))),
              ]),
              const SizedBox(height: 8),
              Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 11, height: 1.4)),
            ])),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
              onPressed: () => Navigator.push(context,
                  AppRoute.scaleDetail(DetailScreen(content: c))),
            ),
          ]),
        ),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 15: EXPLORAR CATEGORÍAS
// ══════════════════════════════════════════════════════════════

class ExploreCategoriesScreen extends StatelessWidget {
  final List<ContentModel> allContent;
  const ExploreCategoriesScreen({super.key, required this.allContent});

  static const _categories = [
    {'name': 'Acción',        'icon': Icons.local_fire_department},
    {'name': 'Comedia',       'icon': Icons.emoji_emotions_outlined},
    {'name': 'Terror',        'icon': Icons.nightlight_outlined},
    {'name': 'Romance',       'icon': Icons.favorite_outline},
    {'name': 'Ciencia ficción', 'icon': Icons.rocket_launch_outlined},
    {'name': 'Animé',         'icon': Icons.animation},
    {'name': 'Drama',         'icon': Icons.theater_comedy_outlined},
    {'name': 'Documentales',  'icon': Icons.video_library_outlined},
    {'name': 'Aventura',      'icon': Icons.explore_outlined},
    {'name': 'Suspenso',      'icon': Icons.visibility_outlined},
    {'name': 'Animación',     'icon': Icons.child_friendly_outlined},
    {'name': 'Fantasía',      'icon': Icons.auto_awesome_outlined},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Categorías',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [
      // Tabs Series / Películas
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('Series',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('Películas',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF999999))),
          )),
        ]),
      ),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12,
            mainAxisSpacing: 12, childAspectRatio: 1.5),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat  = _categories[i];
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;
          return GestureDetector(
            onTap: () => Navigator.push(context, AppRoute.slideRight(
                CategoryScreen(genre: name, allContent: allContent))),
            child: Container(
              decoration: BoxDecoration(
                color: genreColor(name).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(children: [
                Positioned(right: -10, bottom: -10,
                  child: Icon(icon, size: 80,
                      color: Colors.black.withValues(alpha: 0.2))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const Spacer(),
                    Text(name, style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
            ),
          );
        },
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA CATEGORÍA ESPECÍFICA
// ══════════════════════════════════════════════════════════════

class CategoryScreen extends StatelessWidget {
  final String genre;
  final List<ContentModel> allContent;
  const CategoryScreen({super.key, required this.genre, required this.allContent});

  @override
  Widget build(BuildContext context) {
    final items = allContent.where((c) => c.genre == genre).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text(genre,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8,
            mainAxisSpacing: 8, childAspectRatio: 0.65),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final c = items[i];
          return GestureDetector(
            onTap: () => Navigator.push(context,
                AppRoute.scaleDetail(DetailScreen(content: c))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlixImage(
                url: cloudinaryOptimized(c.imagenUrl, w: 120, h: 180),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 16: BÚSQUEDA
// ══════════════════════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  final List<ContentModel> allContent;
  const SearchScreen({super.key, required this.allContent});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl     = TextEditingController();
  final _debounce = Debouncer();
  String _query   = '';
  ContentFilter _filter = ContentFilter();
  final List<String> _recentSearches = ['Stranger Things', 'The Witcher', 'La Casa de Papel'];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce.dispose();
    super.dispose();
  }

  List<ContentModel> get _results => _query.isEmpty
      ? []
      : _filter.apply(widget.allContent.where((c) =>
              c.title.toLowerCase().contains(_query.toLowerCase()) ||
              c.genre.toLowerCase().contains(_query.toLowerCase()))
          .toList());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: TextField(
        controller: _ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar películas, series...',
          hintStyle: const TextStyle(color: Color(0xFF999999)),
          filled: true, fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF999999)),
                  onPressed: () { _ctrl.clear(); setState(() => _query = ''); })
              : null,
        ),
        onChanged: (v) => _debounce.run(() {
          if (mounted) setState(() => _query = v);
        }),
      ),
      actions: [
        Stack(children: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => FilterSheet.show(
              context,
              current: _filter,
              availableGenres: widget.allContent.map((c) => c.genre).toSet().toList()..sort(),
              onApply: (f) => setState(() => _filter = f),
            ),
          ),
          if (_filter.hasFilters) Positioned(right: 8, top: 8,
            child: Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFFE50914), shape: BoxShape.circle))),
        ]),
      ],
    ),
    body: _query.isEmpty
        ? _buildHomeSearch()
        : _results.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 60,
                    color: const Color(0xFF999999).withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No se encontró "$_query"',
                    style: const TextStyle(color: Color(0xFF999999), fontSize: 16)),
              ]))
            : _list(),
  );

  Widget _buildHomeSearch() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Búsquedas recientes
      if (_recentSearches.isNotEmpty) ...[
        const Text('Búsquedas recientes', style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._recentSearches.map((s) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history, color: Color(0xFF666666), size: 20),
          title: Text(s, style: const TextStyle(color: Color(0xFF999999))),
          trailing: const Icon(Icons.close, color: Color(0xFF444444), size: 18),
          onTap: () {
            _ctrl.text = s;
            setState(() => _query = s);
          },
        )).toList(),
        const Divider(color: Color(0xFF1E1E1E), height: 24),
      ],
      // Categorías
      const Text('Buscar por categoría', style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5,
        children: [
          {'name': 'Acción',   'icon': Icons.local_fire_department},
          {'name': 'Drama',    'icon': Icons.theater_comedy},
          {'name': 'Comedia',  'icon': Icons.emoji_emotions},
          {'name': 'Terror',   'icon': Icons.nightlight},
          {'name': 'Aventura', 'icon': Icons.explore},
          {'name': 'Sci-Fi',   'icon': Icons.rocket_launch},
        ].map((g) {
          final name = g['name'] as String;
          return GestureDetector(
            onTap: () { _ctrl.text = name; setState(() => _query = name); },
            child: Container(
              decoration: BoxDecoration(
                  color: genreColor(name),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(g['icon'] as IconData, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      // Recomendaciones
      const Text('Recomendaciones', style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (widget.allContent.isNotEmpty)
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.allContent.take(6).length,
            itemBuilder: (_, i) {
              final c = widget.allContent[i];
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    AppRoute.scaleDetail(DetailScreen(content: c))),
                child: Container(
                  width: 100, margin: const EdgeInsets.only(right: 8),
                  child: Column(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FlixImage(url: cloudinaryOptimized(c.imagenUrl, w: 100, h: 140)),
                    )),
                    const SizedBox(height: 4),
                    Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF999999), fontSize: 10)),
                  ]),
                ),
              );
            },
          ),
        ),
    ]),
  );

  Widget _list() => StaggerList(
    children: _results.map((item) => GestureDetector(
      onTap: () => Navigator.push(context,
          AppRoute.scaleDetail(DetailScreen(content: item))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12)),
            child: item.imagenUrl.isNotEmpty
                ? FlixImage(
                    url: cloudinaryOptimized(item.imagenUrl, w: 90, h: 90),
                    width: 90, height: 90,
                    errorWidget: (_) => _sPlaceholder(item))
                : _sPlaceholder(item),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: genreColor(item.genre),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(item.genre, style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 6),
                Text(item.type, style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Text('${item.year} - ${item.duration}',
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
            ]),
          )),
          const Icon(Icons.chevron_right, color: Color(0xFF999999)),
          const SizedBox(width: 8),
        ]),
      ),
    )).toList(),
  );

  Widget _sPlaceholder(ContentModel item) => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: [genreColor(item.genre), const Color(0xFF1A1A1A)])),
    child: Icon(item.type == 'Serie' ? Icons.tv : Icons.movie,
        size: 36, color: Colors.white.withValues(alpha: 0.4)));
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 17 & 18: DETALLE DE PELÍCULA / SERIE
// ══════════════════════════════════════════════════════════════

class DetailScreen extends StatefulWidget {
  final ContentModel content;
  const DetailScreen({super.key, required this.content});
  @override State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  ContentModel get c => widget.content;
  bool _inList = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _inList = WatchlistManager.isInWatchlist(c.title);
    WatchlistManager.addListener(_onWatchlistChanged);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  void _onWatchlistChanged() {
    if (mounted) setState(() => _inList = WatchlistManager.isInWatchlist(c.title));
  }

  @override
  void dispose() {
    WatchlistManager.removeListener(_onWatchlistChanged);
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    WatchlistManager.toggle(c.toMap());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          WatchlistManager.isInWatchlist(c.title)
              ? '✓ Agregado a Mi Lista'
              : 'Eliminado de Mi Lista',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE50914), width: 1)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: FadeTransition(
      opacity: _fadeIn,
      child: Stack(children: [
        Positioned.fill(child: _buildBackground()),
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.36),
              _buildInfoPanel(),
            ]),
          )),
        ])),
      ]),
    ),
  );

  Widget _buildBackground() => Stack(fit: StackFit.expand, children: [
    if (c.imagenUrl.isNotEmpty)
      FlixImage(url: c.imagenUrl, fit: BoxFit.cover, errorWidget: (_) => _fallback())
    else
      _fallback(),
    Container(decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Color(0xEE0A0A0A), Color(0x880A0A0A), Color(0x110A0A0A)],
      ),
    )),
    Container(decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.transparent, Color(0xCC0A0A0A), Color(0xFF0A0A0A)],
        stops: [0.0, 0.35, 0.65, 1.0],
      ),
    )),
  ]);

  Widget _fallback() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF3A0000), Color(0xFF0A0A0A)]),
  ));

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(6)),
        child: Text(c.type.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    ]),
  );

  Widget _buildInfoPanel() => Container(
    color: const Color(0xFF0A0A0A),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Row(children: List.generate(5, (i) => Icon(
          i < 3 ? Icons.star_rounded : Icons.star_outline_rounded,
          color: const Color(0xFFE50914), size: 18,
        ))),
        const SizedBox(width: 6),
        const Text('7.3/10', style: TextStyle(
            color: Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4)),
          child: const Text('HD', style: TextStyle(color: Colors.white38, fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE50914).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5)),
          ),
          child: Text(c.genre, style: const TextStyle(
              color: Color(0xFFE50914), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 12),
        const SizedBox(width: 4),
        Text(c.year, style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
        if (c.duration.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(c.duration, style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
        ],
        if (c.isSerie) ...[
          const SizedBox(width: 8),
          const Text('4 temporadas',
              style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
        ],
      ]),
      const SizedBox(height: 14),
      Text(c.title, style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
          height: 1.1, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      if (c.isSerie)
        const Text('Un niño desaparece y un pequeño pueblo descubre un misterio...',
            style: TextStyle(color: Color(0xFF999999), fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      Text(c.description,
          style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13, height: 1.6),
          maxLines: 4, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      // Reparto
      const Text('Reparto: ',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
      const SizedBox(height: 16),
      Container(height: 1, color: const Color(0xFFE50914).withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      // Botones de acción principales
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () {
            HistoryManager.add(c);
            if (c.isSerie) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EpisodesScreen(series: c)));
            } else {
              Navigator.push(context, AppRoute.playerFade(
                  VideoPlayerScreen(videoUrl: c.videoUrl, title: c.title, content: c)));
            }
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproducir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )),
        const SizedBox(width: 12),
        WatchlistBuilder(builder: (_, __) => ElevatedButton.icon(
          onPressed: _toggle,
          icon: Icon(_inList ? Icons.check : Icons.add),
          label: const Text('Mi lista'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )),
      ]),
      if (c.isSerie) ...[
        const SizedBox(height: 12),
        // Temporadas
        const Text('Temporadas', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Row(children: List.generate(4, (i) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EpisodesScreen(series: c))),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: i == 0 ? const Color(0xFFE50914) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${i + 1}', style: TextStyle(
                color: i == 0 ? Colors.white : const Color(0xFF999999),
                fontWeight: FontWeight.bold)),
          ),
        ))),
      ],
      if (c.trailerUrl.isNotEmpty) ...[
        const SizedBox(height: 12),
        _menuItem(icon: Icons.movie_outlined, label: 'Trailer',
            onTap: () => _showTrailerDialog(context)),
      ],
      const SizedBox(height: 20),
      Container(height: 1, color: const Color(0xFFE50914).withValues(alpha: 0.3)),
      const SizedBox(height: 20),
      // Más similares
      const Text('Más similares', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 12),
      const Text('Calificaciones', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 12),
      RatingWidget(contentId: c.id),
    ]),
  );

  Widget _menuItem({
    required IconData icon, required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ]),
        ),
      );

  void _showTrailerDialog(BuildContext context) {
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF141414),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE50914), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(c.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, AppRoute.playerFade(
                    VideoPlayerScreen(videoUrl: c.trailerUrl,
                        title: '${c.title} - Trailer', content: c)));
              },
              child: Stack(alignment: Alignment.center, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: c.imagenUrl.isNotEmpty
                      ? FlixImage(url: c.imagenUrl, height: 200, fit: BoxFit.cover)
                      : Container(height: 200, color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.movie, color: Colors.white24, size: 60)),
                ),
                Container(height: 200, width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12))),
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE50914), shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.5),
                          blurRadius: 24, spreadRadius: 2)]),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40)),
                Positioned(top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('TRAILER', style: TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                        letterSpacing: 1)))),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  HistoryManager.add(c);
                  Navigator.push(context, AppRoute.playerFade(
                      VideoPlayerScreen(videoUrl: c.videoUrl, title: c.title, content: c)));
                },
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                label: const Text('Ver completo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

