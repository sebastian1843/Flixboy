import 'storage_service.dart';
import 'firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api_service.dart';
import 'security_service.dart';
import 'screens.dart';
import 'preview_card.dart';
import 'video_player_screen.dart';
import 'skeleton_loading.dart';
import 'continue_watching.dart';
import 'progress_service.dart';
import 'profile_manager.dart';
import 'kids_mode.dart';
import 'browse_screen.dart';
import 'filters_and_ratings.dart';
import 'responsive.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audioplayers/audioplayers.dart';

// ══════════════════════════════════════════════════════════════
//  PALETA: SOLO NEGRO Y ROJO
//  Negro fondo:    0xFF0A0A0A
//  Negro card:     0xFF141414
//  Negro surface:  0xFF1A1A1A
//  Negro elevated: 0xFF222222
//  Rojo primario:  0xFFE50914
//  Rojo oscuro:    0xFF8B0000
//  Rojo sutil:     0xFF2A0505
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  HELPERS GLOBALES
// ══════════════════════════════════════════════════════════════

Color genreColor(String genre) {
  switch (genre) {
    case 'Acción':          return const Color(0xFFE50914);
    case 'Drama':           return const Color(0xFF8B0000);
    case 'Comedia':         return const Color(0xFFCC0000);
    case 'Terror':          return const Color(0xFF5C0000);
    case 'Aventura':        return const Color(0xFFB71C1C);
    case 'Sci-Fi':          return const Color(0xFFD32F2F);
    case 'Fantasía':        return const Color(0xFF7B0000);
    case 'Animación':       return const Color(0xFFEF5350);
    case 'Romance':         return const Color(0xFFAD1457);
    case 'Documentales':    return const Color(0xFF4E342E);
    case 'Animé':           return const Color(0xFFB71C1C);
    case 'Ciencia ficción': return const Color(0xFFD32F2F);
    case 'Suspenso':        return const Color(0xFF6D1A1A);
    case 'Proximo estreno': return const Color(0xFF3A0000);
    default:                return const Color(0xFF8B0000);
  }
}

String cloudinaryOptimized(String url, {int w = 300, int h = 450}) {
  if (url.isEmpty || !url.contains('cloudinary.com')) return url;
  return url.replaceFirst('/upload/', '/upload/w_$w,h_$h,c_fill,q_auto,f_auto/');
}

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

// ══════════════════════════════════════════════════════════════
//  API ERROR HANDLER GLOBAL
// ══════════════════════════════════════════════════════════════

enum ApiErrorType { noInternet, unauthorized, serverError, unknown }

class ApiErrorHandler {
  static ApiErrorType classify(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('connection') || msg.contains('network')) {
      return ApiErrorType.noInternet;
    }
    if (msg.contains('401') || msg.contains('unauthenticated') || msg.contains('permission')) {
      return ApiErrorType.unauthorized;
    }
    if (msg.contains('500') || msg.contains('503') || msg.contains('server')) {
      return ApiErrorType.serverError;
    }
    return ApiErrorType.unknown;
  }

  static String message(ApiErrorType type) {
    switch (type) {
      case ApiErrorType.noInternet:   return 'Sin conexión. Revisa tu internet.';
      case ApiErrorType.unauthorized: return 'Sesión expirada. Inicia sesión nuevamente.';
      case ApiErrorType.serverError:  return 'Error del servidor. Intenta más tarde.';
      case ApiErrorType.unknown:      return 'Ocurrió un error inesperado.';
    }
  }

  static Future<void> handle(
    dynamic error,
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    final type = classify(error);
    final msg  = message(type);

    if (type == ApiErrorType.unauthorized) {
      await AuthService.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      }
      return;
    }

    if (type == ApiErrorType.noInternet && context.mounted) {
      Navigator.push(context, AppRoute.fade(const NoInternetScreen()));
      return;
    }

    if (type == ApiErrorType.serverError && context.mounted) {
      Navigator.push(context, AppRoute.fade(ServerErrorScreen(onRetry: onRetry)));
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          if (onRetry != null)
            TextButton(
              onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); onRetry(); },
              child: const Text('Reintentar', style: TextStyle(color: Color(0xFFE50914))),
            ),
        ]),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE50914), width: 1),
        ),
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  SESIÓN PERSISTENTE
// ══════════════════════════════════════════════════════════════

class SessionManager {
  static const _kUid  = 'session_uid';
  static const _kName = 'session_name';

  static Future<void> save(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUid,  user.uid);
    await prefs.setString(_kName, user.displayName ?? '');
  }

  static Future<String?> getSavedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUid);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await prefs.remove(_kName);
  }
}

// ══════════════════════════════════════════════════════════════
//  DEBOUNCE HELPER
// ══════════════════════════════════════════════════════════════

class Debouncer {
  final Duration delay;
  Timer? _timer;
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

// ══════════════════════════════════════════════════════════════
//  WATCHLIST MANAGER
// ══════════════════════════════════════════════════════════════

class WatchlistManager {
  static List<Map<String, String>> _watchlist = [];
  static final _listeners = <VoidCallback>[];

  static List<Map<String, String>> get watchlist => _watchlist;

  static void addListener(VoidCallback cb) => _listeners.add(cb);
  static void removeListener(VoidCallback cb) => _listeners.remove(cb);
  static void _notify() { for (final cb in _listeners) cb(); }

  static Future<void> init() async {
    _watchlist = await StorageService.loadWatchlist();
  }

  static bool isInWatchlist(String title) =>
      _watchlist.any((item) => item['title'] == title);

  static Future<void> toggle(Map<String, String> content) async {
    if (isInWatchlist(content['title']!)) {
      _watchlist.removeWhere((item) => item['title'] == content['title']);
    } else {
      final safe = Map<String, String>.from(content);
      safe.putIfAbsent('trailerUrl', () => '');
      safe.putIfAbsent('isSerie',    () => 'false');
      _watchlist.add(safe);
    }
    await StorageService.saveWatchlist(_watchlist);
    _notify();
  }
}

// ══════════════════════════════════════════════════════════════
//  WATCHLIST LISTENER WIDGET
// ══════════════════════════════════════════════════════════════

class WatchlistBuilder extends StatefulWidget {
  final Widget Function(BuildContext, List<Map<String, String>>) builder;
  const WatchlistBuilder({super.key, required this.builder});
  @override State<WatchlistBuilder> createState() => _WatchlistBuilderState();
}

class _WatchlistBuilderState extends State<WatchlistBuilder> {
  @override
  void initState() {
    super.initState();
    WatchlistManager.addListener(_onChanged);
  }

  void _onChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    WatchlistManager.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, WatchlistManager.watchlist);
}

// ══════════════════════════════════════════════════════════════
//  NOTIFICACIONES IN-APP
// ══════════════════════════════════════════════════════════════

enum NotifType { login, device, password, subscription, security, newContent, upcoming, reminder }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifType type;
  final DateTime time;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.isRead = false,
  });
}

class NotificationsManager {
  static final List<AppNotification> _list = [
    AppNotification(id: '1', title: '¡Nuevo episodio disponible!',    body: 'The Witcher T3 E7 ya está disponible. ¡No te lo pierdas!',                            type: NotifType.newContent,    time: DateTime.now().subtract(const Duration(hours: 3))),
    AppNotification(id: '2', title: 'Estreno esta semana',            body: 'Black Mirror Temporada 7 estrena el viernes.',                                         type: NotifType.upcoming,      time: DateTime.now().subtract(const Duration(hours: 14))),
    AppNotification(id: '3', title: 'Nueva en Flixboy',               body: 'Lupin Parte 3 ya está disponible. ¡Empieza a ver!',                                    type: NotifType.newContent,    time: DateTime.now().subtract(const Duration(hours: 24))),
    AppNotification(id: '4', title: 'Continúa viendo',                body: 'Tienes contenido sin terminar en tu lista. ¿Quieres seguir viendo?',                   type: NotifType.reminder,      time: DateTime.now().subtract(const Duration(hours: 6))),
    AppNotification(id: '5', title: 'Tu suscripción vence pronto',    body: 'Tu plan Premium vence en 3 días. Renuévalo para seguir disfrutando.',                   type: NotifType.subscription,  time: DateTime.now().subtract(const Duration(days: 1))),
    AppNotification(id: '6', title: 'Inicio de sesión detectado',     body: 'Se inició sesión en tu cuenta desde un dispositivo Android en Sincelejo, Colombia.',   type: NotifType.login,         time: DateTime.now().subtract(const Duration(days: 2)), isRead: true),
    AppNotification(id: '7', title: 'Nuevo dispositivo vinculado',    body: 'Tu cuenta fue vinculada a un nuevo dispositivo: Samsung Galaxy S23.',                   type: NotifType.device,        time: DateTime.now().subtract(const Duration(days: 3)), isRead: true),
    AppNotification(id: '8', title: 'Contraseña actualizada',         body: 'Tu contraseña fue cambiada exitosamente. Si no fuiste tú, contacta soporte.',           type: NotifType.password,      time: DateTime.now().subtract(const Duration(days: 4)), isRead: true),
    AppNotification(id: '9', title: 'Alerta de seguridad',            body: 'Detectamos un intento de acceso fallido a tu cuenta. Revisa tu configuración.',         type: NotifType.security,      time: DateTime.now().subtract(const Duration(days: 5)), isRead: true),
  ];

  static List<AppNotification> get all     => _list;
  static int get unreadCount               => _list.where((n) => !n.isRead).length;
  static void markAsRead(String id)        { final i = _list.indexWhere((n) => n.id == id); if (i != -1) _list[i].isRead = true; }
  static void markAllAsRead()              { for (final n in _list) n.isRead = true; }
  static void delete(String id)            => _list.removeWhere((n) => n.id == id);
}

// ══════════════════════════════════════════════════════════════
//  USER PROFILE
// ══════════════════════════════════════════════════════════════

class UserProfile {
  String name;
  String image;
  String? pin;
  bool isOwner;
  bool isKidsMode;

  UserProfile({
    required this.name,
    required this.image,
    this.pin,
    this.isOwner    = false,
    this.isKidsMode = false,
  });
}

