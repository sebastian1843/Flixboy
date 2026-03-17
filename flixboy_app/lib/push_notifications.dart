// lib/push_notifications.dart
//
// Notificaciones push para Flixboy usando Firebase Cloud Messaging.
// Incluye:
//   • Inicialización y permisos
//   • Guardar token FCM en Firestore
//   • Manejar notificaciones en primer plano, background y terminado
//   • Navegar a la pantalla correcta al tocar la notificación
//   • Notificaciones locales como fallback en primer plano

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';
import 'main.dart'; // DetailScreen

// ── Handler global para mensajes en background ─────────────────
// IMPORTANTE: debe ser función top-level (fuera de cualquier clase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado en main()
  // Solo loguear — la notificación la muestra el sistema
  debugPrint('📩 Push background: ${message.notification?.title}');
}

// ══════════════════════════════════════════════════════════════
//  PUSH NOTIFICATION SERVICE
// ══════════════════════════════════════════════════════════════

class PushNotificationService {
  static final _fcm      = FirebaseMessaging.instance;
  static final _db       = FirebaseFirestore.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  // Canal de notificaciones Android
  static const _channel = AndroidNotificationChannel(
    'flixboy_channel',
    'Flixboy Notificaciones',
    description: 'Notificaciones de Flixboy',
    importance: Importance.high,
    playSound: true,
  );

  // Callback para navegar al tocar notificación
  static void Function(Map<String, dynamic> data)? onNotificationTap;

  // ── Inicializar (llamar en main() antes de runApp) ────────

  static Future<void> init() async {
    // 1. Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // 2. Solicitar permisos
    await _fcm.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );

    // 3. Crear canal Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Inicializar notificaciones locales
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:     DarwinInitializationSettings(
          requestAlertPermission: false, // ya pedimos arriba
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        // Tocar notificación local
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            onNotificationTap?.call(data);
          } catch (_) {}
        }
      },
    );

    // 5. Guardar token en Firestore
    await _saveToken();
    _fcm.onTokenRefresh.listen(_saveTokenString);

    // 6. Manejar notificación cuando la app estaba cerrada
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessage(initial, fromBackground: true);

    // 7. Manejar notificación cuando la app estaba en background
    FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _handleMessage(m, fromBackground: true));

    // 8. Manejar notificación en primer plano (mostrar local)
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _handleMessage(message, fromBackground: false);
    });
  }

  // ── Guardar token FCM en Firestore ────────────────────────

  static Future<void> _saveToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveTokenString(token);
  }

  static Future<void> _saveTokenString(String token) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Llamar al hacer logout para eliminar el token
  static Future<void> removeToken() async {
    final uid   = AuthService.currentUser?.uid;
    final token = await _fcm.getToken();
    if (uid == null || token == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {}
    await _fcm.deleteToken();
  }

  // ── Suscribirse a tópicos ─────────────────────────────────

  // Suscribe al usuario a notificaciones de nuevos estrenos
  static Future<void> subscribeToNewReleases() async =>
      _fcm.subscribeToTopic('new_releases');

  // Suscribe por género favorito
  static Future<void> subscribeToGenre(String genre) async =>
      _fcm.subscribeToTopic('genre_${genre.toLowerCase()}');

  static Future<void> unsubscribeFromGenre(String genre) async =>
      _fcm.unsubscribeFromTopic('genre_${genre.toLowerCase()}');

  // ── Mostrar notificación local (cuando app está en primer plano) ──

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    await _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:         Importance.high,
          priority:           Priority.high,
          icon:               '@mipmap/ic_launcher',
          color:              const Color(0xFFE50914),
          largeIcon: notif.android?.imageUrl != null
              ? DrawableResourceAndroidBitmap('@mipmap/ic_launcher')
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Manejar datos de la notificación ─────────────────────

  static void _handleMessage(RemoteMessage message,
      {required bool fromBackground}) {
    final data = message.data;
    if (data.isEmpty) return;
    // Si venía de background o app cerrada, navegar inmediato
    if (fromBackground) {
      onNotificationTap?.call(data);
    }
  }

  // ── Suscripciones por defecto al iniciar sesión ───────────

  static Future<void> onLogin() async {
    await _saveToken();
    await subscribeToNewReleases();
  }

  static Future<void> onLogout() async {
    await removeToken();
    await _fcm.unsubscribeFromTopic('new_releases');
  }
}

