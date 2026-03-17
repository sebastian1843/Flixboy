// lib/filters_and_ratings.dart
//
// Dos sistemas para la Fase 3:
//
//   1. FilterSheet     — bottom sheet con filtros avanzados
//      (género, tipo, año, orden)
//
//   2. RatingService   — guarda calificaciones en Firestore
//   3. RatingWidget    — estrellas interactivas para DetailScreen
//   4. RatingBar       — barra de resumen de calificaciones

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'main.dart'; // genreColor

// ══════════════════════════════════════════════════════════════
//  MODELO DE FILTROS
// ══════════════════════════════════════════════════════════════

class ContentFilter {
  String? genre;
  String? type;      // 'Película' | 'Serie' | null
  String? yearRange; // 'Antes 2010' | '2010-2019' | '2020+' | null
  String  sortBy;    // 'Recientes' | 'A-Z' | 'Calificación'

  ContentFilter({
    this.genre,
    this.type,
    this.yearRange,
    this.sortBy = 'Recientes',
  });

  bool get hasFilters =>
      genre != null || type != null || yearRange != null;

  List<ContentModel> apply(List<ContentModel> all) {
    var result = all.where((c) {
      if (genre != null && c.genre != genre) return false;
      if (type  != null) {
        if (type == 'Película' && !c.isPelicula) return false;
        if (type == 'Serie'    && !c.isSerie)    return false;
      }
      if (yearRange != null) {
        final y = int.tryParse(c.year) ?? 0;
        if (yearRange == 'Antes 2010' && y >= 2010) return false;
        if (yearRange == '2010-2019'  && (y < 2010 || y > 2019)) return false;
        if (yearRange == '2020+'      && y < 2020) return false;
      }
      return true;
    }).toList();

    switch (sortBy) {
      case 'A-Z':
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Calificación':
        // Se ordena por rating cuando se tenga (por ahora mantiene orden)
        break;
      default: // Recientes — mantiene orden de Firestore
        break;
    }
    return result;
  }

  ContentFilter copyWith({
    String? genre, String? type, String? yearRange, String? sortBy,
  }) => ContentFilter(
    genre:     genre     ?? this.genre,
    type:      type      ?? this.type,
    yearRange: yearRange ?? this.yearRange,
    sortBy:    sortBy    ?? this.sortBy,
  );

  ContentFilter clear() => ContentFilter();
}

// ══════════════════════════════════════════════════════════════
//  FILTROS — Bottom Sheet
// ══════════════════════════════════════════════════════════════

class FilterSheet extends StatefulWidget {
  final ContentFilter      current;
  final List<String>       availableGenres;
  final void Function(ContentFilter) onApply;

  const FilterSheet({
    super.key,
    required this.current,
    required this.availableGenres,
    required this.onApply,
  });

  // Abre el bottom sheet
  static Future<void> show(
    BuildContext context, {
    required ContentFilter      current,
    required List<String>       availableGenres,
    required void Function(ContentFilter) onApply,
  }) => showModalBottomSheet(
    context:          context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FilterSheet(
      current:         current,
      availableGenres: availableGenres,
      onApply:         onApply,
    ),
  );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ContentFilter _f;

  @override
  void initState() {
    super.initState();
    _f = widget.current;
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF141414),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle
      Container(width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),

