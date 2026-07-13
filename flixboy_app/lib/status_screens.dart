// lib/status_screens.dart
// Pantallas de estado: sin conexión, error del servidor, registro exitoso, actualización, carga.
import 'package:flutter/material.dart';
import 'app_transitions.dart';
import 'auth_screens.dart';
import 'profile_screens.dart';
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
 

