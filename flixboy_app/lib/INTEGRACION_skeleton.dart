// ══════════════════════════════════════════════════════════════
//  INTEGRACIÓN — skeleton_loading.dart en HomeScreen
// ══════════════════════════════════════════════════════════════

// ── 1. Copia skeleton_loading.dart en lib/ ───────────────────

// ── 2. Importa en main.dart ───────────────────────────────────
//   import 'skeleton_loading.dart';

// ── 3. En HomeScreen.build() — reemplaza el body ─────────────
//
// ANTES:
//   body: _loadingContent
//       ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
//       : Stack(children: [ ... ]),
//
// DESPUÉS:
//   body: Stack(children: [
//     CustomScrollView(
//       controller: _scrollCtrl,
//       slivers: [
//         if (_loadingContent)
//           // ← Skeleton ocupa toda la pantalla mientras carga
//           const SliverFillRemaining(
//             hasScrollBody: false,
//             child: HomeSkeletonScreen(),
//           )
//         else ...[
//           if (_allContent.isNotEmpty)
//             SliverToBoxAdapter(
//               child: AnimatedOpacity(
//                 opacity: _bannerOpacity,
//                 duration: const Duration(milliseconds: 100),
//                 child: _buildHeroBanner(),
//               ),
//             ),
//           const SliverToBoxAdapter(child: SizedBox(height: 24)),
//           if (_trending.isNotEmpty) ..._buildSection('Tendencias ahora', _trending),
//           if (myList.isNotEmpty) ..._buildSection('Mi Lista', myList.map(...).toList()),
//           ..._allGenres.expand((genre) { ... }),
//           if (_upcoming.isNotEmpty) ..._buildUpcomingSection(),
//           const SliverToBoxAdapter(child: SizedBox(height: 32)),
//         ],
//       ],
//     ),
//     // Sidebar y gestos (igual que antes)
//     if (!_sidebarVisible) Positioned( ... ),
//     if (_sidebarVisible) GestureDetector( ... ),
//     AnimatedPositioned( ... _buildSidebar() ),
//   ]),

// ── 4. En SearchScreen — skeleton mientras busca ─────────────
//
// Si quieres mostrar skeleton mientras se ejecuta una búsqueda
// asíncrona, añade un bool _searching en _SearchScreenState:
//
//   bool _searching = false;
//
//   @override
//   void onChanged(String v) async {
//     setState(() { _query = v; _searching = true; });
//     // Si usas búsqueda en Firestore (ContentService.search):
//     final results = await ContentService.search(v);
//     setState(() { _remoteResults = results; _searching = false; });
//   }
//
// En build():
//   body: _searching
//       ? const SearchSkeletonList()
//       : _query.isEmpty ? _cats() : _results.isEmpty ? ... : _list(),

// ══════════════════════════════════════════════════════════════
//  RESULTADO VISUAL
// ══════════════════════════════════════════════════════════════
// • En vez de un spinner solitario en el centro, el usuario ve
//   el layout completo de la app con bloques grises animados:
//     - Hero banner con título y botones en gris
//     - 3 filas de 5 tarjetas con póster + texto en gris
//   Todo con el shimmer deslizándose de izquierda a derecha.
// • Al cargar el contenido real, aparece con AnimatedOpacity
//   para una transición suave.