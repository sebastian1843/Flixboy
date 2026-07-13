// lib/account_screens.dart
// Pantallas de cuenta: mi lista, notificaciones, perfil, configuración, control parental.
import 'package:flutter/material.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'profile_manager.dart';
import 'video_player_screen.dart';
import 'auth_screens.dart';
import 'content_screens.dart';
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
          await LocalSessionManager.clear();
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
 
