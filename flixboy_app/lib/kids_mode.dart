// lib/kids_mode.dart
//
// Modo niños para Flixboy:
//   • KidsModeScreen   — pantalla principal con UI colorida para niños
//   • KidsModeToggle   — widget para activar/desactivar en perfil
//   • KidsGenreSelector — selector de géneros permitidos para el perfil

import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'profile_manager.dart';
import 'main.dart'; // cloudinaryOptimized, genreColor

// ══════════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL MODO NIÑOS
// ══════════════════════════════════════════════════════════════

class KidsModeScreen extends StatefulWidget {
  final List<ContentModel> allContent;
  const KidsModeScreen({super.key, required this.allContent});

  @override
  State<KidsModeScreen> createState() => _KidsModeScreenState();
}

class _KidsModeScreenState extends State<KidsModeScreen> {
  late List<ContentModel> _content;

  // Géneros con colores e iconos divertidos
  static const _kidsGenres = [
    {'name': 'Animación', 'icon': Icons.animation,       'color': Color(0xFF00BCD4)},
    {'name': 'Aventura',  'icon': Icons.explore_rounded,  'color': Color(0xFF4CAF50)},
    {'name': 'Comedia',   'icon': Icons.emoji_emotions,   'color': Color(0xFFFF9800)},
  ];

  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _content = ProfileManager.filterForProfile(widget.allContent);
  }

  List<ContentModel> get _filtered => _selectedGenre == null
      ? _content
      : _content.where((c) => c.genre == _selectedGenre).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D1B2A),
    body: SafeArea(child: Column(children: [

      // ── Header ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          // Logo kids
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.child_care_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 6),
              const Text('FLIXBOY Kids',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          const Spacer(),
          // Salir del modo niños
          TextButton.icon(
            onPressed: () => _confirmExit(context),
            icon: const Icon(Icons.lock_outline,
                color: Colors.white54, size: 18),
            label: const Text('Salir',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ]),
      ),

      // ── Selector de géneros ──
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // "Todos"
            _GenreChip(
              label: 'Todo',
              icon:  Icons.grid_view_rounded,
              color: const Color(0xFF7B1FA2),
              selected: _selectedGenre == null,
              onTap: () => setState(() => _selectedGenre = null),
            ),
            ..._kidsGenres.map((g) => _GenreChip(
              label:    g['name'] as String,
              icon:     g['icon'] as IconData,
              color:    g['color'] as Color,
              selected: _selectedGenre == g['name'],
              onTap:    () => setState(() =>
                  _selectedGenre = _selectedGenre == g['name']
                      ? null : g['name'] as String),
            )),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // ── Grid de contenido ──
      Expanded(child: _filtered.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎬', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Sin contenido aquí',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ]))
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   3,
                mainAxisSpacing:  12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _KidsContentCard(
                  content: _filtered[i]),
            )),
    ])),
  );

  void _confirmExit(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Salir del modo niños',
          style: TextStyle(color: Colors.white)),
      content: const Text('¿Quieres salir del modo niños?',
          style: TextStyle(color: Colors.grey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Salir'),
        ),
      ],
    ),
  );
}

// ── Chip de género ─────────────────────────────────────────────

class _GenreChip extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:  selected ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color:  selected ? Colors.white : color,
            size:   18),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color:      selected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize:   13)),
      ]),
    ),
  );
}

// ── Tarjeta de contenido kids ──────────────────────────────────

class _KidsContentCard extends StatelessWidget {
  final ContentModel content;
  const _KidsContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final imgUrl = content.imagenUrl.isNotEmpty
        ? cloudinaryOptimized(content.imagenUrl, w: 120, h: 160)
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(content: content))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            imgUrl.isNotEmpty
                ? Image.network(imgUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
            // Borde colorido kids
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: genreColor(content.genre).withValues(alpha: 0.6),
                width: 2,
              ),
            ))),
          ]),
        )),
        const SizedBox(height: 6),
        Text(content.title,
            style: const TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          genreColor(content.genre).withValues(alpha: 0.7),
          const Color(0xFF1A1A2E),
        ],
      ),
    ),
    child: const Icon(Icons.movie_rounded,
        color: Colors.white24, size: 36),
  );
}

// ══════════════════════════════════════════════════════════════
//  SELECTOR DE GÉNEROS PERMITIDOS (para editar perfil)
// ══════════════════════════════════════════════════════════════

class KidsGenreSelector extends StatefulWidget {
  final List<String> selected;
  final void Function(List<String>) onChanged;

  const KidsGenreSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<KidsGenreSelector> createState() => _KidsGenreSelectorState();
}

class _KidsGenreSelectorState extends State<KidsGenreSelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: ProfileData.allGenres.map((g) {
      final sel = _selected.contains(g);
      return GestureDetector(
        onTap: () {
          setState(() {
            sel ? _selected.remove(g) : _selected.add(g);
          });
          widget.onChanged(_selected);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel
                ? genreColor(g).withValues(alpha: 0.2)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? genreColor(g) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(g,
              style: TextStyle(
                  color: sel ? genreColor(g) : Colors.grey,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ),
      );
    }).toList(),
  );
}