// ══════════════════════════════════════════════════════════════
//  CACHED IMAGE WIDGET
// ══════════════════════════════════════════════════════════════

class FlixImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext)? errorWidget;
  final BorderRadius? borderRadius;

  const FlixImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget img = CachedNetworkImage(
      imageUrl: url,
      width:    width,
      height:   height,
      fit:      fit,
      placeholder: (ctx, _) => placeholder?.call(ctx) ??
          Container(
            width: width, height: height,
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFE50914), strokeWidth: 1.5),
              ),
            ),
          ),
      errorWidget: (ctx, _, __) => errorWidget?.call(ctx) ??
          Container(
            width: width, height: height,
            color: const Color(0xFF1A1A1A),
            child: const Icon(Icons.broken_image_outlined,
                color: Color(0xFF444444), size: 28),
          ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

// ══════════════════════════════════════════════════════════════
//  PAGINACIÓN — CONTENT PAGINATOR
// ══════════════════════════════════════════════════════════════

class ContentPaginator {
  final int pageSize;
  final List<ContentModel> _all = [];
  final List<ContentModel> _visible = [];
  bool _hasMore = true;
  bool _loading = false;

  ContentPaginator({this.pageSize = 20});

  List<ContentModel> get visible => _visible;
  bool get hasMore  => _hasMore;
  bool get loading  => _loading;

  void setAll(List<ContentModel> data) {
    _all
      ..clear()
      ..addAll(data);
    _visible.clear();
    _hasMore = true;
    loadMore();
  }

  bool loadMore() {
    if (_loading || !_hasMore) return false;
    _loading = true;
    final start = _visible.length;
    final end   = (start + pageSize).clamp(0, _all.length);
    _visible.addAll(_all.sublist(start, end));
    _hasMore  = end < _all.length;
    _loading  = false;
    return end > start;
  }
}

// ══════════════════════════════════════════════════════════════
//  HISTORY MANAGER
// ══════════════════════════════════════════════════════════════

class HistoryManager {
  static final List<Map<String, dynamic>> _history = [];

  static List<Map<String, dynamic>> get all => _history;

  static void add(ContentModel content, {String? episode}) {
    _history.removeWhere((h) => h['title'] == content.title);
    _history.insert(0, {
      'title':    content.title,
      'genre':    content.genre,
      'type':     content.type,
      'imagenUrl': content.imagenUrl,
      'episode':  episode ?? '',
      'watchedAt': DateTime.now(),
      'content':  content,
    });
  }

  static void remove(String title) =>
      _history.removeWhere((h) => h['title'] == title);

  static void clear() => _history.clear();
}

// ══════════════════════════════════════════════════════════════
//  SETTINGS MANAGER
// ══════════════════════════════════════════════════════════════

class SettingsManager {
  static bool autoPlay          = true;
  static String videoQuality    = 'Automática';
  static String audioLanguage   = 'Español';
  static String subtitleLanguage = 'Español';
  static bool notifications     = true;
  static String parentalPin     = '';
  static String minRating       = 'Todos';

  static final List<String> qualities = ['Automática', 'Alta (HD)', 'Media', 'Baja'];
  static final List<String> languages = ['Español', 'Español (Latino)', 'Inglés', 'Portugués'];
  static final List<String> ratings   = ['Todos', '7+', '13+', '16+', '18+'];
}

// ══════════════════════════════════════════════════════════════
//  MAIN
// ══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Firebase.initializeApp();
  await WatchlistManager.init();

  await PushNotificationService.init();
  PushNotificationService.onNotificationTap = NotificationNavigator.handleData;

  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await DeviceSecurity.enableSecureScreen();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // ✅ CORREGIDO
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
]);

runApp(const FlixboyApp());
}

// ══════════════════════════════════════════════════════════════
//  APP
// ══════════════════════════════════════════════════════════════

class FlixboyApp extends StatelessWidget {
  const FlixboyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: NotificationNavigator.navigatorKey,
    title: 'Flixboy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: const ColorScheme.dark(
        primary:   Color(0xFFE50914),
        secondary: Color(0xFF8B0000),
        surface:   Color(0xFF141414),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
          foregroundColor: Colors.white,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
            ? const Color(0xFFE50914)
            : const Color(0xFF444444)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(const Color(0xFFE50914)),
        side: const BorderSide(color: Color(0xFF8C8C8C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
    ),
    home: const SplashScreen(),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 1: SPLASH SCREEN
// ══════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fCtrl;
  late AnimationController _linesCtrl;
  late AnimationController _nameCtrl;

  late Animation<double> _fScale;
  late Animation<double> _fOpacity;
  late Animation<double> _linesOpacity;
  late Animation<double> _nameOpacity;
  late Animation<double> _nameScale;

  final List<_Line> _lines = [];
  bool _linesReady = false;

  @override
  void initState() {
    super.initState();

    // Controlador de la F
    _fCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));

    _fScale = Tween<double>(begin: 1.0, end: 80.0).animate(
        CurvedAnimation(parent: _fCtrl, curve: Curves.easeIn));

