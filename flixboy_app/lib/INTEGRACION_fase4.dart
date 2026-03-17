// ══════════════════════════════════════════════════════════════
//  INTEGRACIÓN — Fase 4: Perfiles + Historial + Modo Niños
// ══════════════════════════════════════════════════════════════

// ── Archivos a copiar en lib/ ─────────────────────────────────
//   • profile_manager.dart
//   • kids_mode.dart

// ── pubspec.yaml — añadir ─────────────────────────────────────
//   shared_preferences: ^2.2.2

// ── Imports en main.dart ──────────────────────────────────────
//   import 'profile_manager.dart';
//   import 'kids_mode.dart';

// ══════════════════════════════════════════════════════════════
//  1. ProfileSelectScreen — activar perfil al seleccionar
// ══════════════════════════════════════════════════════════════

// En _selectProfile(), ANTES de navegar al HomeScreen,
// activa el perfil seleccionado:
//
//   void _selectProfile(UserProfile p) {
//     // Convertir UserProfile → ProfileData
//     final profileData = ProfileData(
//       id:         p.name, // usa el nombre como ID o añade un campo id
//       name:       p.name,
//       image:      p.image,
//       pin:        p.pin,
//       isOwner:    p.isOwner,
//       isKidsMode: p.isKidsMode ?? false,  // ← añadir campo a UserProfile
//     );
//
//     if (p.pin != null) {
//       // ... tu lógica de PIN actual ...
//       // Al confirmar PIN correcto:
//       ProfileManager.setActiveProfile(profileData).then((_) {
//         Navigator.pushReplacement(context,
//             MaterialPageRoute(builder: (_) => const HomeScreen()));
//       });
//     } else {
//       ProfileManager.setActiveProfile(profileData).then((_) {
//         if (profileData.isKidsMode) {
//           // Ir directamente a modo niños
//           Navigator.pushReplacement(context, MaterialPageRoute(
//             builder: (_) => KidsModeScreen(allContent: [])));
//         } else {
//           Navigator.pushReplacement(context,
//               MaterialPageRoute(builder: (_) => const HomeScreen()));
//         }
//       });
//     }
//   }

// ══════════════════════════════════════════════════════════════
//  2. HomeScreen — filtrar contenido por perfil activo
// ══════════════════════════════════════════════════════════════

// En _loadContent() de _HomeScreenState, añade el filtro:
//
//   Future<void> _loadContent() async {
//     final all      = await ContentService.getAllContent();
//     final trending = await ContentService.getTrending();
//     final upcoming = await ContentService.getUpcoming();
//
//     // ← NUEVO: filtrar si es modo niños
//     final filtered = ProfileManager.filterForProfile(all);
//
//     if (mounted) setState(() {
//       _allContent = filtered;          // ← usa filtered
//       _trending   = trending.isNotEmpty
//           ? ProfileManager.filterForProfile(trending)
//           : filtered.take(6).toList();
//       _upcoming   = upcoming;
//       _loadingContent = false;
//     });
//   }

// ══════════════════════════════════════════════════════════════
//  3. VideoPlayerScreen — registrar en historial al reproducir
// ══════════════════════════════════════════════════════════════

// En _initPlayer() de video_player_screen.dart, después de
// inicializar el controller y antes de play():
//
//   // Registrar en historial del perfil
//   await ProfileManager.addToHistory(widget.content);

// ══════════════════════════════════════════════════════════════
//  4. ProfileScreen — añadir acceso a Historial y Modo Niños
// ══════════════════════════════════════════════════════════════

// En _ProfileScreenState.build(), añade opciones en la lista:
//
//   _opt(Icons.history,        'Historial',     () => Navigator.push(context,
//       MaterialPageRoute(builder: (_) => const HistoryScreen()))),
//
//   _opt(Icons.child_care,     'Modo Niños',    () => Navigator.push(context,
//       MaterialPageRoute(builder: (_) => KidsModeScreen(
//           allContent: [] // pasa _allContent del HomeScreen
//       )))),

// ══════════════════════════════════════════════════════════════
//  5. ManageProfilesScreen — añadir toggle de modo niños
// ══════════════════════════════════════════════════════════════

// En _editProfile(), dentro del AlertDialog content,
// añade después del toggle de PIN:
//
//   const SizedBox(height: 12),
//   GestureDetector(
//     onTap: () => set(() => isKidsMode = !isKidsMode),
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(children: [
//         Icon(Icons.child_care_rounded,
//             color: isKidsMode ? const Color(0xFF00BCD4) : Colors.grey,
//             size: 20),
//         const SizedBox(width: 10),
//         Expanded(child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Modo niños',
//                 style: TextStyle(
//                     color: isKidsMode ? Colors.white : Colors.grey)),
//             if (isKidsMode)
//               const Text('Solo muestra contenido infantil',
//                   style: TextStyle(color: Colors.grey, fontSize: 11)),
//           ],
//         )),
//         Switch(
//           value: isKidsMode,
//           onChanged: (v) => set(() => isKidsMode = v),
//           activeColor: const Color(0xFF00BCD4),
//         ),
//       ]),
//     ),
//   ),
//
//   // Selector de géneros si modo niños está activo
//   if (isKidsMode) ...[
//     const SizedBox(height: 12),
//     const Text('Géneros permitidos:',
//         style: TextStyle(color: Colors.grey, fontSize: 12)),
//     const SizedBox(height: 8),
//     KidsGenreSelector(
//       selected:  kidsGenres,
//       onChanged: (genres) => set(() => kidsGenres = genres),
//     ),
//   ],

// ══════════════════════════════════════════════════════════════
//  6. Firestore — reglas de seguridad
// ══════════════════════════════════════════════════════════════

//   match /users/{uid}/profiles/{profileId}/history/{contentId} {
//     allow read, write: if request.auth != null
//                        && request.auth.uid == uid;
//   }

// ══════════════════════════════════════════════════════════════
//  RESULTADO
// ══════════════════════════════════════════════════════════════
//
//  ✓ Cada perfil tiene su propio historial en Firestore.
//
//  ✓ Al activar modo niños en un perfil, HomeScreen solo
//    muestra los géneros permitidos (Animación, Aventura, Comedia).
//
//  ✓ Al seleccionar un perfil con modo niños activado,
//    va directamente a KidsModeScreen con UI colorida.
//
//  ✓ KidsModeScreen tiene filtros por género con chips
//    coloridos y grid de tarjetas con borde de colores.
//
//  ✓ Historial: el usuario puede ver qué vio, cuándo,
//    eliminar entradas individuales o limpiar todo.
//
//  ✓ Swipe a la izquierda en historial para eliminar entrada.