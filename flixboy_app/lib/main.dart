import 'storage_service.dart';
import 'firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════
//  HELPERS GLOBALES
// ══════════════════════════════════════════════════════════════

Color genreColor(String genre) {
  switch (genre) {
    case 'Acción':          return const Color(0xFFE50914);
    case 'Drama':           return const Color(0xFF1565C0);
    case 'Comedia':         return const Color(0xFFF57C00);
    case 'Terror':          return const Color(0xFF4A148C);
    case 'Aventura':        return const Color(0xFF2E7D32);
    case 'Sci-Fi':          return const Color(0xFF00838F);
    case 'Fantasía':        return const Color(0xFF6A1B9A);
    case 'Animación':       return const Color(0xFF00897B);
    case 'Proximo estreno': return const Color(0xFF37474F);
    default:                return const Color(0xFF424242);
  }
}

String cloudinaryOptimized(String url, {int w = 300, int h = 450}) {
  if (url.isEmpty || !url.contains('cloudinary.com')) return url;
  return url.replaceFirst('/upload/', '/upload/w_$w,h_$h,c_fill,q_auto,f_auto/');
}

// ══════════════════════════════════════════════════════════════
//  WATCHLIST MANAGER
// ══════════════════════════════════════════════════════════════

class WatchlistManager {
  static List<Map<String, String>> _watchlist = [];
  static List<Map<String, String>> get watchlist => _watchlist;

  static Future<void> init() async {
    _watchlist = await StorageService.loadWatchlist();
  }

  static bool isInWatchlist(String title) =>
      _watchlist.any((item) => item['title'] == title);

  static Future<void> toggle(Map<String, String> content) async {
    if (isInWatchlist(content['title']!)) {
      _watchlist.removeWhere((item) => item['title'] == content['title']);
    } else {
      _watchlist.add(content);
    }
    await StorageService.saveWatchlist(_watchlist);
  }
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
    AppNotification(id: '1', title: '¡Nuevo contenido disponible!',       body: 'Se agregaron nuevas películas y series. ¡Descúbrelas ahora!',                          type: NotifType.newContent,    time: DateTime.now().subtract(const Duration(minutes: 10))),
    AppNotification(id: '2', title: 'Próximo estreno esta semana',         body: 'Una serie que te puede gustar estrena nuevos episodios esta semana.',                  type: NotifType.upcoming,      time: DateTime.now().subtract(const Duration(hours: 3))),
    AppNotification(id: '3', title: 'Continúa viendo',                    body: 'Tienes contenido sin terminar en tu lista. ¿Quieres seguir viendo?',                   type: NotifType.reminder,      time: DateTime.now().subtract(const Duration(hours: 6))),
    AppNotification(id: '4', title: 'Tu suscripción vence pronto',         body: 'Tu plan Premium vence en 3 días. Renuévalo para seguir disfrutando.',                  type: NotifType.subscription,  time: DateTime.now().subtract(const Duration(days: 1))),
    AppNotification(id: '5', title: 'Inicio de sesión detectado',          body: 'Se inició sesión en tu cuenta desde un dispositivo Android en Sincelejo, Colombia.',  type: NotifType.login,         time: DateTime.now().subtract(const Duration(days: 2)), isRead: true),
    AppNotification(id: '6', title: 'Nuevo dispositivo vinculado',         body: 'Tu cuenta fue vinculada a un nuevo dispositivo: Samsung Galaxy S23.',                  type: NotifType.device,        time: DateTime.now().subtract(const Duration(days: 3)), isRead: true),
    AppNotification(id: '7', title: 'Contraseña actualizada',              body: 'Tu contraseña fue cambiada exitosamente. Si no fuiste tú, contacta soporte.',          type: NotifType.password,      time: DateTime.now().subtract(const Duration(days: 4)), isRead: true),
    AppNotification(id: '8', title: 'Alerta de seguridad',                 body: 'Detectamos un intento de acceso fallido a tu cuenta. Revisa tu configuración.',        type: NotifType.security,      time: DateTime.now().subtract(const Duration(days: 5)), isRead: true),
  ];

  static List<AppNotification> get all        => _list;
  static int get unreadCount                  => _list.where((n) => !n.isRead).length;
  static void markAsRead(String id)           { final i = _list.indexWhere((n) => n.id == id); if (i != -1) _list[i].isRead = true; }
  static void markAllAsRead()                 { for (final n in _list) n.isRead = true; }
  static void delete(String id)               => _list.removeWhere((n) => n.id == id);
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
//  MAIN
// ══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      colorScheme: const ColorScheme.dark(primary: Color(0xFFE50914)),
    ),
    home: const SplashScreen(),
  );
}