// ══════════════════════════════════════════════════════════════
//  NOTIFICATION NAVIGATOR
//  Maneja a qué pantalla ir según los datos de la notificación
// ══════════════════════════════════════════════════════════════

class NotificationNavigator {
  static GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void handleData(Map<String, dynamic> data) {
    final type      = data['type']      as String?;
    final contentId = data['contentId'] as String?;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'new_content':
        // Ir al DetailScreen del nuevo contenido
        if (contentId != null) {
          _goToContent(context, contentId);
        }
        break;
      case 'subscription':
        // Ir al perfil / suscripción
        Navigator.of(context).pushNamed('/profile');
        break;
      case 'security':
        // Ir a notificaciones
        Navigator.of(context).pushNamed('/notifications');
        break;
      default:
        // Ir a la pantalla de notificaciones general
        Navigator.of(context).pushNamed('/notifications');
    }
  }

  static Future<void> _goToContent(
      BuildContext context, String contentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('content')
          .doc(contentId)
          .get();
      if (!doc.exists) return;
      final content = ContentModel.fromFirestore(doc);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => DetailScreen(content: content)),
        );
      }
    } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════════════
//  WIDGET DE PREFERENCIAS DE NOTIFICACIONES
//  Para mostrar en ProfileScreen o ajustes
// ══════════════════════════════════════════════════════════════

class NotificationPreferences extends StatefulWidget {
  const NotificationPreferences({super.key});

  @override
  State<NotificationPreferences> createState() =>
      _NotificationPreferencesState();
}

class _NotificationPreferencesState
    extends State<NotificationPreferences> {
  bool _newReleases = true;
  bool _accion      = false;
  bool _drama       = false;
  bool _animacion   = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Notificaciones',
          style: TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _toggle(
        icon:  Icons.new_releases_outlined,
        title: 'Nuevos estrenos',
        sub:   'Aviso cuando llegue contenido nuevo',
        value: _newReleases,
        onChanged: (v) async {
          setState(() => _newReleases = v);
          v
              ? await PushNotificationService.subscribeToNewReleases()
              : await FirebaseMessaging.instance
                  .unsubscribeFromTopic('new_releases');
        },
      ),
      const Divider(color: Color(0xFF2A2A2A)),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Por género',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      _toggle(
        icon:  Icons.local_fire_department,
        title: 'Acción',
        value: _accion,
        onChanged: (v) async {
          setState(() => _accion = v);
          v
              ? await PushNotificationService.subscribeToGenre('acción')
              : await PushNotificationService.unsubscribeFromGenre('acción');
        },
      ),
      _toggle(
        icon:  Icons.theater_comedy,
        title: 'Drama',
        value: _drama,
        onChanged: (v) async {
          setState(() => _drama = v);
          v
              ? await PushNotificationService.subscribeToGenre('drama')
              : await PushNotificationService.unsubscribeFromGenre('drama');
        },
      ),
      _toggle(
        icon:  Icons.animation,
        title: 'Animación',
        value: _animacion,
        onChanged: (v) async {
          setState(() => _animacion = v);
          v
              ? await PushNotificationService.subscribeToGenre('animación')
              : await PushNotificationService.unsubscribeFromGenre('animación');
        },
      ),
    ],
  );

  Widget _toggle({
    required IconData icon,
    required String   title,
    String?           sub,
    required bool     value,
    required void Function(bool) onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: Colors.white70, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white,
              fontSize: 14)),
          if (sub != null)
            Text(sub, style: const TextStyle(
                color: Colors.grey, fontSize: 12)),
        ],
      )),
      Switch(
        value:       value,
        onChanged:   onChanged,
        activeColor: const Color(0xFFE50914),
      ),
    ]),
  );
}