    _fOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_fCtrl);

    // Controlador de líneas
    _linesCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _linesOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_linesCtrl);

    // Controlador del nombre
    _nameCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _nameCtrl, curve: Curves.easeOut));

    _nameScale = Tween<double>(begin: 1.15, end: 1.0).animate(
        CurvedAnimation(parent: _nameCtrl, curve: Curves.easeOutBack));

    _playIntro();
  }

  void _buildLines(Size size) {
    final colors = [
      const Color(0xFFE50914), const Color(0xFFCC0000), const Color(0xFFFF4500),
      const Color(0xFFFF6600), const Color(0xFFFFAA00), const Color(0xFFFFCC00),
      const Color(0xFFFF1493), const Color(0xFF9B59B6), const Color(0xFF3498DB),
      const Color(0xFF00BCD4), const Color(0xFFE91E63), const Color(0xFFFF5722),
      const Color(0xFF8E44AD), const Color(0xFF2980B9), const Color(0xFFF39C12),
    ];
    final rng = DateTime.now().millisecondsSinceEpoch;
    _lines.clear();
    final cx = size.width / 2;
    for (int i = 0; i < 60; i++) {
      final seed = (rng + i * 137) % 1000 / 1000.0;
      _lines.add(_Line(
        x: cx + (seed - 0.5) * 40,
        width: 1.5 + seed * 5,
        color: colors[i % colors.length],
        speed: 180 + seed * 400,
        delay: seed * 0.4,
        opacity: 0.6 + seed * 0.4,
      ));
    }
    _linesReady = true;
  }

  Future<void> _playIntro() async {
    // 1. Pantalla negra por 600ms
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Reproducir sonido
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/intro.mp3'));
    } catch (_) {}

    // 2. La F crece
    _fCtrl.forward();

    // 3. Líneas aparecen cuando la F ya creció bastante
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    _linesCtrl.forward();

    // 4. El nombre aparece al final
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _nameCtrl.forward();

    // 5. Navegar
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
  final savedUid = await SessionManager.getSavedUid();
  final firebaseUser = await FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  if (!mounted) return;
  if (firebaseUser != null) await SessionManager.save(firebaseUser);
  if (firebaseUser == null && savedUid != null) await SessionManager.clear();
  final isLoggedIn = firebaseUser != null || savedUid != null;

  if (!mounted) return;

  Navigator.pushReplacement(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) =>
        isLoggedIn ? const ProfileSelectScreen() : const LoginScreen(),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 500),
  ));
}

  @override
  void dispose() {
    _fCtrl.dispose();
    _linesCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_linesReady) _buildLines(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Líneas de colores (canvas)
            AnimatedBuilder(
              animation: _linesCtrl,
              builder: (_, __) => CustomPaint(
                painter: _LinesPainter(
                  lines: _lines,
                  progress: _linesCtrl.value,
                  opacity: _linesOpacity.value,
                  size: size,
                ),
              ),
            ),
            // La F que crece
            AnimatedBuilder(
              animation: _fCtrl,
              builder: (_, __) => Opacity(
                opacity: _fOpacity.value,
                child: Center(
                  child: Transform.scale(
                    scale: _fScale.value,
                    child: Text(
                      'F',
                      style: TextStyle(
                        fontFamily: 'Arial Black',
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE50914),
                        shadows: [
                          Shadow(
                            color: const Color(0xFFE50914).withValues(alpha: 0.7),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Nombre completo "Flixboy"
            AnimatedBuilder(
              animation: _nameCtrl,
              builder: (_, __) => Opacity(
                opacity: _nameOpacity.value,
                child: Center(
                  child: Transform.scale(
                    scale: _nameScale.value,
                    child: Text(
                      'Flixboy',
                      style: TextStyle(
                        fontFamily: 'Arial Black',
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFE50914).withValues(alpha: 0.5),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// Modelo de línea
class _Line {
  final double x, width, speed, delay, opacity;
  final Color color;
  _Line({
    required this.x,
    required this.width,
    required this.color,
    required this.speed,
    required this.delay,
    required this.opacity,
  });
}

// Painter para las líneas
class _LinesPainter extends CustomPainter {
  final List<_Line> lines;
  final double progress;
  final double opacity;
  final Size size;

  _LinesPainter({
    required this.lines,
    required this.progress,
    required this.opacity,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size s) {
    for (final l in lines) {
      final t = (progress - l.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final spread = t * l.speed;
      final alpha = (t * 3).clamp(0.0, 1.0) * l.opacity * opacity;

      final paint = Paint()
        ..color = l.color.withValues(alpha: alpha)
        ..strokeWidth = l.width
        ..strokeCap = StrokeCap.round;

      // Línea izquierda
      canvas.drawLine(
        Offset(l.x - spread, 0),
        Offset(l.x - spread, size.height),
        paint,
      );
      // Línea derecha
      canvas.drawLine(
        Offset(l.x + spread, 0),
        Offset(l.x + spread, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => true;
}
// ══════════════════════════════════════════════════════════════
//  PANTALLA 2: BIENVENIDO (Welcome / Onboarding)
// ══════════════════════════════════════════════════════════════

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.movie_filter_rounded,
      'title': 'Películas, series y\nmucho más.',
      'subtitle': 'Sin límites.',
      'desc': 'Accede a miles de películas y series de todos los géneros.',
    },
    {
      'icon': Icons.devices_rounded,
      'title': 'Ve en cualquier\ndispositivo.',
      'subtitle': 'Siempre contigo.',
      'desc': 'Disfruta tu contenido favorito desde tu móvil, tablet o TV.',
    },
    {
      'icon': Icons.download_rounded,
      'title': 'Descarga y ve\nsin internet.',
      'subtitle': 'Sin interrupciones.',
      'desc': 'Guarda episodios y películas para verlos cuando quieras.',
    },
  ];

  int _currentPage = 0;
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override void dispose() { _animCtrl.dispose(); _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF2A0505), Color(0xFF0A0A0A)],
        ),
      )),
      SafeArea(child: Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushReplacement(
                context, AppRoute.fade(const LoginScreen())),
            child: const Text('Omitir', style: TextStyle(
                color: Color(0xFF999999), fontSize: 14)),
          ),
        ),
        Expanded(child: PageView.builder(
          controller: _pageCtrl,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (_, i) {
            final p = _pages[i];
            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 2),
                      ),
                      child: Icon(p['icon'] as IconData,
                          color: const Color(0xFFE50914), size: 60),
                    ),
                    const SizedBox(height: 40),
                    const Text('FLIXBOY', style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: Color(0xFFE50914), letterSpacing: 6)),
                    const SizedBox(height: 24),
                    Text(p['title'] as String, style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold,
                        color: Colors.white, height: 1.3),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(p['subtitle'] as String, style: const TextStyle(
                        fontSize: 20, color: Color(0xFFE50914),
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Text(p['desc'] as String, style: const TextStyle(
                        color: Color(0xFF999999), fontSize: 15, height: 1.6),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            );
          },
        )),
        // Indicadores de página
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
          _pages.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == i ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == i
                  ? const Color(0xFFE50914)
                  : const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        )),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(children: [
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut);
                  } else {
                    Navigator.pushReplacement(
                        context, AppRoute.fade(const LoginScreen()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _currentPage < _pages.length - 1 ? 'Siguiente' : 'Comenzar',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('¿Ya tienes cuenta? ',
                  style: TextStyle(color: Color(0xFF999999))),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                    context, AppRoute.fade(const LoginScreen())),
                child: const Text('Inicia sesión',
                    style: TextStyle(
                        color: Color(0xFFE50914),
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 32),
          ]),
        ),
      ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 3: LOGIN SCREEN
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true, _isLoading = false, _rememberMe = false;

  late final Future<DocumentSnapshot> _bgFuture =
      FirebaseFirestore.instance.collection('config').doc('app').get();

  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)));

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _snack('Por favor completa todos los campos'); return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.login(
          email: _emailCtrl.text.trim(), password: _passCtrl.text);
      if (!mounted) return;
      if (result.success) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await SessionManager.save(user);
        await PushNotificationService.onLogin();
        Navigator.pushReplacement(
            context, AppRoute.fade(const ProfileSelectScreen()));
      } else {
        _snack(result.message ?? 'Error al iniciar sesión');
      }
    } catch (e) {
      if (!mounted) return;
      await ApiErrorHandler.handle(e, context, onRetry: _handleLogin);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(fit: StackFit.expand, children: [
      FutureBuilder<DocumentSnapshot>(
        future: _bgFuture,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final url  = data?['loginBackground'] as String? ?? '';
          if (url.isEmpty) return Container(color: const Color(0xFF141414));
          return Positioned.fill(
            child: FlixImage(url: url, fit: BoxFit.cover,
              errorWidget: (_) => Container(color: const Color(0xFF141414))),
          );
        },
      ),
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x44000000), Color(0xCC000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      )),
      SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 60),
          const Text('FLIXBOY', style: TextStyle(
              fontSize: 52, fontWeight: FontWeight.w900,
              color: Color(0xFFE50914), letterSpacing: 4)),
          const SizedBox(height: 8),
          const Text('Inicia sesión para continuar',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          const SizedBox(height: 50),
          _field(controller: _emailCtrl,
              hint: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl, obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: const TextStyle(color: Color(0xFF8C8C8C)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8C8C8C)),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF8C8C8C)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Text('Iniciar sesión',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                SizedBox(width: 20, height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: const Color(0xFFE50914),
                    side: const BorderSide(color: Color(0xFF8C8C8C)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                  )),
                const SizedBox(width: 8),
                const Text('Recuérdame',
                    style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
              ]),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    AppRoute.slideUp(const ForgotPasswordScreen())),
                child: const Text('¿Olvidaste tu contraseña?',
                    style: TextStyle(
                        color: Color(0xFFE50914), fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Eres nuevo en Flixboy? ',
                style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 15)),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  AppRoute.slideRight(const RegisterScreen())),
              child: const Text('Regístrate ahora',
                  style: TextStyle(
                      color: Color(0xFFE50914), fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 24),
          const Text(
            'El acceso está protegido por reCAPTCHA de Google.',
            style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ]),
      )),
    ]),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8C8C8C)),
          prefixIcon: Icon(icon, color: const Color(0xFF8C8C8C)),
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 18),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 4: REGISTRO
// ══════════════════════════════════════════════════════════════

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _op = true, _oc = true, _isLoading = false, _acceptTerms = false;

  @override void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)));

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      _snack('Completa todos los campos'); return;
    }
    if (!_acceptTerms) { _snack('Acepta los Términos de uso'); return; }
    if (_passCtrl.text.length < 6) { _snack('Mínimo 6 caracteres'); return; }
    if (_passCtrl.text != _confirmCtrl.text) { _snack('Las contraseñas no coinciden'); return; }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.register(
          name:     _nameCtrl.text.trim(),
          email:    _emailCtrl.text.trim(),
          password: _passCtrl.text);
      if (!mounted) return;
      if (result.success) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await SessionManager.save(user);
        await PushNotificationService.onLogin();
        Navigator.pushReplacement(
            context, AppRoute.fade(const RegisterSuccessScreen()));
      } else {
        _snack(result.message ?? 'Error al registrarse');
      }
    } catch (e) {
      if (!mounted) return;
      await ApiErrorHandler.handle(e, context, onRetry: _register);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
      )),
      SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 30),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const Text('FLIXBOY', style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.bold,
              color: Color(0xFFE50914), letterSpacing: 6)),
          const SizedBox(height: 8),
          const Text('Crea tu cuenta',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          const SizedBox(height: 32),
          _f(_nameCtrl,  'Nombre completo',    Icons.person_outline),
          const SizedBox(height: 16),
          _f(_emailCtrl, 'Correo electrónico', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _pw(_passCtrl,    'Contraseña',           _op,
              () => setState(() => _op = !_op)),
          const SizedBox(height: 16),
          _pw(_confirmCtrl, 'Confirmar contraseña', _oc,
              () => setState(() => _oc = !_oc)),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              width: 20, height: 20,
              child: Checkbox(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                activeColor: const Color(0xFFE50914),
                side: const BorderSide(color: Color(0xFF8C8C8C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: RichText(text: const TextSpan(
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              children: [
                TextSpan(text: 'Acepto los '),
                TextSpan(text: 'Términos de uso',
                    style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
                TextSpan(text: ' y la '),
                TextSpan(text: 'Política de privacidad',
                    style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
              ],
            ))),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Registrarme',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Ya tienes cuenta?',
                style: TextStyle(color: Color(0xFF999999))),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Inicia sesión',
                  style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 20),
        ]),
      )),
    ]),
  );

  Widget _f(TextEditingController c, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) =>
      TextField(
          controller: c, keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xFF999999)),
            prefixIcon: Icon(icon, color: const Color(0xFF999999)),
            filled: true, fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ));

  Widget _pw(TextEditingController c, String label, bool ob, VoidCallback t) =>
      TextField(
          controller: c, obscureText: ob,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xFF999999)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF999999)),
            suffixIcon: IconButton(
              icon: Icon(ob ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF999999)),
              onPressed: t,
            ),
            filled: true, fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ));
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 5: RECUPERAR CONTRASEÑA
// ══════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override void dispose() { _emailCtrl.dispose(); super.dispose(); }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)));

  Future<void> _send() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _snack('Ingresa tu correo'); return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.forgotPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      if (result.success) {
        Navigator.pushReplacement(context,
            AppRoute.fade(EmailSentScreen(email: _emailCtrl.text.trim())));
      } else {
        _snack(result.message ?? 'Error al enviar correo');
      }
    } catch (e) {
      if (!mounted) return;
      await ApiErrorHandler.handle(e, context, onRetry: _send);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Align(alignment: Alignment.centerLeft,
            child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
          const SizedBox(height: 20),
          Container(width: 80, height: 80,
            decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 2)),
            child: const Icon(Icons.lock_reset, size: 40, color: Color(0xFFE50914))),
          const SizedBox(height: 24),
          const Text('¿Olvidaste tu\ncontraseña?',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold,
                color: Colors.white, height: 1.3),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('Ingresa tu correo electrónico y te enviaremos un enlace para restablecerla.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),
          TextField(
            controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: const TextStyle(color: Color(0xFF999999)),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF999999)),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar enlace',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 6: CORREO ENVIADO
// ══════════════════════════════════════════════════════════════

class EmailSentScreen extends StatelessWidget {
  final String email;
  const EmailSentScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
      )),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 3),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                size: 60, color: Color(0xFFE50914)),
          ),
          const SizedBox(height: 32),
          const Text('¡Correo enviado!',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Text(
            'Hemos enviado un enlace de recuperación a\n$email',
            style: const TextStyle(
                color: Color(0xFF999999), fontSize: 15, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text('Revisa tu bandeja de entrada y sigue las instrucciones.',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 48),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                  AppRoute.fade(const LoginScreen()), (r) => false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ir al inicio de sesión',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reenviar correo',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          ),
        ]),
      ))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 7: RESTABLECER CONTRASEÑA