// ══════════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ══════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim, _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _animCtrl.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = await FirebaseAuth.instance.authStateChanges().first;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          user != null ? const ProfileSelectScreen() : const LoginScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override void dispose() { _animCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _animCtrl,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.4),
                      blurRadius: 30, spreadRadius: 5,
                    )],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                const Text('FLIXBOY', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8)),
                const SizedBox(height: 8),
                const Text('Tu plataforma de streaming', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 48),
                const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2)),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  LOGIN SCREEN
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true, _isLoading = false, _rememberMe = false;

  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)));

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _snack('Por favor completa todos los campos'); return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.login(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      await PushNotificationService.onLogin();
      Navigator.pushReplacement(context, AppRoute.fade(const ProfileSelectScreen()));
    } else {
      _snack(result.message ?? 'Error al iniciar sesión');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(fit: StackFit.expand, children: [

      // ── Fondo desde S3 vía Firestore ─────────────────────
      FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('config').doc('app').get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final url  = data?['loginBackground'] ?? '';
          if (url.isEmpty) return Container(color: const Color(0xFF141414));
          return Positioned.fill(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141414)),
            ),
          );
        },
      ),

      // ── Degradado ─────────────────────────────────────────
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x44000000), Color(0x99000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      )),

      // ── Contenido ─────────────────────────────────────────
      SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 60),
          const Text('FLIXBOY', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFFE50914), letterSpacing: 4)),
          const SizedBox(height: 60),
          _field(controller: _emailCtrl, hint: 'Email o número de teléfono', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl, obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: const TextStyle(color: Color(0xFF8C8C8C)),
              filled: true, fillColor: const Color(0xFF333333),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF8C8C8C)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('Iniciar sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                SizedBox(
                  width: 20, height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: const Color(0xFFE50914),
                    side: const BorderSide(color: Color(0xFF8C8C8C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Recuérdame', style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, AppRoute.slideUp(const ForgotPasswordScreen())),
                    child: const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(color: Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {},
                    child: const Text('¿Necesitas ayuda?',
                        style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 60),
          const Divider(color: Color(0xFF404040)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Eres nuevo en Flixboy? ', style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 15)),
            GestureDetector(
              onTap: () => Navigator.push(context, AppRoute.slideRight(const RegisterScreen())),
              child: const Text('Regístrate ahora',
                  style: TextStyle(color: Color(0xFFE50914), fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 32),
          const Text(
            'El acceso está protegido por reCAPTCHA de Google para asegurarnos de que no eres un robot.',
            style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ]),
      )),
    ]),
  );

  Widget _field({required TextEditingController controller, required String hint, TextInputType keyboardType = TextInputType.text}) =>
      TextField(
        controller: controller, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Color(0xFF8C8C8C)),
          filled: true, fillColor: const Color(0xFF333333),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  FORGOT PASSWORD SCREEN
// ══════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override void dispose() { _emailCtrl.dispose(); super.dispose(); }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)));

  Future<void> _send() async {
    if (_emailCtrl.text.trim().isEmpty) { _snack('Ingresa tu correo'); return; }
    setState(() => _isLoading = true);
    final result = await AuthService.forgotPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      _snack('Correo enviado. Revisa tu bandeja.');
      Navigator.pop(context);
    } else {
      _snack(result.message ?? 'Error al enviar correo');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Align(alignment: Alignment.centerLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
          const SizedBox(height: 20),
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFE50914).withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.lock_reset, size: 40, color: Color(0xFFE50914))),
          const SizedBox(height: 24),
          const Text('¿Olvidaste tu\ncontraseña?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('Te enviaremos un enlace a tu correo.',
              style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          TextField(
            controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Correo electrónico', labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar enlace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  REGISTER SCREEN
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
  bool _op = true, _oc = true, _isLoading = false;

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
    if (_passCtrl.text.length < 6) { _snack('Mínimo 6 caracteres'); return; }
    if (_passCtrl.text != _confirmCtrl.text) { _snack('Las contraseñas no coinciden'); return; }
    setState(() => _isLoading = true);
    final result = await AuthService.register(
        name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(), password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      await PushNotificationService.onLogin();
      Navigator.pushReplacement(context, AppRoute.fade(const ProfileSelectScreen()));
    } else {
      _snack(result.message ?? 'Error al registrarse');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)]),
      )),
      SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 40),
          const Text('FLIXBOY', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFFE50914), letterSpacing: 6)),
          const SizedBox(height: 8),
          const Text('Crea tu cuenta', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 40),
          _f(_nameCtrl,  'Nombre completo',    Icons.person_outline),   const SizedBox(height: 16),
          _f(_emailCtrl, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress), const SizedBox(height: 16),
          _pw(_passCtrl,    'Contraseña',           _op, () => setState(() => _op = !_op)), const SizedBox(height: 16),
          _pw(_confirmCtrl, 'Confirmar contraseña', _oc, () => setState(() => _oc = !_oc)), const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Ya tienes cuenta?', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Inicia sesión', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 20),
        ]),
      )),
    ]),
  );

  Widget _f(TextEditingController c, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) =>
      TextField(controller: c, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ));

  Widget _pw(TextEditingController c, String label, bool ob, VoidCallback t) =>
      TextField(controller: c, obscureText: ob,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(ob ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: t,
          ),
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ));
}

// ══════════════════════════════════════════════════════════════
//  HELPER SELECTOR DE IMÁGENES DE PERFIL
// ══════════════════════════════════════════════════════════════

