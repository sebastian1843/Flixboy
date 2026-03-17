// lib/screens.dart
// ============================================================
//  PANTALLAS NUEVAS:
//  - SeriesScreen    → todas las series agrupadas por género
//  - MoviesScreen    → todas las películas agrupadas por género
//  - CalendarScreen  → próximos estrenos ordenados por año
//
//  IMPORTANTE: agrega este import en main.dart:
//  import 'screens.dart';
// ============================================================

import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'preview_card.dart';

// ============================================================
//  SERIES SCREEN
// ============================================================

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});
  @override State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<ContentModel> _series = [];
  bool _loading = true;
  String _selectedGenre = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final all = await ContentService.getAllContent();
    setState(() {
      _series = all.where((c) => c.type == 'Serie').toList();
      _loading = false;
    });
  }

  List<String> get _genres {
    final g = <String>{'Todos'};
    for (final c in _series) g.add(c.genre);
    return g.toList();
  }

  List<ContentModel> get _filtered => _selectedGenre == 'Todos'
      ? _series
      : _series.where((c) => c.genre == _selectedGenre).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _series.isEmpty
              ? _buildEmpty('No hay series disponibles', Icons.tv_off)
              : Column(children: [
                  _buildGenreFilter(),
                  Expanded(child: _buildGrid()),
                ]),
    );
  }

  Widget _buildGenreFilter() => SizedBox(
    height: 44,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _genres.length,
      itemBuilder: (_, i) {
        final genre = _genres[i];
        final isSelected = genre == _selectedGenre;
        return GestureDetector(
          onTap: () => setState(() => _selectedGenre = genre),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFFE50914) : Colors.white24,
                width: 1,
              ),
            ),
            child: Text(genre, style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        );
      },
    ),
  );

  Widget _buildGrid() => _filtered.isEmpty
      ? _buildEmpty('No hay series en este género', Icons.tv_off)
      : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _contentCard(_filtered[i]),
        );

  Widget _contentCard(ContentModel c) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(content: c))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          c.imagenUrl.isNotEmpty
              ? Image.network(cloudinaryOptimized(c.imagenUrl, w: 200, h: 300), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(c))
              : _placeholder(c),
          if (c.isPremium) Positioned(top: 4, right: 4,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF57C00), borderRadius: BorderRadius.circular(3)),
              child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)))),
        ]),
      )),
      const SizedBox(height: 4),
      Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(c.genre, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
    ]),
  );

  Widget _placeholder(ContentModel c) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [genreColor(c.genre).withOpacity(0.8), const Color(0xFF111111)])),
    child: Center(child: Icon(Icons.tv_rounded, size: 28, color: Colors.white.withOpacity(0.2))),
  );

  Widget _buildEmpty(String msg, IconData icon) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 72, color: Colors.grey.withOpacity(0.3)),
    const SizedBox(height: 16),
    Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16)),
    const SizedBox(height: 8),
    const Text('Agrega series en Firestore con type="Serie"', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
  ]));
}

// ============================================================
//  MOVIES SCREEN
// ============================================================

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});
  @override State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<ContentModel> _movies = [];
  bool _loading = true;
  String _selectedGenre = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final all = await ContentService.getAllContent();
    setState(() {
      _movies = all.where((c) => c.type == 'Pelicula').toList();
      _loading = false;
    });
  }

  List<String> get _genres {
    final g = <String>{'Todos'};
    for (final c in _movies) g.add(c.genre);
    return g.toList();
  }

  List<ContentModel> get _filtered => _selectedGenre == 'Todos'
      ? _movies
      : _movies.where((c) => c.genre == _selectedGenre).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Películas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _movies.isEmpty
              ? _buildEmpty()
              : Column(children: [
                  _buildGenreFilter(),
                  Expanded(child: _buildGrid()),
                ]),
    );
  }

  Widget _buildGenreFilter() => SizedBox(
    height: 44,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _genres.length,
      itemBuilder: (_, i) {
        final genre = _genres[i];
        final isSelected = genre == _selectedGenre;
        return GestureDetector(
          onTap: () => setState(() => _selectedGenre = genre),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFFE50914) : Colors.white24, width: 1),
            ),
            child: Text(genre, style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        );
      },
    ),
  );

  Widget _buildGrid() => _filtered.isEmpty
      ? Center(child: Text('No hay películas en "$_selectedGenre"', style: const TextStyle(color: Colors.grey, fontSize: 14)))
      : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _contentCard(_filtered[i]),
        );

  Widget _contentCard(ContentModel c) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(content: c))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          c.imagenUrl.isNotEmpty
              ? Image.network(cloudinaryOptimized(c.imagenUrl, w: 200, h: 300), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(c))
              : _placeholder(c),
          if (c.isPremium) Positioned(top: 4, right: 4,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF57C00), borderRadius: BorderRadius.circular(3)),
              child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)))),
        ]),
      )),
      const SizedBox(height: 4),
      Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(c.genre, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
    ]),
  );

  Widget _placeholder(ContentModel c) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [genreColor(c.genre).withOpacity(0.8), const Color(0xFF111111)])),
    child: Center(child: Icon(Icons.movie_rounded, size: 28, color: Colors.white.withOpacity(0.2))),
  );

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.movie_creation_outlined, size: 72, color: Colors.grey.withOpacity(0.3)),
    const SizedBox(height: 16),
    const Text('No hay películas disponibles', style: TextStyle(color: Colors.grey, fontSize: 16)),
    const SizedBox(height: 8),
    const Text('Agrega películas en Firestore con type="Pelicula"', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
  ]));
}