// ══════════════════════════════════════════════════════════════

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _o1 = true, _o2 = true, _isLoading = false;

  String _strength(String p) {
    if (p.isEmpty) return '';
    if (p.length < 6) return 'Muy débil';
    bool hasUpper  = p.contains(RegExp(r'[A-Z]'));
    bool hasDigit  = p.contains(RegExp(r'[0-9]'));
    bool hasSpecial = p.contains(RegExp(r'[!@#\$%^&*]'));
    if (hasUpper && hasDigit && hasSpecial && p.length >= 8) return 'Fuerte';
    if ((hasUpper || hasDigit) && p.length >= 6) return 'Media';
    return 'Débil';
  }

  Color _strengthColor(String s) {
    switch (s) {
      case 'Fuerte': return Colors.green;
      case 'Media':  return Colors.orange;
      case 'Débil':  return Colors.red;
      default:       return Colors.red;
    }
  }

  @override void dispose() { _newCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pass     = _newCtrl.text;
    final strength = _strength(pass);

    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
        )),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Align(alignment: Alignment.centerLeft,
              child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context))),
            const SizedBox(height: 20),
            const Text('FLIXBOY', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold,
                color: Color(0xFFE50914), letterSpacing: 6)),
            const SizedBox(height: 24),
            const Text('Crea una nueva\ncontraseña',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold,
                    color: Colors.white, height: 1.3),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _pwField(_newCtrl, 'Nueva contraseña', _o1,
                () => setState(() => _o1 = !_o1)),
            if (pass.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  width: 60, height: 4,
                  decoration: BoxDecoration(
                      color: _strengthColor(strength),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(strength, style: TextStyle(
                    color: _strengthColor(strength), fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 16),
            _pwField(_confirmCtrl, 'Confirmar contraseña', _o2,
                () => setState(() => _o2 = !_o2)),
            const SizedBox(height: 20),
            // Requisitos
            _req('Mínimo 8 caracteres', pass.length >= 8),
            _req('Una mayúscula',       pass.contains(RegExp(r'[A-Z]'))),
            _req('Un número',           pass.contains(RegExp(r'[0-9]'))),
            _req('Un carácter especial',pass.contains(RegExp(r'[!@#\$%^&*]'))),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (_newCtrl.text != _confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Las contraseñas no coinciden'),
                        backgroundColor: Color(0xFFE50914)));
                    return;
                  }
                  // Navegar a login tras cambiar
                  Navigator.pushAndRemoveUntil(context,
                      AppRoute.fade(const LoginScreen()), (r) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Restablecer contraseña',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _req(String text, bool met) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(met ? Icons.check_circle : Icons.circle_outlined,
          color: met ? Colors.green : const Color(0xFF666666), size: 16),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          color: met ? Colors.white : const Color(0xFF666666), fontSize: 13)),
    ]),
  );

  Widget _pwField(TextEditingController c, String label, bool ob, VoidCallback t) =>
      StatefulBuilder(builder: (_, set) => TextField(
        controller: c, obscureText: ob,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF999999)),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF999999)),
          suffixIcon: IconButton(
            icon: Icon(ob ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF999999)),
            onPressed: t,
          ),
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ));
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 8: SELECCIÓN DE PERFILES
// ══════════════════════════════════════════════════════════════

Widget _buildImageSelector(
    List<String> imgs, String selImage, void Function(String) onSelect) {
  return SizedBox(
    height: 80,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: imgs.length,
      itemBuilder: (_, i) {
        final img   = imgs[i];
        final isSel = selImage == img;
        return GestureDetector(
          onTap: () => onSelect(img),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                  width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(img, width: 60, height: 60, fit: BoxFit.cover),
            ),
          ),
        );
      },
    ),
  );
}

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});
  @override State<ProfileSelectScreen> createState() =>
      _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  List<UserProfile> _profiles = [];
  final List<String> _imgs = [
    'assets/images/profile1.jpg', 'assets/images/profile2.jpg',
    'assets/images/profile3.jpg', 'assets/images/profile4.jpg',
    'assets/images/profile5.jpg',
  ];
  bool _loading = true;

  @override void initState() { super.initState(); _loadProfiles(); }

  Future<void> _loadProfiles() async {
    final saved       = await StorageService.loadProfiles();
    final displayName = AuthService.currentUser?.displayName ?? 'Usuario';
    setState(() {
      if (saved.isNotEmpty) {
        _profiles = saved.map((p) => UserProfile(
          name:       p['name']       as String,
          image:      p['image']      as String,
          pin:        p['pin']        as String?,
          isOwner:    p['isOwner']    as bool? ?? false,
          isKidsMode: p['isKidsMode'] as bool? ?? false,
        )).toList();
      } else {
        _profiles = [UserProfile(
            name: displayName,
            image: 'assets/images/profile1.jpg',
            isOwner: true)];
        _persistProfiles();
      }
      _loading = false;
    });
  }

  Future<void> _persistProfiles() async => StorageService.saveProfiles(
    _profiles.map((p) => {
      'name': p.name, 'image': p.image, 'pin': p.pin,
      'isOwner': p.isOwner, 'isKidsMode': p.isKidsMode,
    }).toList(),
  );

  void _addProfile() {
    if (_profiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Máximo 5 perfiles'),
          backgroundColor: Color(0xFFE50914)));
      return;
    }
    Navigator.push(context, AppRoute.slideUp(CreateProfileScreen(
      availableImages: _imgs,
      onCreated: (profile) async {
        setState(() => _profiles.add(profile));
        await _persistProfiles();
      },
    )));
  }

  void _selectProfile(UserProfile p) {
    final profileData = ProfileData(
      id:         p.name,
      name:       p.name,
      image:      p.image,
      pin:        p.pin,
      isOwner:    p.isOwner,
      isKidsMode: p.isKidsMode,
    );

    if (p.pin != null) {
      _showPinDialog(p, profileData);
    } else {
      ProfileManager.setActiveProfile(profileData).then((_) {
        if (profileData.isKidsMode) {
          Navigator.pushReplacement(
              context, AppRoute.fade(KidsModeScreen(allContent: const [])));
        } else {
          Navigator.pushReplacement(
              context, AppRoute.fade(const HomeScreen()));
        }
      });
    }
  }

  void _showPinDialog(UserProfile p, ProfileData profileData) {
    final pinCtrl = TextEditingController();
    bool obscure = true, error = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.asset(p.image, width: 36, height: 36, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ingresa el PIN para acceder.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: pinCtrl, obscureText: obscure,
            keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(color: Color(0xFF999999), letterSpacing: 8),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF999999)),
                onPressed: () => set(() => obscure = !obscure),
              ),
              filled: true, fillColor: const Color(0xFF222222),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error ? const Color(0xFFE50914) : const Color(0xFF3A3A3A),
                    width: 1.5),
              ),
            ),
            onChanged: (_) => set(() => error = false),
          ),
          if (error) ...[
            const SizedBox(height: 8),
            const Text('PIN incorrecto',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 12)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              if (hashPin(pinCtrl.text) == p.pin) {
                Navigator.pop(ctx);
                ProfileManager.setActiveProfile(profileData).then((_) {
                  if (profileData.isKidsMode) {
                    Navigator.pushReplacement(context,
                        AppRoute.fade(KidsModeScreen(allContent: const [])));
                  } else {
                    Navigator.pushReplacement(
                        context, AppRoute.fade(const HomeScreen()));
                  }
                });
              } else {
                set(() => error = true);
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      )),
    );
  }

 @override
Widget build(BuildContext context) {
  if (_loading) return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))));
  return Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('FLIXBOY', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
              color: Color(0xFFE50914), letterSpacing: 4)),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              AppRoute.slideUp(ManageProfilesScreen(
                  profiles: _profiles, availableImages: _imgs)),
            ).then((_) async { await _persistProfiles(); setState(() {}); }),
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF999999), size: 18),
            label: const Text('Editar',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          ),
        ]),
      ),
      // ... resto del build de ProfileSelectScreen
        const SizedBox(height: 32),
        const Text('¿Quién está viendo?', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 40),
        Expanded(child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 24,
              crossAxisSpacing: 24, childAspectRatio: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          itemCount: _profiles.length + (_profiles.length < 5 ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _profiles.length) return GestureDetector(
              onTap: _addProfile,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 90, height: 90,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A3A3A), width: 2)),
                  child: const Icon(Icons.add, size: 40, color: Color(0xFF999999))),
                const SizedBox(height: 12),
                const Text('Agregar perfil',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
              ]),
            );
            final p = _profiles[index];
            return TapScale(
              onTap: () => _selectProfile(p),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.asset(p.image, width: 90, height: 90, fit: BoxFit.cover)),
                  if (p.pin != null) Positioned(bottom: 4, right: 4,
                    child: Container(width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE50914), shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.white, size: 14))),
                  if (p.isOwner) Positioned(top: 4, right: 4,
                    child: Container(width: 24, height: 24,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE50914), shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A0A0A), width: 2)),
                      child: const Icon(Icons.star, color: Colors.white, size: 12))),
                  if (p.isKidsMode) Positioned(top: 4, left: 4,
                    child: Container(width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFF8B0000), shape: BoxShape.circle),
                      child: const Icon(Icons.child_care, color: Colors.white, size: 13))),
                ]),
                const SizedBox(height: 12),
                Text(p.name, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                if (p.isKidsMode)
                  const Text('Kids', style: TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
              ]),
            );
          },
        )),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            await PushNotificationService.onLogout();
            await AuthService.logout();
            await SessionManager.clear();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            }
          },
          icon: const Icon(Icons.logout, color: Color(0xFF999999), size: 18),
          label: const Text('Cerrar sesión',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
        ),
        const SizedBox(height: 32),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 9: CREAR PERFIL
// ══════════════════════════════════════════════════════════════

class CreateProfileScreen extends StatefulWidget {
  final List<String> availableImages;
  final void Function(UserProfile) onCreated;
  const CreateProfileScreen({
    super.key,
    required this.availableImages,
    required this.onCreated,
  });
  @override State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _selImage = '';
  bool _isKidsMode = false, _hasPin = false;
  final _pinCtrl  = TextEditingController();
  final _pin2Ctrl = TextEditingController();
  bool _op = true, _op2 = true;

  @override
  void initState() {
    super.initState();
    _selImage = widget.availableImages.isNotEmpty ? widget.availableImages[0] : '';
  }