Widget _buildImageSelector(List<String> imgs, String selImage, void Function(String) onSelect) {
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
              border: Border.all(color: isSel ? const Color(0xFFE50914) : Colors.transparent, width: 3),
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

// ══════════════════════════════════════════════════════════════
//  PROFILE SELECT SCREEN
// ══════════════════════════════════════════════════════════════

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});
  @override State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
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
        _profiles = [UserProfile(name: displayName, image: 'assets/images/profile1.jpg', isOwner: true)];
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 5 perfiles'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    final nameCtrl = TextEditingController();
    final pinCtrl  = TextEditingController();
    final pin2Ctrl = TextEditingController();
    String selImage = _imgs[_profiles.length % _imgs.length];
    bool hasPin = false, op = true, op2 = true;

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Nuevo perfil', style: TextStyle(color: Colors.white)),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildImageSelector(_imgs, selImage, (img) => set(() => selImage = img)),
        const SizedBox(height: 16),
        TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'Nombre', labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
            filled: true, fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        GestureDetector(onTap: () => set(() => hasPin = !hasPin),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.lock_outline, color: hasPin ? const Color(0xFFE50914) : Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Proteger con PIN', style: TextStyle(color: hasPin ? Colors.white : Colors.grey))),
              Switch(value: hasPin, onChanged: (v) => set(() => hasPin = v), activeColor: const Color(0xFFE50914)),
            ]))),
        if (hasPin) ...[
          const SizedBox(height: 12),
          TextField(controller: pinCtrl, obscureText: op, keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(counterText: '', labelText: 'PIN (4-6 dígitos)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.pin_outlined, color: Colors.grey),
              suffixIcon: IconButton(icon: Icon(op ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => set(() => op = !op)),
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          TextField(controller: pin2Ctrl, obscureText: op2, keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(counterText: '', labelText: 'Confirmar PIN',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.pin_outlined, color: Colors.grey),
              suffixIcon: IconButton(icon: Icon(op2 ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => set(() => op2 = !op2)),
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            if (hasPin && pinCtrl.text.length < 4) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN mínimo 4 dígitos'), backgroundColor: Color(0xFFE50914))); return;
            }
            if (hasPin && pinCtrl.text != pin2Ctrl.text) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs no coinciden'), backgroundColor: Color(0xFFE50914))); return;
            }
            setState(() => _profiles.add(UserProfile(name: nameCtrl.text.trim(), image: selImage, pin: hasPin ? pinCtrl.text : null)));
            await _persistProfiles();
            Navigator.pop(ctx);
          },
          child: const Text('Crear'),
        ),
      ],
    )));
  }

  void _selectProfile(UserProfile p) {
    final profileData = ProfileData(
      id: p.name, name: p.name, image: p.image, pin: p.pin,
      isOwner: p.isOwner, isKidsMode: p.isKidsMode,
    );

    if (p.pin != null) {
      final pinCtrl = TextEditingController();
      bool obscure = true, error = false;
      showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.asset(p.image, width: 36, height: 36, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ingresa el PIN para acceder.', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: pinCtrl, obscureText: obscure,
            keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '', hintText: '• • • •',
              hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 8),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => set(() => obscure = !obscure),
              ),
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: error ? const Color(0xFFE50914) : const Color(0xFF3A3A3A), width: 1.5),
              ),
            ),
            onChanged: (_) => set(() => error = false),
          ),
          if (error) ...[const SizedBox(height: 8), const Text('PIN incorrecto', style: TextStyle(color: Color(0xFFE50914), fontSize: 12))],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
            onPressed: () {
              if (pinCtrl.text == p.pin) {
                Navigator.pop(ctx);
                ProfileManager.setActiveProfile(profileData).then((_) {
                  if (profileData.isKidsMode) {
                    Navigator.pushReplacement(context, AppRoute.fade(KidsModeScreen(allContent: const [])));
                  } else {
                    Navigator.pushReplacement(context, AppRoute.fade(const HomeScreen()));
                  }
                });
              } else {
                set(() => error = true);
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      )));
    } else {
      ProfileManager.setActiveProfile(profileData).then((_) {
        if (profileData.isKidsMode) {
          Navigator.pushReplacement(context, AppRoute.fade(KidsModeScreen(allContent: const [])));
        } else {
          Navigator.pushReplacement(context, AppRoute.fade(const HomeScreen()));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 60),
        const Text('FLIXBOY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFE50914), letterSpacing: 4)),
        const SizedBox(height: 16),
        const Text('¿Quién está viendo?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 48),
        Expanded(child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          itemCount: _profiles.length + (_profiles.length < 5 ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _profiles.length) return GestureDetector(
              onTap: _addProfile,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 90, height: 90,
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 2)),
                  child: const Icon(Icons.add, size: 40, color: Colors.grey)),
                const SizedBox(height: 12),
                const Text('Agregar perfil', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                      decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.white, size: 14))),
                  if (p.isOwner) Positioned(top: 4, right: 4,
                    child: Container(width: 24, height: 24,
                      decoration: BoxDecoration(color: const Color(0xFFF57C00), shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A0A0A), width: 2)),
                      child: const Icon(Icons.star, color: Colors.white, size: 12))),
                  if (p.isKidsMode) Positioned(top: 4, left: 4,
                    child: Container(width: 24, height: 24,
                      decoration: const BoxDecoration(color: Color(0xFF00BCD4), shape: BoxShape.circle),
                      child: const Icon(Icons.child_care, color: Colors.white, size: 13))),
                ]),
                const SizedBox(height: 12),
                Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            );
          },
        )),
        TextButton.icon(
          onPressed: () => Navigator.push(context, AppRoute.slideUp(
            ManageProfilesScreen(profiles: _profiles, availableImages: _imgs),
          )).then((_) async { await _persistProfiles(); setState(() {}); }),
          icon: const Icon(Icons.edit, color: Colors.grey),
          label: const Text('Administrar perfiles', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        const SizedBox(height: 32),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MANAGE PROFILES SCREEN
// ══════════════════════════════════════════════════════════════

class ManageProfilesScreen extends StatefulWidget {
  final List<UserProfile> profiles;
  final List<String>      availableImages;
  const ManageProfilesScreen({super.key, required this.profiles, required this.availableImages});
  @override State<ManageProfilesScreen> createState() => _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  List<UserProfile> get _profiles => widget.profiles;

  void _editProfile(int index) {
    final p           = _profiles[index];
    final nameCtrl    = TextEditingController(text: p.name);
    final pinCtrl     = TextEditingController();
    final pin2Ctrl    = TextEditingController();
    String selImage   = p.image;
    bool hasPin       = p.pin != null;
    bool isKidsMode   = p.isKidsMode;
    bool op = true, op2 = true;

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Editar "${p.name}"', style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildImageSelector(widget.availableImages, selImage, (img) => set(() => selImage = img)),
        const SizedBox(height: 16),
        TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'Nombre', labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
            filled: true, fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => set(() { hasPin = !hasPin; if (!hasPin) { pinCtrl.clear(); pin2Ctrl.clear(); } }),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.lock_outline, color: hasPin ? const Color(0xFFE50914) : Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Proteger con PIN', style: TextStyle(color: hasPin ? Colors.white : Colors.grey))),
              Switch(value: hasPin, onChanged: (v) => set(() { hasPin = v; if (!v) { pinCtrl.clear(); pin2Ctrl.clear(); } }), activeColor: const Color(0xFFE50914)),
            ])),
        ),
        if (hasPin) ...[
          const SizedBox(height: 12),
          TextField(controller: pinCtrl, obscureText: op, keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(counterText: '', labelText: p.pin != null ? 'Nuevo PIN (vacío = mantener)' : 'PIN (4-6 dígitos)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.pin_outlined, color: Colors.grey),
              suffixIcon: IconButton(icon: Icon(op ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => set(() => op = !op)),
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          TextField(controller: pin2Ctrl, obscureText: op2, keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(counterText: '', labelText: 'Confirmar PIN',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.pin_outlined, color: Colors.grey),
              suffixIcon: IconButton(icon: Icon(op2 ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => set(() => op2 = !op2)),
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        ],
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.child_care_rounded, color: isKidsMode ? const Color(0xFF00BCD4) : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Modo niños', style: TextStyle(color: isKidsMode ? Colors.white : Colors.grey)),
              if (isKidsMode) const Text('Solo muestra contenido infantil', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ])),
            Switch(value: isKidsMode, onChanged: (v) => set(() => isKidsMode = v), activeColor: const Color(0xFF00BCD4)),
          ])),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            String? newPin = p.pin;
            if (hasPin && pinCtrl.text.isNotEmpty) {
              if (pinCtrl.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN mínimo 4 dígitos'), backgroundColor: Color(0xFFE50914))); return;
              }
              if (pinCtrl.text != pin2Ctrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs no coinciden'), backgroundColor: Color(0xFFE50914))); return;
              }
              newPin = pinCtrl.text;
            } else if (!hasPin) { newPin = null; }
            setState(() {
              _profiles[index].name       = nameCtrl.text.trim();
              _profiles[index].image      = selImage;
              _profiles[index].pin        = newPin;
              _profiles[index].isKidsMode = isKidsMode;
            });
            Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    )));
  }

  void _deleteProfile(int index) {
    if (_profiles[index].isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No puedes eliminar el perfil principal'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Eliminar perfil', style: TextStyle(color: Colors.white)),
      content: Text('¿Eliminar "${_profiles[index].name}"?', style: const TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
          onPressed: () { setState(() => _profiles.removeAt(index)); Navigator.pop(context); },
          child: const Text('Eliminar'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A), elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: const Text('Administrar perfiles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF1E1010), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3))),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF57C00).withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.star, color: Color(0xFFF57C00), size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Solo el creador puede administrar perfiles.', style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5))),
        ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _profiles.length,
        itemBuilder: (_, index) {
          final p = _profiles[index];
          return Container(margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
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
                    decoration: BoxDecoration(color: const Color(0xFFF57C00), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5)),
                    child: const Icon(Icons.star, color: Colors.white, size: 9))),
                if (p.isKidsMode) Positioned(top: 2, left: 2,
                  child: Container(width: 18, height: 18,
                    decoration: const BoxDecoration(color: Color(0xFF00BCD4), shape: BoxShape.circle),
                    child: const Icon(Icons.child_care, color: Colors.white, size: 10))),
              ]),
              title: Row(children: [
                Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (p.isOwner) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF57C00).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Creador', style: TextStyle(color: Color(0xFFF57C00), fontSize: 10, fontWeight: FontWeight.bold))),
                ],
                if (p.isKidsMode) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF00BCD4).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Kids', style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ]),
              subtitle: Text(p.pin != null ? 'Con PIN' : 'Sin PIN',
                style: TextStyle(color: p.pin != null ? const Color(0xFFE50914).withValues(alpha: 0.8) : Colors.grey, fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white70), onPressed: () => _editProfile(index)),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: p.isOwner ? Colors.grey.withValues(alpha: 0.3) : const Color(0xFFE50914)),
                  onPressed: p.isOwner ? null : () => _deleteProfile(index),
                ),
              ]),
            ));
        },
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int    _currentIndex   = 0;
  double _bannerOpacity  = 1.0;
  bool   _sidebarVisible = false;

  final ScrollController _scrollCtrl = ScrollController();

  List<ContentModel> _allContent = [];
  List<ContentModel> _trending   = [];
  List<ContentModel> _upcoming   = [];
  bool _loadingContent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(() {
      final opacity = (1.0 - (_scrollCtrl.offset / 200)).clamp(0.0, 1.0);
      if ((opacity - _bannerOpacity).abs() > 0.01) setState(() => _bannerOpacity = opacity);
    });
    _loadContent();
  }

  Future<void> _loadContent() async {
    final all      = await ContentService.getAllContent();
    final trending = await ContentService.getTrending();
    final upcoming = await ContentService.getUpcoming();
    final filtered = ProfileManager.filterForProfile(all);
    if (mounted) setState(() {
      _allContent     = filtered;
      _trending       = trending.isNotEmpty ? ProfileManager.filterForProfile(trending) : filtered.take(6).toList();
      _upcoming       = upcoming;
      _loadingContent = false;
    });
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !AuthService.isLoggedIn && mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        Navigator.push(context, AppRoute.slideRight(SearchScreen(allContent: _allContent)))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 2:
        Navigator.push(context, AppRoute.slideRight(const SeriesScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 3:
        Navigator.push(context, AppRoute.slideRight(const MoviesScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 4:
        Navigator.push(context, AppRoute.slideUp(const WatchlistScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 5:
        Navigator.push(context, AppRoute.slideRight(const CalendarScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
      case 6:
        Navigator.push(context, AppRoute.fade(const BrowseScreen()))
            .then((_) => setState(() => _currentIndex = 0));
        break;
    }
  }

  List<String> get _allGenres {
    final g = <String>{};
    for (final c in _allContent) { if (c.genre != 'Proximo estreno') g.add(c.genre); }
    return g.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final myList = WatchlistManager.watchlist;
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _bannerOpacity < 0.5 ? const Color(0xFF080808) : Colors.transparent,
            gradient: _bannerOpacity >= 0.5 ? LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.8 * (1 - _bannerOpacity)), Colors.transparent],
            ) : null,
          ),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _sidebarVisible ? const Color(0xFFE50914).withValues(alpha: 0.15) : Colors.transparent,
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
                const SizedBox(width: 10),
                AnimatedOpacity(
                  opacity: _bannerOpacity < 0.3 ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 200),
                  child: const Text('FLIXBOY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE50914), letterSpacing: 4)),
                ),
              ]),
              Row(children: [
                StatefulBuilder(builder: (ctx, setLocal) {
                  final count = NotificationsManager.unreadCount;
                  return Stack(children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () async {
                        await Navigator.push(ctx, AppRoute.slideUp(const NotificationsScreen()));
                        setLocal(() {});
                      },
                    ),
                    if (count > 0) Positioned(right: 6, top: 6,
                      child: Container(width: 18, height: 18,
                        decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
                        child: Center(child: Text(count > 9 ? '9+' : '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))),
                  ]);
                }),
                const SizedBox(width: 8),
                GestureDetector(
                     onTap: () => Navigator.push(context, AppRoute.fade(const ProfileSelectScreen())),
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      ProfileManager.activeProfile?.image ?? 'assets/images/profile1.jpg',
                      width: 32, height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const CircleAvatar(
                        radius: 16, backgroundColor: Color(0xFFE50914),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          )),
        ),
      ),
      body: Stack(children: [
        CustomScrollView(controller: _scrollCtrl, slivers: [
          if (_loadingContent)
            const SliverFillRemaining(hasScrollBody: false, child: HomeSkeletonScreen())
          else ...[
            if (_allContent.isNotEmpty)
              SliverToBoxAdapter(child: AnimatedOpacity(
                opacity: _bannerOpacity, duration: const Duration(milliseconds: 100),
                child: _buildHeroBanner(),
              )),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: ContinueWatchingSection()),
            if (_trending.isNotEmpty) ..._buildSection('Tendencias ahora', _trending),
            if (myList.isNotEmpty) ..._buildSection('Mi Lista', myList.map((m) => ContentModel(
              id: m['id'] ?? '', title: m['title'] ?? '', genre: m['genre'] ?? '',
              year: m['year'] ?? '', duration: m['duration'] ?? '', type: m['type'] ?? '',
              description: m['description'] ?? '', videoUrl: m['videoUrl'] ?? '', imagenUrl: m['imagenUrl'] ?? '',
            )).toList()),
            ..._allGenres.expand((genre) {
              final items = _allContent.where((c) => c.genre == genre).toList();
              if (items.isEmpty) return <Widget>[];
              return _buildSection(genre, items);
            }),
            if (_upcoming.isNotEmpty) ..._buildUpcomingSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ]),
        if (!_sidebarVisible) Positioned(left: 0, top: 0, bottom: 0, width: 30,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) { if (d.delta.dx > 3) setState(() => _sidebarVisible = true); },
            behavior: HitTestBehavior.translucent,
          )),
        if (_sidebarVisible) GestureDetector(
          onTap: () => setState(() => _sidebarVisible = false),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut,
          left: _sidebarVisible ? 0 : -220, top: 0, bottom: 0, width: 220,
          child: _buildSidebar(),
        ),
      ]),
    );
  }

  Widget _buildSidebar() => GestureDetector(
    onHorizontalDragUpdate: (d) { if (d.delta.dx < -5) setState(() => _sidebarVisible = false); },
    child: Container(
      decoration: BoxDecoration(color: const Color(0xFF0A0A0A),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5)]),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 16, 8), child: Row(children: [
          const Text('F', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFE50914))),
          const SizedBox(width: 2),
          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle)),
        ])),
        const SizedBox(height: 12),
        ...[
          {'icon': Icons.home_rounded,       'label': 'Inicio',     'index': 0},
          {'icon': Icons.search_rounded,     'label': 'Buscar',     'index': 1},
          {'icon': Icons.tv_rounded,         'label': 'Series',     'index': 2},
          {'icon': Icons.movie_rounded,      'label': 'Películas',  'index': 3},
          {'icon': Icons.add_circle_outline, 'label': 'Mi Lista',   'index': 4},
          {'icon': Icons.calendar_month,     'label': 'Calendario', 'index': 5},
          {'icon': Icons.explore_rounded,    'label': 'Explorar',   'index': 6},
        ].map((item) {
          final isActive = item['index'] == _currentIndex;
          return GestureDetector(
            onTap: () { setState(() => _sidebarVisible = false); _onNavTap(item['index'] as int); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE50914).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isActive ? Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 1) : null,
              ),
              child: Row(children: [
                Icon(item['icon'] as IconData, color: isActive ? const Color(0xFFE50914) : Colors.white70, size: 24),
                const SizedBox(width: 14),
                Text(item['label'] as String, style: TextStyle(
                  color: isActive ? const Color(0xFFE50914) : Colors.white70,
                  fontSize: 15, fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
            if (mounted) Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          },
          child: Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.logout, color: Color(0xFFE50914), size: 20),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(color: Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.bold)),
            ])),
        ),
        const SizedBox(height: 8),
      ])),
    ),
  );

  Widget _bl(bool active, {bool top = false, bool mid = false, bool bottom = false}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
        width: mid ? (active ? 14 : 20) : 20, height: 2.2,
        margin: EdgeInsets.only(left: mid ? (active ? 3 : 0) : 0),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE50914) : Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeroBanner() {
    final featured = _allContent.first;
    final imgUrl   = cloudinaryOptimized(featured.imagenUrl, w: 800, h: 600);
    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoute.scaleDetail(DetailScreen(content: featured))),
      child: SizedBox(height: MediaQuery.of(context).size.height * 0.62,
        child: Stack(fit: StackFit.expand, children: [
          featured.imagenUrl.isNotEmpty
              ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _heroBannerFallback())
              : _heroBannerFallback(),
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x80000000), Color(0xFF080808)],
            stops: [0.3, 0.7, 1.0],
          ))),
          Positioned(bottom: 40, left: 20, right: 20,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: Text(featured.type.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 4, fontWeight: FontWeight.w500))),
              const SizedBox(height: 12),
              Text(featured.title.toUpperCase(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 0.9, letterSpacing: -1)),
              const SizedBox(height: 12),
              Text(featured.description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              Row(children: [
                SizedBox(height: 44, child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, AppRoute.playerFade(
                      VideoPlayerScreen(videoUrl: featured.videoUrl, title: featured.title, content: featured))),
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                  label: const Text('Reproducir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                )),
                const SizedBox(width: 10),
                SizedBox(height: 44, child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, AppRoute.scaleDetail(DetailScreen(content: featured))),
                  icon: Icon(Icons.info_outline_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
                  label: Text('Más info', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.4)), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16)),
                )),
              ]),
            ])),
        ]),
      ),
    );
  }

  Widget _heroBannerFallback() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1A0A0A), Color(0xFF2D0505), Color(0xFF1A0A0A), Color(0xFF080808)],
        stops: [0.0, 0.3, 0.7, 1.0]),
  ));

  List<Widget> _buildSection(String title, List<ContentModel> items) => [
    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)))),
    SliverToBoxAdapter(child: SizedBox(height: 200, child: ListView.builder(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length, itemBuilder: (_, i) => _contentCard(items[i])))),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];

  List<Widget> _buildUpcomingSection() => [
    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Row(children: [
        const Text('Próximos estrenos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
          child: const Text('PRONTO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
      ]))),
    SliverToBoxAdapter(child: SizedBox(height: 200, child: ListView.builder(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _upcoming.length, itemBuilder: (_, i) => _upcomingCard(_upcoming[i])))),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];

  Widget _contentCard(ContentModel c) => Container(
    width: 120, margin: const EdgeInsets.only(right: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: TapScale(
        onTap: () => Navigator.push(context, AppRoute.scaleDetail(DetailScreen(content: c))),
        child: HeroPoster(
          contentId: c.id, imageUrl: c.imagenUrl,
          width: 120, height: 160, borderRadius: BorderRadius.circular(6),
        ),
      )),
      const SizedBox(height: 6),
      Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: genreColor(c.genre), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(c.genre, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        const Spacer(),
        Text(c.year, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ]),
    ]),
  );

  Widget _cardPlaceholder(ContentModel c) => Stack(fit: StackFit.expand, children: [
    Container(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [genreColor(c.genre).withValues(alpha: 0.85), genreColor(c.genre).withValues(alpha: 0.3), const Color(0xFF111111)],
    ))),
    Center(child: Icon(c.type == 'Serie' ? Icons.tv_rounded : Icons.movie_rounded,
        size: 36, color: Colors.white.withValues(alpha: 0.25))),
  ]);

  Widget _upcomingCard(ContentModel c) => Container(
    width: 120, margin: const EdgeInsets.only(right: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          c.imagenUrl.isNotEmpty
              ? ColorFiltered(colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                  child: Image.network(cloudinaryOptimized(c.imagenUrl, w: 120, h: 160), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _cardPlaceholder(c)))
              : _cardPlaceholder(c),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.access_time_rounded, size: 28, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 4),
            Text(c.year, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold)),
          ])),
          Positioned(top: 6, right: 6,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(3)),
              child: const Text('PRONTO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)))),
        ]))),
      const SizedBox(height: 6),
      Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: genreColor(c.genre), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(c.genre, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  DETAIL SCREEN
// ══════════════════════════════════════════════════════════════

class DetailScreen extends StatefulWidget {
  final ContentModel content;
  const DetailScreen({super.key, required this.content});
  @override State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ContentModel get c => widget.content;

  void _toggle() {
    WatchlistManager.toggle(c.toMap()).then((_) {
      if (!mounted) return;
      setState(() {});
      final inList = WatchlistManager.isInWatchlist(c.title);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(inList ? 'Agregado a Mi Lista' : 'Eliminado de Mi Lista'),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final inList = WatchlistManager.isInWatchlist(c.title);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true,
          backgroundColor: const Color(0xFF0A0A0A),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          flexibleSpace: FlexibleSpaceBar(background: Stack(children: [
            Positioned.fill(child: Hero(
              tag: 'poster_${c.id}',
              child: c.imagenUrl.isNotEmpty
                  ? Image.network(cloudinaryOptimized(c.imagenUrl, w: 800, h: 400), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [genreColor(c.genre).withValues(alpha: 0.7), const Color(0xFF0A0A0A)]))))
                  : Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [genreColor(c.genre).withValues(alpha: 0.7), const Color(0xFF0A0A0A)]))),
            )),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(height: 120, decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xFF0A0A0A), Colors.transparent])))),
          ])),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: genreColor(c.genre), borderRadius: BorderRadius.circular(4)),
                child: Text(c.genre, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              _tag(c.type), _tag(c.year), _tag(c.duration),
              if (c.isPremium) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF57C00), borderRadius: BorderRadius.circular(4)),
                child: const Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 20),
            // Botón reproducir
