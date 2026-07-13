import 'storage_service.dart';
import 'firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'security_service.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'auth_screens.dart';
import 'profile_screens.dart';
import 'status_screens.dart';

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

class LocalSessionManager {
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
  final savedUid = await LocalSessionManager.getSavedUid();
  final firebaseUser = await FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  if (!mounted) return;
  if (firebaseUser != null) await LocalSessionManager.save(firebaseUser);
  if (firebaseUser == null && savedUid != null) await LocalSessionManager.clear();
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