  @override void dispose() {
    _nameCtrl.dispose(); _pinCtrl.dispose(); _pin2Ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresa un nombre'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    if (_hasPin && _pinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN mínimo 4 dígitos'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    if (_hasPin && _pinCtrl.text != _pin2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs no coinciden'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    widget.onCreated(UserProfile(
      name:       _nameCtrl.text.trim(),
      image:      _selImage,
      pin:        _hasPin ? hashPin(_pinCtrl.text) : null,
      isKidsMode: _isKidsMode,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Crear perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Avatar seleccionable
        GestureDetector(
          onTap: () => _showImagePicker(),
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE50914), width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selImage.isNotEmpty
                    ? Image.asset(_selImage, fit: BoxFit.cover)
                    : Container(color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.person, size: 50, color: Color(0xFF444444))),
              ),
            ),
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFFE50914), shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 14),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Toca para cambiar', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
        const SizedBox(height: 24),
        // Nombre
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nombre del perfil',
            labelStyle: const TextStyle(color: Color(0xFF999999)),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF999999)),
            filled: true, fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        // Modo niños
        _switchTile(
          icon: Icons.child_care_rounded,
          title: 'Perfil infantil',
          subtitle: 'Solo mostrará contenido apto para niños.',
          value: _isKidsMode,
          onChanged: (v) => setState(() => _isKidsMode = v),
        ),
        const SizedBox(height: 12),
        // PIN
        _switchTile(
          icon: Icons.lock_outline,
          title: 'Proteger con PIN',
          subtitle: 'Solicita PIN al acceder a este perfil.',
          value: _hasPin,
          onChanged: (v) => setState(() { _hasPin = v; if (!v) { _pinCtrl.clear(); _pin2Ctrl.clear(); } }),
        ),
        if (_hasPin) ...[
          const SizedBox(height: 16),
          _pwField(_pinCtrl, 'PIN (4-6 dígitos)', _op,
              () => setState(() => _op = !_op)),
          const SizedBox(height: 12),
          _pwField(_pin2Ctrl, 'Confirmar PIN', _op2,
              () => setState(() => _op2 = !_op2)),
        ],
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ),
  );

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Elige un avatar',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: widget.availableImages.length,
            itemBuilder: (_, i) {
              final img   = widget.availableImages[i];
              final isSel = _selImage == img;
              return GestureDetector(
                onTap: () {
                  setState(() => _selImage = img);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                        width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(img, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ]),
      )),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: value ? const Color(0xFFE50914) : const Color(0xFF999999)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: value ? Colors.white : const Color(0xFF999999))),
            Text(subtitle, style: const TextStyle(
                color: Color(0xFF666666), fontSize: 11)),
          ])),
          Switch(value: value, onChanged: onChanged,
              activeColor: const Color(0xFFE50914)),
        ]),
      );

  Widget _pwField(TextEditingController c, String label, bool ob, VoidCallback t) =>
      TextField(
        controller: c, obscureText: ob,
        keyboardType: TextInputType.number, maxLength: 6,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF999999)),
          prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
          suffixIcon: IconButton(
            icon: Icon(ob ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF999999)),
            onPressed: t,
          ),
          filled: true, fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 10: EDITAR PERFIL (parte de ManageProfilesScreen)
// ══════════════════════════════════════════════════════════════

class ManageProfilesScreen extends StatefulWidget {
  final List<UserProfile> profiles;
  final List<String>      availableImages;
  const ManageProfilesScreen({
    super.key,
    required this.profiles,
    required this.availableImages,
  });
  @override State<ManageProfilesScreen> createState() =>
      _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  late List<UserProfile> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = widget.profiles.map((p) => UserProfile(
      name:       p.name,
      image:      p.image,
      pin:        p.pin,
      isOwner:    p.isOwner,
      isKidsMode: p.isKidsMode,
    )).toList();
  }

  @override
  void dispose() {
    widget.profiles
      ..clear()
      ..addAll(_profiles);
    super.dispose();
  }

  void _editProfile(int index) {
    final p           = _profiles[index];
    final nameCtrl    = TextEditingController(text: p.name);
    final pinCtrl     = TextEditingController();
    final pin2Ctrl    = TextEditingController();
    String selImage   = p.image;
    bool hasPin       = p.pin != null;
    bool isKidsMode   = p.isKidsMode;
    bool op = true, op2 = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: Text('Editar "${p.name}"',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSelector(widget.availableImages, selImage,
                  (img) => set(() => selImage = img)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: Color(0xFF999999)),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF999999)),
                  filled: true, fillColor: const Color(0xFF222222),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.lock_outline,
                      color: hasPin ? const Color(0xFFE50914) : const Color(0xFF999999),
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Proteger con PIN',
                      style: TextStyle(
                          color: hasPin ? Colors.white : const Color(0xFF999999)))),
                  Switch(
                      value: hasPin,
                      onChanged: (v) => set(() {
                        hasPin = v;
                        if (!v) { pinCtrl.clear(); pin2Ctrl.clear(); }
                      }),
                      activeColor: const Color(0xFFE50914)),
                ]),
              ),
              if (hasPin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl, obscureText: op,
                  keyboardType: TextInputType.number, maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: p.pin != null ? 'Nuevo PIN (vacío = mantener)' : 'PIN (4-6 dígitos)',
                    labelStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(op ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF999999)),
                      onPressed: () => set(() => op = !op),
                    ),
                    filled: true, fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pin2Ctrl, obscureText: op2,
                  keyboardType: TextInputType.number, maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Confirmar PIN',
                    labelStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(op2 ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF999999)),
                      onPressed: () => set(() => op2 = !op2),
                    ),
                    filled: true, fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.child_care_rounded,
                      color: isKidsMode ? const Color(0xFFE50914) : const Color(0xFF999999),
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Modo niños',
                        style: TextStyle(
                            color: isKidsMode ? Colors.white : const Color(0xFF999999))),
                    if (isKidsMode) const Text('Solo muestra contenido infantil',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 11)),
                  ])),
                  Switch(
                      value: isKidsMode,
                      onChanged: (v) => set(() => isKidsMode = v),
                      activeColor: const Color(0xFFE50914)),
                ]),
              ),
            ],
          )),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              String? newPin = p.pin;
              if (hasPin && pinCtrl.text.isNotEmpty) {
                if (pinCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PIN mínimo 4 dígitos'),
                      backgroundColor: Color(0xFFE50914)));
                  return;
                }
                if (pinCtrl.text != pin2Ctrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PINs no coinciden'),
                      backgroundColor: Color(0xFFE50914)));
                  return;
                }
                newPin = hashPin(pinCtrl.text);
              } else if (!hasPin) {
                newPin = null;
              }
              setState(() {
                _profiles[index].name       = nameCtrl.text.trim();
                _profiles[index].image      = selImage;
                _profiles[index].pin        = newPin;
                _profiles[index].isKidsMode = isKidsMode;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      )),
    );
  }

  void _deleteProfile(int index) {
    if (_profiles[index].isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No puedes eliminar el perfil principal'),
          backgroundColor: Color(0xFFE50914)));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: const Text('Eliminar perfil', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar "${_profiles[index].name}"?',
            style: const TextStyle(color: Color(0xFF999999))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _profiles.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Eliminar perfil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A), elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Administrar perfiles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF1E0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3))),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.star, color: Color(0xFFE50914), size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Text(
              'Solo el creador puede administrar perfiles.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 12, height: 1.5))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _profiles.length,
        itemBuilder: (_, index) {
          final p = _profiles[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.asset(p.image, width: 52, height: 52, fit: BoxFit.cover)),
                if (p.pin != null) Positioned(bottom: 2, right: 2,
                  child: Container(width: 18, height: 18,
                    decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: Colors.white, size: 10))),
                if (p.isOwner) Positioned(top: 2, right: 2,
                  child: Container(width: 18, height: 18,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5)),
                    child: const Icon(Icons.star, color: Colors.white, size: 9))),
                if (p.isKidsMode) Positioned(top: 2, left: 2,
                  child: Container(width: 18, height: 18,
                    decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle),
                    child: const Icon(Icons.child_care, color: Colors.white, size: 10))),
              ]),
              title: Row(children: [
                Text(p.name, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
                if (p.isOwner) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Creador',
                        style: TextStyle(color: Color(0xFFE50914), fontSize: 10,
                            fontWeight: FontWeight.bold))),
                ],
                if (p.isKidsMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B0000).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Kids',
                        style: TextStyle(color: Color(0xFFCC0000), fontSize: 10,
                            fontWeight: FontWeight.bold))),
                ],
              ]),
              subtitle: Text(
                  p.pin != null ? 'Con PIN' : 'Sin PIN',
                  style: TextStyle(
                      color: p.pin != null
                          ? const Color(0xFFE50914).withValues(alpha: 0.8)
                          : const Color(0xFF999999),
                      fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    onPressed: () => _editProfile(index)),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: p.isOwner
                          ? const Color(0xFF999999).withValues(alpha: 0.3)
                          : const Color(0xFFE50914)),
                  onPressed: p.isOwner ? null : () => _deleteProfile(index),
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
      // REEMPLAZA POR:
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
      .replaceAll('ó','o').replaceAll('é','e')
      .replaceAll('á','a').replaceAll('í','i').replaceAll('ú','u');
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

      if (mounted) {
  setState(() {
    _allContent     = filtered;
    _trending       = trendingFiltered;
    // REEMPLAZA POR:
    // REEMPLAZA POR:
_upcoming = upcoming.isNotEmpty
    ? upcoming
    : all.where((c) => c.isUpcoming).toList();

// Asegurarse que _upcoming nunca esté vacío si hay contenido con ese género
if (_upcoming.isEmpty) {
  _upcoming = all.where((c) {
    final g = c.genre.toLowerCase()
        .replaceAll('ó','o').replaceAll('é','e')
        .replaceAll('á','a').replaceAll('í','i').replaceAll('ú','u');
    return g.contains('proximo') || g.contains('upcoming');
  }).toList();
}
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

  // REEMPLAZA POR:
List<String> get _allGenres {
  final g = <String>{};
  for (final c in _allContent) {
    if (c.genre != 'Proximo estreno' && !c.isUpcoming) g.add(c.genre);
  }
  return g.toList()..sort();
}

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF080808),
    extendBodyBehindAppBar: true,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _bannerOpacity < 0.5
              ? const Color(0xFF080808)
              : Colors.transparent,
        ),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Hamburguesa
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
            // Logo
            const Text('FLIXBOY', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: Color(0xFFE50914), letterSpacing: 3)),
            const Spacer(), // ← AGREGA ESTA LÍNEA
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
      ),
    ),
      body: Stack(children: [
        CustomScrollView(controller: _scrollCtrl, slivers: [
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
        ]),
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
    );  // cierre del Scaffold
  }     // cierre del build

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
            await SessionManager.clear();
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

// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
//  PANTALLA 19: EPISODIOS DE SERIE
// ══════════════════════════════════════════════════════════════

class EpisodesScreen extends StatefulWidget {
  final ContentModel series;
  const EpisodesScreen({super.key, required this.series});
  @override State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  int _selectedSeason = 1;
  final int _totalSeasons = 4;

  final _episodes = [
    {'number': 1, 'title': 'Capítulo uno: La desaparición...',   'duration': '52m'},
    {'number': 2, 'title': 'Capítulo dos: El aro de Maple...',   'duration': '1h 0m'},
    {'number': 3, 'title': 'Capítulo tres: El monstruo y el...', 'duration': '1h 0m'},
    {'number': 4, 'title': 'Capítulo cuatro: Querido Billy',     'duration': '1h 18m'},
    {'number': 5, 'title': 'Capítulo cinco: La nina',            'duration': '55m'},
    {'number': 6, 'title': 'Capítulo seis: El buceo',            'duration': '1h 2m'},
    {'number': 7, 'title': 'Capítulo siete: El laboratorio',     'duration': '1h 7m'},
    {'number': 8, 'title': 'Capítulo ocho: El paisaje caído',    'duration': '1h 16m'},
    {'number': 9, 'title': 'Capítulo nueve: El bautismo del fuego','duration': '1h 25m'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: Text(widget.series.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {}),
      ],
    ),
    body: Column(children: [
      // Info de temporada
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF141414),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<int>(
              value: _selectedSeason,
              dropdownColor: const Color(0xFF1A1A1A),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _selectedSeason = v!),
              items: List.generate(_totalSeasons, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text('Temporada ${i + 1}'),
              )),
            ),
          ),
          const Spacer(),
          Text('${_episodes.length} episodios',
              style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _episodes.length,
        itemBuilder: (_, i) {
          final ep = _episodes[i];
          return GestureDetector(
            onTap: () {
              HistoryManager.add(widget.series,
                  episode: 'T$_selectedSeason E${ep['number']} - ${ep['title']}');
              Navigator.push(context, AppRoute.playerFade(
                  VideoPlayerScreen(videoUrl: widget.series.videoUrl,
                      title: ep['title'] as String, content: widget.series)));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A), shape: BoxShape.circle),
                  child: Center(child: Text('${ep['number']}',
                      style: const TextStyle(
                          color: Color(0xFF999999), fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ep['title'] as String, style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(ep['duration'] as String,
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
                ])),
                const Icon(Icons.play_circle_outline,
                    color: Color(0xFFE50914), size: 28),
              ]),
            ),
          );
        },
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 22: MI LISTA (FAVORITOS/WATCHLIST)
// ══════════════════════════════════════════════════════════════

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: WatchlistBuilder(builder: (_, wl) =>
          Text('Mi Lista (${wl.length})', style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold))),
    ),
    body: WatchlistBuilder(
      builder: (context, wl) {
        if (wl.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bookmark_outline, size: 80,
                color: const Color(0xFF999999).withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Tu lista está vacía', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Agrega películas y series para verlas después',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                textAlign: TextAlign.center),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: wl.length,
          itemBuilder: (ctx, i) {
            final item  = wl[i];
            final model = ContentModel(
              id:          item['id']          ?? '',
              title:       item['title']        ?? '',
              genre:       item['genre']        ?? '',
              year:        item['year']         ?? '',
              duration:    item['duration']     ?? '',
              type:        item['type']         ?? '',
              description: item['description']  ?? '',
              videoUrl:    item['videoUrl']     ?? '',
              imagenUrl:   item['imagenUrl']    ?? '',
              trailerUrl:  item['trailerUrl']   ?? '',
            );
            return GestureDetector(
              onTap: () => Navigator.push(ctx,
                  AppRoute.scaleDetail(DetailScreen(content: model))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12)),
                    child: (item['imagenUrl'] ?? '').isNotEmpty
                        ? FlixImage(
                            url: cloudinaryOptimized(item['imagenUrl']!, w: 90, h: 90),
                            width: 90, height: 90)
                        : Container(width: 90, height: 90,
                            color: genreColor(item['genre'] ?? ''),
                            child: const Icon(Icons.movie, color: Colors.white38)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['title'] ?? '', style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: genreColor(item['genre'] ?? ''),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(item['genre'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 6),
                        Text(item['type'] ?? '',
                            style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${item['year']} - ${item['duration']}',
                          style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
                    ]),
                  )),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill,
                        color: Color(0xFFE50914), size: 28),
                    onPressed: () => Navigator.push(ctx, AppRoute.playerFade(
                        VideoPlayerScreen(videoUrl: model.videoUrl,
                            title: model.title, content: model))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFE50914)),
                    onPressed: () => WatchlistManager.toggle(item),
                  ),
                ]),
              ),
            );
          },
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 23: HISTORIAL
// ══════════════════════════════════════════════════════════════

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Historial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        TextButton(
          onPressed: () {
            HistoryManager.clear();
            setState(() {});
          },
          child: const Text('Limpiar historial',
              style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
        ),
      ],
    ),
    body: HistoryManager.all.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history, size: 80,
                color: const Color(0xFF999999).withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Sin historial', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: HistoryManager.all.length,
            itemBuilder: (context, i) {
              final item    = HistoryManager.all[i];
              final content = item['content'] as ContentModel?;
              return Dismissible(
                key: Key(item['title'] as String),
                direction: DismissDirection.endToStart,
                background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: const Color(0xFFE50914),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 28)),
                onDismissed: (_) {
                  HistoryManager.remove(item['title'] as String);
                  setState(() {});
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: content != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FlixImage(
                              url: cloudinaryOptimized(content.imagenUrl, w: 56, h: 56),
                              width: 56, height: 56))
                        : const Icon(Icons.movie, color: Color(0xFF999999)),
                    title: Text(item['title'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((item['episode'] as String).isNotEmpty)
                        Text(item['episode'] as String,
                            style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                      Text(_ago(item['watchedAt'] as DateTime),
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
                    ]),
                    trailing: content != null
                        ? IconButton(
                            icon: const Icon(Icons.play_circle_outline,
                                color: Color(0xFFE50914)),
                            onPressed: () => Navigator.push(context, AppRoute.playerFade(
                                VideoPlayerScreen(videoUrl: content.videoUrl,
                                    title: content.title, content: content))))
                        : null,
                  ),
                ),
              );
            },
          ),
  );

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours   < 24) return 'Hace ${d.inHours} h';
    if (d.inDays    == 1) return 'Ayer';
    return 'Hace ${d.inDays} días';
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 24: NOTIFICACIONES
// ══════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notifs = NotificationsManager.all;
    final unread = NotificationsManager.unreadCount;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A), elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notificaciones', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          if (unread > 0) Text('$unread sin leer',
              style: const TextStyle(color: Color(0xFFE50914), fontSize: 12)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF999999)),
            onPressed: () => Navigator.push(context,
                AppRoute.slideRight(const NotificationPreferencesScreen())),
          ),
          if (unread > 0) TextButton(
            onPressed: () { NotificationsManager.markAllAsRead(); setState(() {}); },
            child: const Text('Marcar todo',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
          ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none, size: 80,
                  color: const Color(0xFF999999).withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Sin notificaciones', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifs.length,
              itemBuilder: (_, i) => _item(notifs[i]),
            ),
    );
  }

  Widget _item(AppNotification n) => Dismissible(
    key: Key(n.id),
    direction: DismissDirection.endToStart,
    background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFE50914),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28)),
    onDismissed: (_) {
      NotificationsManager.delete(n.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Eliminada'),
          backgroundColor: Color(0xFF1A1A1A),
          duration: Duration(seconds: 2)));
    },
    child: GestureDetector(
      onTap: () { NotificationsManager.markAsRead(n.id); setState(() {}); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: n.isRead ? const Color(0xFF141414) : const Color(0xFF1E0505),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: n.isRead ? Colors.transparent : const Color(0xFFE50914).withValues(alpha: 0.3),
              width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _iconBg(n.type), borderRadius: BorderRadius.circular(10)),
              child: Icon(_iconData(n.type), color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.title, style: TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold))),
                if (!n.isRead) Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE50914), shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(n.body, style: const TextStyle(
                  color: Color(0xFF999999), fontSize: 12, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(_ago(n.time), style: const TextStyle(
                  color: Color(0xFF666666), fontSize: 11)),
            ])),
          ]),
        ),
      ),
    ),
  );

  IconData _iconData(NotifType t) {
    switch (t) {
      case NotifType.login:        return Icons.login;
      case NotifType.device:       return Icons.phone_android;
      case NotifType.password:     return Icons.lock_reset;
      case NotifType.subscription: return Icons.card_membership;
      case NotifType.security:     return Icons.shield_outlined;
      case NotifType.newContent:   return Icons.play_circle_outline;
      case NotifType.upcoming:     return Icons.upcoming_outlined;
      case NotifType.reminder:     return Icons.watch_later_outlined;
    }
  }

  Color _iconBg(NotifType t) {
    switch (t) {
      case NotifType.login:        return const Color(0xFF8B0000);
      case NotifType.device:       return const Color(0xFF8B0000);
      case NotifType.password:     return const Color(0xFFE50914);
      case NotifType.subscription: return const Color(0xFF8B0000);
      case NotifType.security:     return const Color(0xFFE50914);
      case NotifType.newContent:   return const Color(0xFFE50914);
      case NotifType.upcoming:     return const Color(0xFF5C0000);
      case NotifType.reminder:     return const Color(0xFF3A0000);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours   < 24) return 'Hace ${d.inHours} h';
    if (d.inDays    == 1) return 'Ayer';
    return 'Hace ${d.inDays} días';
  }
}