SizedBox(width: double.infinity, height: 52,
  child: ElevatedButton.icon(
    onPressed: () => Navigator.push(context, AppRoute.playerFade(
        VideoPlayerScreen(videoUrl: c.videoUrl, title: c.title, content: c))),
    icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
    label: const Text('Reproducir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  ),
),
const SizedBox(height: 12),

// Botón trailer
if (c.trailerUrl.isNotEmpty)
  SizedBox(width: double.infinity, height: 52,
    child: OutlinedButton.icon(
      onPressed: () => _showTrailerDialog(context),
      icon: const Icon(Icons.movie_outlined, color: Color(0xFFE50914), size: 22),
      label: const Text('Ver Trailer', style: TextStyle(color: Color(0xFFE50914), fontSize: 16, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE50914), width: 1.5),
        foregroundColor: const Color(0xFFE50914),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  ),
            const SizedBox(height: 24),
            const Text('Sinopsis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(c.description, style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.6)),
            const SizedBox(height: 24),
            const Text('Calificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            RatingWidget(contentId: c.id),
            const SizedBox(height: 80),
          ]))),
      ]),
    );
  }

  void _showTrailerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(c.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, AppRoute.playerFade(
                    VideoPlayerScreen(videoUrl: c.trailerUrl, title: '${c.title} - Trailer', content: c),
                  ));
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: c.imagenUrl.isNotEmpty
                          ? Image.network(c.imagenUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 200, color: const Color(0xFF111111),
                                  child: const Icon(Icons.movie, color: Colors.grey, size: 60)))
                          : Container(height: 200, color: const Color(0xFF111111),
                              child: const Icon(Icons.movie, color: Colors.grey, size: 60)),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(height: 200, width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.4)),
                    ),
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.5),
                          blurRadius: 20, spreadRadius: 2,
                        )],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                    ),
                    Positioned(top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
                        child: const Text('TRAILER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, AppRoute.playerFade(
                      VideoPlayerScreen(videoUrl: c.videoUrl, title: c.title, content: c),
                    ));
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                  label: const Text('Ver película completa', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _tag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12)),
  );
}

