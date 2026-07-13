// lib/auth_screens.dart
// Pantallas de autenticación: bienvenida, login, registro, recuperación de contraseña.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'profile_screens.dart';
import 'status_screens.dart';

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
        if (user != null) await LocalSessionManager.save(user);
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
        if (user != null) await LocalSessionManager.save(user);
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
      SafeArea(child: SingleChildScrollView(
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