// Pantalla de preferencias de notificaciones
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _newEpisodes   = true;
  bool _premiers      = true;
  bool _reminders     = true;
  bool _promotions    = false;
  bool _security      = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Preferencias de notificaciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _section('Contenido', [
        _toggle('Nuevos episodios', 'Cuando salga un episodio de lo que sigues',
            _newEpisodes, (v) => setState(() => _newEpisodes = v)),
        _toggle('Estrenos', 'Nuevas películas y series disponibles',
            _premiers, (v) => setState(() => _premiers = v)),
        _toggle('Recordatorios', 'Para retomar lo que dejaste a medias',
            _reminders, (v) => setState(() => _reminders = v)),
        _toggle('Promociones', 'Ofertas y descuentos especiales',
            _promotions, (v) => setState(() => _promotions = v)),
      ]),
      const SizedBox(height: 16),
      _section('Seguridad', [
        _toggle('Alertas de seguridad', 'Accesos y cambios en tu cuenta',
            _security, (v) => setState(() => _security = v)),
      ]),
    ]),
  );

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title, style: const TextStyle(
            color: Color(0xFF999999), fontSize: 12,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      ),
    ],
  );

  Widget _toggle(String title, String subtitle, bool value,
      void Function(bool) onChanged) =>
      SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFE50914),
      );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 25: PERFIL DE USUARIO
// ══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Usuario', _email = '', _plan = 'free';

  @override void initState() { super.initState(); _loadUser(); }

  Future<void> _loadUser() async {
    final user = AuthService.currentUser;
    final plan = await SubscriptionService.getUserPlan();
    if (mounted) setState(() {
      _name  = user?.displayName ?? 'Usuario';
      _email = user?.email ?? '';
      _plan  = plan;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: SafeArea(child: SingleChildScrollView(child: Column(children: [
      // Header perfil
      Container(width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)])),
        child: Column(children: [
          const SizedBox(height: 16),
          Stack(alignment: Alignment.bottomRight, children: [
            ClipRRect(borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                ProfileManager.activeProfile?.image ?? 'assets/images/profile1.jpg',
                width: 100, height: 100, fit: BoxFit.cover)),
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                  color: Color(0xFFE50914), shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 16)),
          ]),
          const SizedBox(height: 16),
          Text(_name, style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(_email, style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _plan == 'premium'
                  ? const Color(0xFFE50914).withValues(alpha: 0.2)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _plan == 'premium'
                  ? const Color(0xFFE50914) : const Color(0xFF3A3A3A)),
            ),
            child: Text(
                _plan == 'premium' ? 'Plan Premium' : 'Plan Gratuito',
                style: TextStyle(
                  color: _plan == 'premium'
                      ? const Color(0xFFE50914) : const Color(0xFF999999),
                  fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ])),
      // Stats
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          WatchlistBuilder(builder: (_, wl) =>
              _stat(wl.length.toString(), 'Mi lista')),
          _stat('${HistoryManager.all.length}', 'Vistos'),
          _stat(_plan == 'premium' ? 'PRO' : 'FREE', 'Plan'),
        ])),
      const Divider(color: Color(0xFF1E1E1E)),
      _section('Mi cuenta', [
        _opt(Icons.person_outline, 'Información de la cuenta', () {}),
        _opt(Icons.lock_outline, 'Cambiar contraseña',
            () => Navigator.push(context, AppRoute.slideRight(const ResetPasswordScreen()))),
        _opt(Icons.family_restroom, 'Control parental',
            () => Navigator.push(context, AppRoute.slideRight(const ParentalControlScreen()))),
        _opt(Icons.language_outlined, 'Idioma', () {}),
      ]),
      _section('Actividad', [
        _opt(Icons.bookmark_outline, 'Mi Lista',
            () => Navigator.push(context, AppRoute.slideUp(const WatchlistScreen()))),
        _opt(Icons.history, 'Historial',
            () => Navigator.push(context, AppRoute.slideRight(const HistoryScreen()))),
        _opt(Icons.notifications_outlined, 'Notificaciones',
            () => Navigator.push(context, AppRoute.slideUp(const NotificationsScreen()))),
      ]),
      _section('Cuenta', [
        _opt(Icons.star_outline, 'Suscripción', _showSubscriptionDialog),
        _opt(Icons.settings_outlined, 'Configuración',
            () => Navigator.push(context, AppRoute.slideRight(const SettingsScreen()))),
        _opt(Icons.help_outline, 'Ayuda y soporte', () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Ayuda', style: TextStyle(color: Colors.white)),
            content: const Text('Para soporte, escríbenos a soporte@flixboy.com',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
            actions: [TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar',
                    style: TextStyle(color: Color(0xFFE50914))))],
          ),
        )),
        _opt(Icons.info_outline, 'Acerca de Flixboy', () {}),
      ]),
      const Divider(color: Color(0xFF1E1E1E)),
      ListTile(
        leading: const Icon(Icons.logout, color: Color(0xFFE50914)),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Color(0xFFE50914))),
        onTap: () async {
          await PushNotificationService.onLogout();
          await AuthService.logout();
          await SessionManager.clear();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false);
          }
        },
      ),
      const SizedBox(height: 32),
    ]))),
  );

  void _showSubscriptionDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2A))),
      title: const Text('Suscripción', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3))),
          child: const Column(children: [
            Text('Plan Premium', style: TextStyle(
                color: Color(0xFFE50914), fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Acceso a todo el contenido\n• Sin anuncios\n• Calidad HD\n• 1 mes de duración',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13, height: 1.6)),
          ])),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF999999)))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
          onPressed: () async {
            await SubscriptionService.activatePremium();
            Navigator.pop(context);
            _loadUser();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('¡Plan Premium activado!'),
                backgroundColor: Color(0xFFE50914)));
          },
          child: const Text('Activar Premium'),
        ),
      ],
    ));
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: const TextStyle(
            color: Color(0xFF666666), fontSize: 12,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      ...children,
      const Divider(color: Color(0xFF1E1E1E)),
    ],
  );

  Widget _stat(String v, String l) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(
        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
    Text(l, style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
  ]));

  Widget _opt(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: Colors.white70),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    trailing: const Icon(Icons.chevron_right, color: Color(0xFF999999)),
    onTap: onTap,
  );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 26: CONFIGURACIÓN
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlay     = SettingsManager.autoPlay;
  String _quality    = SettingsManager.videoQuality;
  String _audio      = SettingsManager.audioLanguage;
  String _subtitles  = SettingsManager.subtitleLanguage;
  bool _notifications = SettingsManager.notifications;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Configuración',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('Reproducción'),
      _settingTile(
        icon: Icons.play_arrow_outlined,
        title: 'Reproducción automática',
        trailing: Switch(
          value: _autoPlay,
          onChanged: (v) => setState(() {
            _autoPlay = v;
            SettingsManager.autoPlay = v;
          }),
          activeColor: const Color(0xFFE50914),
        ),
      ),
      _settingTile(
        icon: Icons.hd_outlined,
        title: 'Calidad de video',
        trailing: _dropdown(
          SettingsManager.qualities, _quality,
          (v) => setState(() { _quality = v!; SettingsManager.videoQuality = v; }),
        ),
      ),
      const SizedBox(height: 16),
      _sectionTitle('Audio y subtítulos'),
      _settingTile(
        icon: Icons.volume_up_outlined,
        title: 'Idioma de audio',
        trailing: _dropdown(
          SettingsManager.languages, _audio,
          (v) => setState(() { _audio = v!; SettingsManager.audioLanguage = v; }),
        ),
      ),
      _settingTile(
        icon: Icons.subtitles_outlined,
        title: 'Subtítulos',
        trailing: _dropdown(
          SettingsManager.languages, _subtitles,
          (v) => setState(() { _subtitles = v!; SettingsManager.subtitleLanguage = v; }),
        ),
      ),
      const SizedBox(height: 16),
      _sectionTitle('Notificaciones'),
      _settingTile(
        icon: Icons.notifications_outlined,
        title: 'Notificaciones',
        trailing: Switch(
          value: _notifications,
          onChanged: (v) => setState(() {
            _notifications = v;
            SettingsManager.notifications = v;
          }),
          activeColor: const Color(0xFFE50914),
        ),
      ),
      const SizedBox(height: 16),
      _sectionTitle('Control parental'),
      _settingTile(
        icon: Icons.family_restroom,
        title: 'Control parental',
        onTap: () => Navigator.push(context,
            AppRoute.slideRight(const ParentalControlScreen())),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
      ),
      const SizedBox(height: 16),
      _sectionTitle('Acerca de'),
      _settingTile(
        icon: Icons.info_outline,
        title: 'Acerca de Flixboy',
        trailing: const Text('v1.0.0', style: TextStyle(color: Color(0xFF666666))),
      ),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton(
          onPressed: () {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Cambios guardados'),
                backgroundColor: Color(0xFFE50914)));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: const TextStyle(
        color: Color(0xFF666666), fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _settingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: Icon(icon, color: Colors.white70, size: 22),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          trailing: trailing,
          onTap: onTap,
        ),
      );

  Widget _dropdown(List<String> items, String value,
      void Function(String?) onChanged) =>
      DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1A1A1A),
        underline: const SizedBox(),
        style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
        onChanged: onChanged,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 27: CONTROL PARENTAL
// ══════════════════════════════════════════════════════════════

class ParentalControlScreen extends StatefulWidget {
  const ParentalControlScreen({super.key});
  @override State<ParentalControlScreen> createState() => _ParentalControlScreenState();
}

class _ParentalControlScreenState extends State<ParentalControlScreen> {
  final _pinCtrl  = TextEditingController();
  bool _pinSet    = false;
  bool _obscure   = true;
  String _minRating = 'Todos';