// ══════════════════════════════════════════════════════════════
//  PROFILE SCREEN
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
      Container(width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)])),
        child: Column(children: [
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(50),
            child: Image.asset('assets/images/profile1.jpg', width: 100, height: 100, fit: BoxFit.cover)),
          const SizedBox(height: 16),
          Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _plan == 'premium' ? const Color(0xFFF57C00).withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _plan == 'premium' ? const Color(0xFFF57C00) : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Text(_plan == 'premium' ? 'Plan Premium' : 'Plan Gratuito',
              style: TextStyle(color: _plan == 'premium' ? const Color(0xFFF57C00) : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
        ])),
      Padding(padding: const EdgeInsets.all(16),
        child: Row(children: [_stat(WatchlistManager.watchlist.length.toString(), 'Mi lista'), _stat(_plan == 'premium' ? 'PRO' : 'FREE', 'Plan')])),
      const Divider(color: Color(0xFF1E1E1E)),
      _opt(Icons.bookmark_outline,       'Mi Lista',        () => Navigator.push(context, AppRoute.slideUp(const WatchlistScreen()))),
      _opt(Icons.history,                'Historial',       () => Navigator.push(context, AppRoute.slideRight(const HistoryScreen()))),
      _opt(Icons.notifications_outlined, 'Notificaciones',  () => Navigator.push(context, AppRoute.slideUp(const NotificationsScreen()))),
      _opt(Icons.star_outline,           'Suscripción',     _showSubscriptionDialog),
      _opt(Icons.explore_rounded,        'Explorar',        () => Navigator.push(context, AppRoute.fade(const BrowseScreen()))),
      _opt(Icons.help_outline,           'Ayuda',           () {}),
      const Divider(color: Color(0xFF1E1E1E)),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: NotificationPreferences(),
      ),
      const Divider(color: Color(0xFF1E1E1E)),
      ListTile(
        leading: const Icon(Icons.logout, color: Color(0xFFE50914)),
        title: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFE50914))),
        onTap: () async {
          await PushNotificationService.onLogout();
          await AuthService.logout();
          if (context.mounted) Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        },
      ),
      const SizedBox(height: 80),
    ]))),
  );

  void _showSubscriptionDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Suscripción', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF57C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.3))),
          child: const Column(children: [
            Text('Plan Premium', style: TextStyle(color: Color(0xFFF57C00), fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Acceso a todo el contenido\nSin anuncios\nCalidad HD\n1 mes de duración',
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.6)),
          ])),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF57C00), foregroundColor: Colors.white),
          onPressed: () async {
            await SubscriptionService.activatePremium();
            Navigator.pop(context);
            _loadUser();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Plan Premium activado!'), backgroundColor: Color(0xFFF57C00)));
          },
          child: const Text('Activar Premium'),
        ),
      ],
    ));
  }

  Widget _stat(String v, String l) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
    Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)),
  ]));

  Widget _opt(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: Colors.white70),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    onTap: onTap,
  );
}

