// ══════════════════════════════════════════════════════════════
//  INTEGRACIÓN — Fase 3: Browse + Filtros + Calificaciones
// ══════════════════════════════════════════════════════════════

// ── Archivos a copiar en lib/ ─────────────────────────────────
//   • browse_screen.dart
//   • filters_and_ratings.dart

// ── Imports en main.dart ──────────────────────────────────────
//   import 'browse_screen.dart';
//   import 'filters_and_ratings.dart';

// ══════════════════════════════════════════════════════════════
//  1. Agregar BrowseScreen al sidebar y navegación
// ══════════════════════════════════════════════════════════════

// En _HomeScreenState._buildSidebar(), añade la opción Browse
// en la lista de items del sidebar:
//
//   {'icon': Icons.explore_rounded, 'label': 'Explorar', 'index': 6},
//
// En _onNavTap(), añade el case 6:
//
//   case 6:
//     Navigator.push(context, MaterialPageRoute(
//         builder: (_) => const BrowseScreen()))
//         .then((_) => setState(() => _currentIndex = 0));
//     break;

// ══════════════════════════════════════════════════════════════
//  2. Agregar filtros a SearchScreen
// ══════════════════════════════════════════════════════════════

// En _SearchScreenState, añade el filtro activo:
//
//   ContentFilter _filter = ContentFilter();
//
// En el AppBar de SearchScreen, añade botón de filtros:
//
//   actions: [
//     Stack(children: [
//       IconButton(
//         icon: const Icon(Icons.tune_rounded, color: Colors.white),
//         onPressed: () => FilterSheet.show(
//           context,
//           current:         _filter,
//           availableGenres: widget.allContent
//               .map((c) => c.genre).toSet().toList()..sort(),
//           onApply: (f) => setState(() => _filter = f),
//         ),
//       ),
//       if (_filter.hasFilters)
//         Positioned(right: 8, top: 8,
//           child: Container(width: 8, height: 8,
//             decoration: const BoxDecoration(
//               color: Color(0xFFE50914), shape: BoxShape.circle))),
//     ]),
//   ],
//
// Y aplica el filtro en los resultados:
//
//   List<ContentModel> get _results => _query.isEmpty
//       ? []
//       : _filter.apply(widget.allContent.where((c) =>
//             c.title.toLowerCase().contains(_query.toLowerCase()) ||
//             c.genre.toLowerCase().contains(_query.toLowerCase()))
//           .toList());

// ══════════════════════════════════════════════════════════════
//  3. Agregar RatingWidget a DetailScreen
// ══════════════════════════════════════════════════════════════

// En DetailScreen.build(), dentro del SliverToBoxAdapter,
// DESPUÉS de la descripción (sinopsis), añade:
//
//   const SizedBox(height: 24),
//   const Text('Calificaciones',
//       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
//           color: Colors.white)),
//   const SizedBox(height: 12),
//   RatingWidget(contentId: c.id),
//   const SizedBox(height: 80),
//
// NOTA: elimina el SizedBox(height: 80) que ya estaba al final
// y usa el que está después de RatingWidget.

// ══════════════════════════════════════════════════════════════
//  4. Agregar calificación compacta en tarjetas (opcional)
// ══════════════════════════════════════════════════════════════

// En _contentCard() de HomeScreen, en la fila inferior
// de cada tarjeta, puedes añadir el rating compacto:
//
//   Row(children: [
//     Container(width:8, height:8, ...),  // punto de color
//     const SizedBox(width: 4),
//     Text(c.genre, ...),
//     const Spacer(),
//     RatingWidget(contentId: c.id, compact: true), // ← nuevo
//   ]),

// ══════════════════════════════════════════════════════════════
//  5. Firestore — reglas de seguridad para ratings
// ══════════════════════════════════════════════════════════════

//   match /ratings/{ratingId} {
//     allow read: if true;
//     allow write: if request.auth != null
//                  && ratingId.matches(request.auth.uid + '$');
//                  // Solo el propio usuario puede escribir su rating
//   }

// ══════════════════════════════════════════════════════════════
//  RESULTADO
// ══════════════════════════════════════════════════════════════
//
//  ✓ BrowseScreen: hero banner animado que cambia cada 5s,
//    filtros Todo/Películas/Series, filas por género con
//    barra de color izquierda e indicador de cantidad.
//
//  ✓ FilterSheet: bottom sheet con filtros de tipo, género,
//    año y orden. Badge rojo en el ícono cuando hay filtros.
//
//  ✓ RatingWidget: estrellas interactivas en DetailScreen.
//    Guarda en Firestore. Muestra promedio y cantidad de votos.
//    Versión compacta disponible para tarjetas.
//
//  ✓ Los filtros funcionan también en SearchScreen para
//    refinar los resultados de búsqueda.