// ============================================================
//  CALENDAR SCREEN — Próximos estrenos
// ============================================================

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<ContentModel> _upcoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcoming();
  }

  Future<void> _loadUpcoming() async {
    final all = await ContentService.getAllContent();
    // Incluye contenido con isUpcoming=true O genre='Proximo estreno'
    final upcoming = all.where((c) => c.isUpcoming || c.genre == 'Proximo estreno').toList();
    // Ordena por año
    upcoming.sort((a, b) => a.year.compareTo(b.year));
    setState(() { _upcoming = upcoming; _loading = false; });
  }

  // Agrupa por año
  Map<String, List<ContentModel>> get _groupedByYear {
    final map = <String, List<ContentModel>>{};
    for (final c in _upcoming) {
      map.putIfAbsent(c.year, () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Próximos estrenos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${_upcoming.length} títulos por estrenar', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _upcoming.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildList() {
    final grouped = _groupedByYear;
    final years = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: years.length,
      itemBuilder: (_, i) {
        final year = years[i];
        final items = grouped[year]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Separador de año ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(year, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE50914).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length} títulos', style: const TextStyle(color: Color(0xFFE50914), fontSize: 11))),
            ]),
          ),
          // ── Cards del año ──
          ...items.map((c) => _calendarCard(c)).toList(),
        ]);
      },
    );
  }

  Widget _calendarCard(ContentModel c) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(content: c))),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        // Póster
        ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
          child: SizedBox(width: 80, height: 110,
            child: c.imagenUrl.isNotEmpty
                ? Image.network(cloudinaryOptimized(c.imagenUrl, w: 80, h: 110), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _calendarPlaceholder(c))
                : _calendarPlaceholder(c),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Badge tipo
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: genreColor(c.genre), borderRadius: BorderRadius.circular(4)),
                child: Text(c.type == 'Serie' ? 'SERIE' : 'PELÍCULA', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE50914).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('PRONTO', style: TextStyle(color: Color(0xFFE50914), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ]),
            const SizedBox(height: 6),
            Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: genreColor(c.genre), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(c.genre, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            if (c.description.isNotEmpty)
              Text(c.description, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        )),
        // Año
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.calendar_month, color: Colors.grey.withOpacity(0.5), size: 18),
            const SizedBox(height: 4),
            Text(c.year, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    ),
  );

  Widget _calendarPlaceholder(ContentModel c) => Container(
    color: const Color(0xFF111111),
    child: Stack(fit: StackFit.expand, children: [
      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [genreColor(c.genre).withOpacity(0.5), const Color(0xFF111111)]))),
      Center(child: Icon(c.type == 'Serie' ? Icons.tv_rounded : Icons.movie_rounded, size: 28, color: Colors.white.withOpacity(0.2))),
    ]),
  );

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.calendar_month, size: 72, color: Colors.grey.withOpacity(0.3)),
    const SizedBox(height: 16),
    const Text('No hay próximos estrenos', style: TextStyle(color: Colors.grey, fontSize: 16)),
    const SizedBox(height: 8),
    const Text('Agrega contenido con isUpcoming="true"\no genre="Proximo estreno"', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
  ]));
}