// ══════════════════════════════════════════════════════════════
//  SEARCH SCREEN
// ══════════════════════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  final List<ContentModel> allContent;
  const SearchScreen({super.key, required this.allContent});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  ContentFilter _filter = ContentFilter();

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  List<ContentModel> get _results => _query.isEmpty ? [] :
      _filter.apply(widget.allContent.where((c) =>
          c.title.toLowerCase().contains(_query.toLowerCase()) ||
          c.genre.toLowerCase().contains(_query.toLowerCase())).toList());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: TextField(
        controller: _ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar películas, series...',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _query.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () { _ctrl.clear(); setState(() => _query = ''); })
              : null,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      actions: [
        Stack(children: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => FilterSheet.show(
              context,
              current:         _filter,
              availableGenres: widget.allContent.map((c) => c.genre).toSet().toList()..sort(),
              onApply: (f) => setState(() => _filter = f),
            ),
          ),
          if (_filter.hasFilters) Positioned(right: 8, top: 8,
            child: Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle))),
        ]),
      ],
    ),
    body: _query.isEmpty
        ? _cats()
        : _results.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No se encontró "$_query"', style: const TextStyle(color: Colors.grey, fontSize: 16)),
              ]))
            : _list(),
  );

  Widget _cats() {
    final genres = [
      {'name': 'Acción',   'icon': Icons.local_fire_department},
      {'name': 'Drama',    'icon': Icons.theater_comedy},
      {'name': 'Comedia',  'icon': Icons.emoji_emotions},
      {'name': 'Terror',   'icon': Icons.nightlight},
      {'name': 'Aventura', 'icon': Icons.explore},
      {'name': 'Sci-Fi',   'icon': Icons.rocket_launch},
    ];
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Explorar por género', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 16),
      Expanded(child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
        itemCount: genres.length,
        itemBuilder: (_, i) {
          final g = genres[i];
          return GestureDetector(
            onTap: () => setState(() { _query = g['name'] as String; _ctrl.text = _query; }),
            child: Container(
              decoration: BoxDecoration(color: genreColor(g['name'] as String), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(g['icon'] as IconData, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(g['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          );
        },
      )),
    ]));
  }

  Widget _list() => StaggerList(
    children: _results.map((item) => GestureDetector(
      onTap: () => Navigator.push(context, AppRoute.scaleDetail(DetailScreen(content: item))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            child: item.imagenUrl.isNotEmpty
                ? Image.network(cloudinaryOptimized(item.imagenUrl, w: 90, h: 90), width: 90, height: 90, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _sPlaceholder(item))
                : _sPlaceholder(item),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: genreColor(item.genre), borderRadius: BorderRadius.circular(4)),
                  child: Text(item.genre, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 6),
                Text(item.type, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Text('${item.year} - ${item.duration}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]))),
          const Icon(Icons.chevron_right, color: Colors.grey),
          const SizedBox(width: 8),
        ]),
      ),
    )).toList(),
  );

  Widget _sPlaceholder(ContentModel item) => Container(width: 90, height: 90,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [genreColor(item.genre), const Color(0xFF1A1A1A)])),
    child: Icon(item.type == 'Serie' ? Icons.tv : Icons.movie, size: 36, color: Colors.white.withValues(alpha: 0.4)));
}

