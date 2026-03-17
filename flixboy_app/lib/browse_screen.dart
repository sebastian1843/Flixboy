// lib/browse_screen.dart
//
// Pantalla de descubrimiento estilo Netflix para Flixboy.
// Funcionalidades:
//   • Hero banner animado con cambio automático cada 5 segundos
//   • Filas horizontales por género con títulos
//   • Filtros rápidos: Todo / Películas / Series
//   • Tap en cualquier tarjeta → DetailScreen

import 'dart:async';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'preview_card.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with SingleTickerProviderStateMixin {
  List<ContentModel> _all       = [];
  List<ContentModel> _filtered  = [];
  bool               _loading   = true;
  String             _filter    = 'Todo'; // Todo | Películas | Series
  int                _heroIndex = 0;
  Timer?             _heroTimer;

  late AnimationController _heroAnim;
  late Animation<double>   _heroFade;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _heroAnim, curve: Curves.easeIn));
    _loadContent();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroAnim.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final all = await ContentService.getAllContent();
    if (!mounted) return;
    setState(() {
      _all      = all;
      _filtered = all;
      _loading  = false;
    });
    _heroAnim.forward();
    _startHeroTimer();
  }

  void _startHeroTimer() {
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _filtered.isEmpty) return;
      _heroAnim.reverse().then((_) {
        if (!mounted) return;
        setState(() =>
            _heroIndex = (_heroIndex + 1) % _filtered.take(6).length);
        _heroAnim.forward();
      });
    });
  }

  void _applyFilter(String f) {
    setState(() {
      _filter = f;
      _filtered = f == 'Todo'
          ? _all
          : f == 'Películas'
              ? _all.where((c) => c.isPelicula).toList()
              : _all.where((c) => c.isSerie).toList();
      _heroIndex = 0;
    });
  }

  List<String> get _genres {
    final g = <String>{};
    for (final c in _filtered) {
      if (c.genre != 'Proximo estreno') g.add(c.genre);
    }
    return g.toList()..sort();
  }

  ContentModel? get _heroBanner =>
      _filtered.isEmpty ? null : _filtered[_heroIndex % _filtered.length];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080808),
    body: _loading
        ? const Center(child: CircularProgressIndicator(
            color: Color(0xFFE50914)))
        : CustomScrollView(slivers: [

            // ── Hero Banner animado ──
            if (_heroBanner != null)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: _HeroBanner(content: _heroBanner!),
                ),
              ),

            // ── Filtros ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(children: ['Todo', 'Películas', 'Series']
                    .map((f) => _FilterChip(
                          label:    f,
                          selected: _filter == f,
                          onTap:    () => _applyFilter(f),
                        ))
                    .toList()),
              ),
            ),

            // ── Filas por género ──
            ..._genres.expand((genre) {
              final items =
                  _filtered.where((c) => c.genre == genre).toList();
              if (items.isEmpty) return <Widget>[];
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(children: [
                      Container(
                          width: 4, height: 18,
                          decoration: BoxDecoration(
                            color: genreColor(genre),
                            borderRadius: BorderRadius.circular(2),
                          )),
                      const SizedBox(width: 8),
                      Text(genre,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('(${items.length})',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _BrowseCard(
                          content: items[i]),
                    ),
                  ),
                ),
              ];
            }),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ]),
  );
}

// ── Hero Banner ────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final ContentModel content;
  const _HeroBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    final imgUrl = cloudinaryOptimized(content.imagenUrl, w: 800, h: 500);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(content: content))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Stack(fit: StackFit.expand, children: [
          // Imagen
          content.imagenUrl.isNotEmpty
              ? Image.network(imgUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback())
              : _fallback(),
          // Gradiente
          Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC000000), Color(0xFF080808)],
              stops: [0.3, 0.75, 1.0],
            ),
          )),
          // Info
          Positioned(bottom: 36, left: 20, right: 20,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge tipo
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: genreColor(content.genre),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(content.genre,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(content.title,
                    style: const TextStyle(fontSize: 30,
                        fontWeight: FontWeight.w900, color: Colors.white,
                        height: 1.0, letterSpacing: -0.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text(content.description,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13, height: 1.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                Row(children: [
                  _HeroButton(
                    icon:  Icons.play_arrow_rounded,
                    label: 'Reproducir',
                    filled: true,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            DetailScreen(content: content))),
                  ),
                  const SizedBox(width: 10),
                  _HeroButton(
                    icon:  Icons.info_outline_rounded,
                    label: 'Más info',
                    filled: false,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            DetailScreen(content: content))),
                  ),
                ]),
              ]),
          ),
          // Indicadores de posición
          Positioned(bottom: 12, right: 20,
            child: Row(mainAxisSize: MainAxisSize.min,
              children: List.generate(6, (i) => Container(
                width:  i == 0 ? 16 : 6,
                height: 4,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFFE50914)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ))),
          ),
        ]),
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [genreColor(content.genre).withValues(alpha: 0.6),
            const Color(0xFF080808)],
      ),
    ),
  );
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     filled;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:  filled ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: filled ? null : Border.all(
            color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: filled ? Colors.black : Colors.white, size: 20),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color:      filled ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    ),
  );
}

// ── Chip de filtro ─────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.white : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color:      selected ? Colors.black : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize:   13)),
    ),
  );
}

// ── Tarjeta de browse ──────────────────────────────────────────

class _BrowseCard extends StatelessWidget {
  final ContentModel content;
  const _BrowseCard({required this.content});

  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    margin: const EdgeInsets.only(right: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: PreviewCard(
        content: content, width: 120, height: 160,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => DetailScreen(content: content))),
      )),
      const SizedBox(height: 6),
      Text(content.title,
          style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(
            color: genreColor(content.genre), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(content.genre,
            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        const Spacer(),
        Text(content.year,
            style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ]),
    ]),
  );
}