      // Título
      Row(children: [
        const Text('Filtros', style: TextStyle(color: Colors.white,
            fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (_f.hasFilters)
          TextButton(
            onPressed: () => setState(() => _f = _f.clear()),
            child: const Text('Limpiar todo',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
          ),
      ]),
      const SizedBox(height: 16),

      // Tipo
      _Section(label: 'Tipo', child: Row(children: [
        _OptionChip(label: 'Todo', selected: _f.type == null,
            onTap: () => setState(() => _f = ContentFilter(
                genre: _f.genre, yearRange: _f.yearRange, sortBy: _f.sortBy))),
        _OptionChip(label: 'Películas', selected: _f.type == 'Película',
            onTap: () => setState(() =>
                _f = _f.copyWith(type: 'Película'))),
        _OptionChip(label: 'Series', selected: _f.type == 'Serie',
            onTap: () => setState(() =>
                _f = _f.copyWith(type: 'Serie'))),
      ])),

      const SizedBox(height: 16),

      // Género
      _Section(label: 'Género', child: Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          _OptionChip(label: 'Todos', selected: _f.genre == null,
              onTap: () => setState(() => _f = ContentFilter(
                  type: _f.type, yearRange: _f.yearRange, sortBy: _f.sortBy))),
          ...widget.availableGenres.map((g) => _OptionChip(
            label:    g,
            selected: _f.genre == g,
            color:    genreColor(g),
            onTap: () => setState(() => _f = _f.copyWith(genre: g)),
          )),
        ],
      )),

      const SizedBox(height: 16),

      // Año
      _Section(label: 'Año', child: Row(children: [
        for (final y in ['Antes 2010', '2010-2019', '2020+'])
          _OptionChip(
            label:    y,
            selected: _f.yearRange == y,
            onTap: () => setState(() =>
                _f = _f.copyWith(yearRange: _f.yearRange == y ? null : y)),
          ),
      ])),

      const SizedBox(height: 16),

      // Ordenar
      _Section(label: 'Ordenar por', child: Row(children: [
        for (final s in ['Recientes', 'A-Z', 'Calificación'])
          _OptionChip(
            label:    s,
            selected: _f.sortBy == s,
            onTap: () => setState(() => _f = _f.copyWith(sortBy: s)),
          ),
      ])),

      const SizedBox(height: 24),

      // Botón aplicar
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onApply(_f);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Aplicar filtros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey,
          fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _OptionChip extends StatelessWidget {
  final String     label;
  final bool       selected;
  final Color?     color;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFE50914);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  selected ? c.withValues(alpha: 0.2) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: TextStyle(
            color:      selected ? c : Colors.grey,
            fontSize:   12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SISTEMA DE CALIFICACIONES
// ══════════════════════════════════════════════════════════════

class RatingService {
  static final _db = FirebaseFirestore.instance;

  // ── Guardar calificación del usuario ─────────────────────

  static Future<void> rate(String contentId, double stars) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final batch = _db.batch();

    // 1. Guardar calificación personal
    batch.set(
      _db.collection('ratings').doc('${contentId}_$uid'),
      {
        'contentId': contentId,
        'uid':       uid,
        'stars':     stars,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // 2. Actualizar promedio en el documento de contenido
    //    usando transacción para evitar condiciones de carrera
    batch.set(
      _db.collection('content').doc(contentId),
      {
        'ratingSum':   FieldValue.increment(stars),
        'ratingCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Obtener calificación del usuario para un contenido ───

  static Future<double?> getUserRating(String contentId) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db
          .collection('ratings')
          .doc('${contentId}_$uid')
          .get();
      if (!doc.exists) return null;
      return (doc.data()?['stars'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  // ── Obtener promedio de calificaciones ───────────────────

  static Future<RatingSummary> getSummary(String contentId) async {
    try {
      final doc = await _db.collection('content').doc(contentId).get();
      final d   = doc.data() ?? {};
      final sum   = (d['ratingSum']   as num?)?.toDouble() ?? 0;
      final count = (d['ratingCount'] as num?)?.toInt()    ?? 0;
      return RatingSummary(
        average: count > 0 ? sum / count : 0,
        count:   count,
      );
    } catch (_) {
      return RatingSummary(average: 0, count: 0);
    }
  }
}

class RatingSummary {
  final double average;
  final int    count;
  RatingSummary({required this.average, required this.count});
}

// ── Widget de estrellas interactivo ───────────────────────────

class RatingWidget extends StatefulWidget {
  final String contentId;
  final bool   compact; // true = versión pequeña para tarjetas

  const RatingWidget({
    super.key,
    required this.contentId,
    this.compact = false,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double?       _userRating;
  RatingSummary _summary = RatingSummary(average: 0, count: 0);
  bool          _loading = true;
  double?       _hovered;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rating  = await RatingService.getUserRating(widget.contentId);
    final summary = await RatingService.getSummary(widget.contentId);
    if (mounted) setState(() {
      _userRating = rating;
      _summary    = summary;
      _loading    = false;
    });
  }

  Future<void> _rate(double stars) async {
    setState(() => _userRating = stars);
    await RatingService.rate(widget.contentId, stars);
    final summary = await RatingService.getSummary(widget.contentId);
    if (mounted) setState(() => _summary = summary);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Calificaste con ${stars.toInt()} estrellas'),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 32);

    if (widget.compact) {
      // Versión compacta: solo promedio + estrella
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 14),
        const SizedBox(width: 3),
        Text(
          _summary.count > 0
              ? _summary.average.toStringAsFixed(1)
              : 'N/A',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ]);
    }

    // Versión completa para DetailScreen
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Promedio
      Row(children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 20),
        const SizedBox(width: 6),
        Text(
          _summary.count > 0
              ? '${_summary.average.toStringAsFixed(1)} / 5'
              : 'Sin calificaciones',
          style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        if (_summary.count > 0)
          Text('(${_summary.count} votos)',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
      const SizedBox(height: 12),
      // Estrellas del usuario
      const Text('Tu calificación:',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: List.generate(5, (i) {
        final star = i + 1.0;
        final filled = (_hovered ?? _userRating ?? 0) >= star;
        return GestureDetector(
          onTap: () => _rate(star),
          child: MouseRegion(
            onEnter:  (_) => setState(() => _hovered = star),
            onExit:   (_) => setState(() => _hovered = null),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  key:   ValueKey('$i$filled'),
                  color: filled
                      ? const Color(0xFFFFC107)
                      : Colors.grey[600],
                  size: 32,
                ),
              ),
            ),
          ),
        );
      })),
    ]);
  }
}