// ══════════════════════════════════════════════════════════════
//  WATCHLIST SCREEN
// ══════════════════════════════════════════════════════════════

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final wl = WatchlistManager.watchlist;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text('Mi Lista (${wl.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: wl.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.bookmark_outline, size: 80, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Tu lista está vacía', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Agrega películas y series para verlas después',
                  style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: wl.length,
              itemBuilder: (ctx, i) {
                final item  = wl[i];
                final model = ContentModel(id: item['id'] ?? '', title: item['title'] ?? '',
                    genre: item['genre'] ?? '', year: item['year'] ?? '', duration: item['duration'] ?? '',
                    type: item['type'] ?? '', description: item['description'] ?? '',
                    videoUrl: item['videoUrl'] ?? '', imagenUrl: item['imagenUrl'] ?? '');
                return GestureDetector(
                  onTap: () => Navigator.push(ctx, AppRoute.scaleDetail(DetailScreen(content: model)))
                      .then((_) => setState(() {})),
                  child: Container(margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                        child: (item['imagenUrl'] ?? '').isNotEmpty
                            ? Image.network(cloudinaryOptimized(item['imagenUrl']!, w: 90, h: 90),
                                width: 90, height: 90, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _wlPlaceholder(item))
                            : _wlPlaceholder(item)),
                      const SizedBox(width: 12),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: genreColor(item['genre'] ?? ''), borderRadius: BorderRadius.circular(4)),
                              child: Text(item['genre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 6),
                            Text(item['type'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          Text('${item['year']} - ${item['duration']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ]))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFE50914)),
                        onPressed: () async { await WatchlistManager.toggle(item); setState(() {}); },
                      ),
                    ])),
                );
              },
            ),
    );
  }

  Widget _wlPlaceholder(Map<String, String> item) => Container(width: 90, height: 90,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [genreColor(item['genre'] ?? ''), const Color(0xFF1A1A1A)])),
    child: Icon(item['type'] == 'Serie' ? Icons.tv : Icons.movie, size: 36, color: Colors.white.withValues(alpha: 0.4)));
}

