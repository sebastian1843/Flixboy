// ══════════════════════════════════════════════════════════════
//  INTEGRACIÓN — Fase 5: Animaciones + Notificaciones Push
// ══════════════════════════════════════════════════════════════

// ── Archivos a copiar en lib/ ─────────────────────────────────
//   • app_transitions.dart
//   • push_notifications.dart

// ── pubspec.yaml — añadir ─────────────────────────────────────
//   firebase_messaging: ^14.9.4
//   flutter_local_notifications: ^17.2.2

// ── Imports en main.dart ──────────────────────────────────────
//   import 'app_transitions.dart';
//   import 'push_notifications.dart';

// ══════════════════════════════════════════════════════════════
//  1. main() — inicializar notificaciones push
// ══════════════════════════════════════════════════════════════

// Reemplaza tu main() actual con este:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await Firebase.initializeApp();
//     await WatchlistManager.init();
//
//     // ← NUEVO: inicializar push notifications
//     await PushNotificationService.init();
//     PushNotificationService.onNotificationTap =
//         NotificationNavigator.handleData;
//
//     try {
//       await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//       await DeviceSecurity.enableSecureScreen();
//     } catch (_) {}
//
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//     await SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//     runApp(const FlixboyApp());
//   }

// ══════════════════════════════════════════════════════════════
//  2. FlixboyApp — añadir navigatorKey
// ══════════════════════════════════════════════════════════════

// En FlixboyApp.build(), añade navigatorKey:
//
//   return MaterialApp(
//     navigatorKey: NotificationNavigator.navigatorKey, // ← NUEVO
//     title: 'Flixboy',
//     debugShowCheckedModeBanner: false,
//     theme: ThemeData.dark().copyWith(...),
//     home: const SplashScreen(),
//   );

// ══════════════════════════════════════════════════════════════
//  3. Login / Logout — suscribir y desuscribir token
// ══════════════════════════════════════════════════════════════

// En _handleLogin() de LoginScreen, después del login exitoso:
//   await PushNotificationService.onLogin();
//
// En el botón "Cerrar sesión" (ProfileScreen y sidebar),
// antes de AuthService.logout():
//   await PushNotificationService.onLogout();
//   await AuthService.logout();

// ══════════════════════════════════════════════════════════════
//  4. Transiciones — reemplaza MaterialPageRoute
// ══════════════════════════════════════════════════════════════

// En main.dart, reemplaza TODOS los Navigator.push así:
//
//   // DetailScreen → scaleDetail
//   Navigator.push(context, AppRoute.scaleDetail(DetailScreen(content: c)));
//
//   // VideoPlayerScreen → playerFade (fade a negro)
//   Navigator.push(context, AppRoute.playerFade(VideoPlayerScreen(...)));
//
//   // SearchScreen, SeriesScreen, MoviesScreen → slideRight
//   Navigator.push(context, AppRoute.slideRight(SearchScreen(...)));
//
//   // NotificationsScreen, WatchlistScreen → slideUp
//   Navigator.push(context, AppRoute.slideUp(NotificationsScreen()));
//
//   // ProfileScreen, BrowseScreen → fade
//   Navigator.push(context, AppRoute.fade(BrowseScreen()));

// ══════════════════════════════════════════════════════════════
//  5. Hero Poster — en tarjetas de contenido
// ══════════════════════════════════════════════════════════════

// En _contentCard() de HomeScreen, reemplaza PreviewCard con:
//
//   TapScale(
//     onTap: () => Navigator.push(context,
//         AppRoute.scaleDetail(DetailScreen(content: c))),
//     child: HeroPoster(
//       contentId:    c.id,
//       imageUrl:     c.imagenUrl,
//       width:        120,
//       height:       160,
//       borderRadius: BorderRadius.circular(6),
//     ),
//   )
//
// En DetailScreen, envuelve la imagen del SliverAppBar con Hero:
//   Hero(
//     tag: 'poster_${c.id}',
//     child: Image.network(...),
//   )

// ══════════════════════════════════════════════════════════════
//  6. StaggerList — en resultados de búsqueda
// ══════════════════════════════════════════════════════════════

// En SearchScreen._list(), envuelve el ListView con StaggerList:
//
//   StaggerList(
//     children: _results.map((item) => _searchItem(item)).toList(),
//   )

// ══════════════════════════════════════════════════════════════
//  7. NotificationPreferences — en ProfileScreen
// ══════════════════════════════════════════════════════════════

// En ProfileScreen, añade en la lista de opciones:
//
//   const Divider(color: Color(0xFF1E1E1E)),
//   const Padding(
//     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//     child: NotificationPreferences(),
//   ),

// ══════════════════════════════════════════════════════════════
//  8. Android — AndroidManifest.xml
// ══════════════════════════════════════════════════════════════

// Añade dentro de <application>:
//
//   <meta-data
//     android:name="com.google.firebase.messaging.default_notification_channel_id"
//     android:value="flixboy_channel" />
//
//   <meta-data
//     android:name="com.google.firebase.messaging.default_notification_icon"
//     android:resource="@mipmap/ic_launcher" />
//
//   <meta-data
//     android:name="com.google.firebase.messaging.default_notification_color"
//     android:resource="@color/colorAccent" />

// ══════════════════════════════════════════════════════════════
//  9. Enviar notificaciones desde Firebase Console
// ══════════════════════════════════════════════════════════════

// Firebase Console → Messaging → Nueva campaña:
//
//   Título:   "Nueva serie disponible 🎬"
//   Cuerpo:   "Ya puedes ver Breaking Bad en Flixboy"
//   Tópico:   new_releases  (llega a todos los usuarios)
//
// O desde código (Cloud Functions):
//
//   await admin.messaging().send({
//     topic: 'new_releases',
//     notification: { title: '...', body: '...' },
//     data: { type: 'new_content', contentId: 'abc123' },
//     android: { channelId: 'flixboy_channel' },
//   });

// ══════════════════════════════════════════════════════════════
//  RESULTADO
// ══════════════════════════════════════════════════════════════
//
//  ✓ Transiciones suaves entre pantallas:
//     - Fade a negro al entrar al reproductor
//     - Scale + fade para DetailScreen
//     - Slide horizontal para navegación
//     - Slide desde abajo para sheets y notificaciones
//
//  ✓ Hero animation: el póster vuela desde la tarjeta
//    hasta la imagen del DetailScreen.
//
//  ✓ TapScale: feedback táctil en todas las tarjetas.
//
//  ✓ StaggerList: los resultados de búsqueda aparecen
//    en cascada al cargar.
//
//  ✓ Notificaciones push con FCM:
//     - Permisos solicitados al iniciar
//     - Token guardado en Firestore por usuario
//     - Notificaciones en primer plano con canal Android
//     - Al tocar notificación navega al contenido correcto
//     - Preferencias por género desde ProfileScreen