  @override void dispose() { _pinCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Control parental',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PIN
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PIN de control parental',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl, obscureText: _obscure,
              keyboardType: TextInputType.number, maxLength: 6,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • •',
                hintStyle: const TextStyle(color: Color(0xFF444444), letterSpacing: 8),
                filled: true, fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF666666)),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (_pinCtrl.text.length >= 4) {
                  SettingsManager.parentalPin = hashPin(_pinCtrl.text);
                  setState(() => _pinSet = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PIN guardado correctamente'),
                      backgroundColor: Color(0xFFE50914)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('El PIN debe tener al menos 4 dígitos'),
                      backgroundColor: Color(0xFFE50914)));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_pinSet ? 'Actualizar PIN' : 'Establecer PIN',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Clasificación mínima
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Clasificación mínima permitida',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Restringe el acceso a contenido para adultos en todos los perfiles.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12, height: 1.4)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: SettingsManager.ratings.map((r) {
                final isSelected = _minRating == r;
                return GestureDetector(
                  onTap: () => setState(() {
                    _minRating = r;
                    SettingsManager.minRating = r;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE50914)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : const Color(0xFF3A3A3A),
                      ),
                    ),
                    child: Text(r,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF999999),
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Configuración guardada'),
                  backgroundColor: Color(0xFFE50914)));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    )),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  PANTALLA 28: SIN CONEXIÓN A INTERNET
// ══════════════════════════════════════════════════════════════
 
class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});
  @override State<NoInternetScreen> createState() => _NoInternetScreenState();
}
 
class _NoInternetScreenState extends State<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  bool _checking = false;
 
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }
 
  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }
 
  Future<void> _retry() async {
    setState(() => _checking = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _checking = false);
    // Si recuperó conexión, volver atrás
    Navigator.pop(context);
  }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono animado
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE50914).withValues(alpha: 0.35),
                          width: 2),
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        size: 58, color: Color(0xFFE50914)),
                  ),
                ),
                const SizedBox(height: 36),
                const Text('Sin conexión a internet',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                const Text(
                  'Parece que no tienes conexión.\nVerifica tu conexión e inténtalo de nuevo.',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 15, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _retry,
                    icon: _checking
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                        _checking ? 'Verificando...' : 'Reintentar',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false),
                  child: const Text('Ir al inicio',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  PANTALLA 29: ERROR DEL SERVIDOR
// ══════════════════════════════════════════════════════════════
 
class ServerErrorScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  const ServerErrorScreen({super.key, this.onRetry});
  @override State<ServerErrorScreen> createState() => _ServerErrorScreenState();
}
 
class _ServerErrorScreenState extends State<ServerErrorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
 
  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _shakeAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    // Pequeña animación al entrar
    Future.delayed(const Duration(milliseconds: 300),
        () => _shakeCtrl.forward().then((_) => _shakeCtrl.reverse()));
  }
 
  @override void dispose() { _shakeCtrl.dispose(); super.dispose(); }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono con animación
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.cloud_off_rounded,
                        size: 58, color: Color(0xFFE50914)),
                  ),
                ),
                const SizedBox(height: 36),
                const Text('Algo salió mal',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                const Text(
                  'Estamos teniendo problemas para cargar el contenido. Inténtalo más tarde.',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 15, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Código de error
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF3A3A3A), width: 1),
                  ),
                  child: const Text('Error 500 — Internal Server Error',
                      style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                          fontFamily: 'monospace')),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onRetry != null) {
                        Navigator.pop(context);
                        widget.onRetry!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Intentar de nuevo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false),
                  child: const Text('Ir al inicio',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  PANTALLA 30: REGISTRO EXITOSO
// ══════════════════════════════════════════════════════════════
 
class RegisterSuccessScreen extends StatefulWidget {
  const RegisterSuccessScreen({super.key});
  @override State<RegisterSuccessScreen> createState() =>
      _RegisterSuccessScreenState();
}
 
class _RegisterSuccessScreenState extends State<RegisterSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _scaleFade;
  late Animation<double>   _slideUp;
 
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scaleFade = CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _slideUp = CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _animCtrl.forward();
  }
 
  @override void dispose() { _animCtrl.dispose(); super.dispose(); }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Check animado
                ScaleTransition(
                  scale: _scaleFade,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2A0A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 70, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 36),
                // Textos con slide-up
                FadeTransition(
                  opacity: _slideUp,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(_slideUp),
                    child: Column(children: [
                      const Text('¡Registro exitoso!',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      const Text(
                        'Tu cuenta ha sido creada correctamente.\nAhora puedes disfrutar de todo el contenido de Flixboy.',
                        style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 15,
                            height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Beneficios del registro
                      _benefit(Icons.movie_filter_rounded,
                          'Miles de películas y series'),
                      _benefit(
                          Icons.devices_rounded, 'Disponible en todos tus dispositivos'),
                      _benefit(Icons.hd_rounded, 'Calidad HD sin interrupciones'),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              AppRoute.fade(const ProfileSelectScreen()),
                              (r) => false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Comenzar a explorar',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
 
  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Colors.green, size: 18),
      const SizedBox(width: 10),
      Text(text,
          style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
    ]),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  PANTALLA 31: ACTUALIZACIÓN DISPONIBLE
// ══════════════════════════════════════════════════════════════
 
class UpdateAvailableScreen extends StatefulWidget {
  final String currentVersion;
  final String newVersion;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;
 
  const UpdateAvailableScreen({
    super.key,
    this.currentVersion = '1.0.0',
    this.newVersion     = '1.1.0',
    this.onUpdate,
    this.onLater,
  });
  @override State<UpdateAvailableScreen> createState() =>
      _UpdateAvailableScreenState();
}
 
class _UpdateAvailableScreenState extends State<UpdateAvailableScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _bounceAnim;
  bool _downloading = false;
  double _progress  = 0.0;
 
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }
 
  @override void dispose() { _animCtrl.dispose(); super.dispose(); }
 
  Future<void> _startDownload() async {
    setState(() => _downloading = true);
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _progress = i / 10);
    }
    if (widget.onUpdate != null) widget.onUpdate!();
  }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono con bounce
                AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(0, _bounceAnim.value), child: child),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        size: 58, color: Color(0xFFE50914)),
                  ),
                ),
                const SizedBox(height: 36),
                const Text('Nueva actualización disponible',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                const Text(
                  'Tenemos una nueva versión de Flixboy con mejoras y correcciones.',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 15, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Versiones
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(children: [
                    _versionRow('Versión actual',
                        widget.currentVersion, const Color(0xFF666666)),
                    const Divider(color: Color(0xFF2A2A2A), height: 20),
                    _versionRow('Nueva versión',
                        widget.newVersion, const Color(0xFFE50914)),
                  ]),
                ),
                const SizedBox(height: 16),
                // Novedades
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('¿Qué hay de nuevo?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 10),
                      _change('Mejora en la velocidad de carga'),
                      _change('Corrección de errores en el reproductor'),
                      _change('Nueva sección de Próximamente'),
                      _change('Mejoras de estabilidad general'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Barra de progreso de descarga
                if (_downloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE50914)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Descargando... ${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                          color: Color(0xFF999999), fontSize: 13)),
                  const SizedBox(height: 24),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Actualizar ahora',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () {
                      if (widget.onLater != null) {
                        widget.onLater!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Más tarde',
                        style: TextStyle(
                            color: Color(0xFF999999), fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
 
  Widget _versionRow(String label, String version, Color versionColor) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: versionColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('v$version',
              style: TextStyle(
                  color: versionColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ),
      ]);
 
  Widget _change(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      const Icon(Icons.check_circle_outline,
          color: Color(0xFFE50914), size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFBBBBBB), fontSize: 12))),
    ]),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  PANTALLA 32: CARGANDO CONTENIDO (Splash / Loading State)
// ══════════════════════════════════════════════════════════════
 
class LoadingScreen extends StatefulWidget {
  final String? message;
  const LoadingScreen({super.key, this.message});
  @override State<LoadingScreen> createState() => _LoadingScreenState();
}
 
class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _rotateAnim;
 
  final List<String> _tips = [
    'Cargando tu contenido favorito...',
    'Preparando las mejores películas...',
    'Buscando series para ti...',
    'Casi listo...',
  ];
  int _tipIndex = 0;
 
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(begin: 0, end: 1.0).animate(_animCtrl);
 
    // Rotar los tips cada 2 segundos
    _rotateTips();
  }
 
  void _rotateTips() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    }
  }
 
  @override void dispose() { _animCtrl.dispose(); super.dispose(); }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('FLIXBOY',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 8)),
            const SizedBox(height: 48),
            // Spinner personalizado
            AnimatedBuilder(
              animation: _rotateAnim,
              builder: (_, child) => Transform.rotate(
                angle: _rotateAnim.value * 2 * 3.14159,
                child: child,
              ),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [Color(0xFFE50914), Colors.transparent],
                    stops: [0.0, 1.0],
                  ),
                  border: Border.all(
                      color: Colors.transparent, width: 0),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Color(0xFF0A0A0A), shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Mensaje animado
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                widget.message ?? _tips[_tipIndex],
                key: ValueKey(_tipIndex),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 14,
                    letterSpacing: 0.3),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            // Barra de carga inferior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: LinearProgressIndicator(
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFE50914)),
                    minHeight: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
 
// ══════════════════════════════════════════════════════════════
//  HELPERS ADICIONALES REFERENCIADOS EN LAS PANTALLAS
// ══════════════════════════════════════════════════════════════
 
/// TapScale — efecto de escala al presionar (usado en ProfileSelectScreen)
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const TapScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.92,
  });
  @override State<TapScale> createState() => _TapScaleState();
}
 
class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
 
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
 
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
 
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _ctrl.forward(),
    onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: ()  => _ctrl.reverse(),
    child: ScaleTransition(scale: _scaleAnim, child: widget.child),
  );
}
 
/// StaggerList — lista con animación escalonada (usado en SearchScreen)
class StaggerList extends StatefulWidget {
  final List<Widget> children;
  const StaggerList({super.key, required this.children});
  @override State<StaggerList> createState() => _StaggerListState();
}
 
class _StaggerListState extends State<StaggerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
 
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }
 
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
 
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: widget.children.length,
    itemBuilder: (_, i) {
      final start = (i * 0.08).clamp(0.0, 0.8);
      final end   = (start + 0.3).clamp(0.0, 1.0);
      final anim  = CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOut));
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.15), end: Offset.zero)
              .animate(anim),
          child: widget.children[i],
        ),
      );
    },
  );
}
 