// ══════════════════════════════════════════════════════════════
//  NOTIFICATIONS SCREEN
// ══════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          if (unread > 0) Text('$unread sin leer', style: const TextStyle(color: Color(0xFFE50914), fontSize: 12)),
        ]),
        actions: [
          if (unread > 0) TextButton(
            onPressed: () { NotificationsManager.markAllAsRead(); setState(() {}); },
            child: const Text('Marcar todo', style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
          ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none, size: 80, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Sin notificaciones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
      color: const Color(0xFFE50914), child: const Icon(Icons.delete_outline, color: Colors.white, size: 28)),
    onDismissed: (_) {
      NotificationsManager.delete(n.id); setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Eliminada'), backgroundColor: Color(0xFF1E1E1E), duration: Duration(seconds: 2)));
    },
    child: GestureDetector(
      onTap: () { NotificationsManager.markAsRead(n.id); setState(() {}); },
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: n.isRead ? const Color(0xFF141414) : const Color(0xFF1E1010),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: n.isRead ? Colors.transparent : const Color(0xFFE50914).withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _iconBg(n.type), borderRadius: BorderRadius.circular(10)),
            child: Icon(_iconData(n.type), color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title,
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold))),
              if (!n.isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(n.body, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(_ago(n.time), style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 11)),
          ])),
        ]))),
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
      case NotifType.login:        return const Color(0xFF1565C0);
      case NotifType.device:       return const Color(0xFF2E7D32);
      case NotifType.password:     return const Color(0xFFF57C00);
      case NotifType.subscription: return const Color(0xFF6A1B9A);
      case NotifType.security:     return const Color(0xFFE50914);
      case NotifType.newContent:   return const Color(0xFFE50914);
      case NotifType.upcoming:     return const Color(0xFF00838F);
      case NotifType.reminder:     return const Color(0xFF37474F);
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