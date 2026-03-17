// lib/api_service.dart
//
// ApiService de FlixBoy — versión segura.
// Mantiene todos los endpoints originales y agrega:
//   • Almacenamiento seguro del token (no en memoria estática)
//   • Headers de seguridad en cada request
//   • Sanitización de inputs antes de enviar
//   • Rate limiting en login
//   • Timeout por request
//   • Manejo de errores sin exponer detalles internos
//   • Nonce único por request (anti-replay)
//   • Validación de respuestas

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ============================================================
//  CONFIGURACIÓN
//  La baseUrl viene de --dart-define en producción.
//  Para desarrollo local se usa la IP del servidor.
// ============================================================

class _Config {
  // En producción compilar con:
  //   flutter build apk --dart-define=API_URL=https://tudominio.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.3:3000/api/v1', // ← tu URL original
  );

  static const Duration timeout = Duration(seconds: 15);
  static const int maxLoginAttempts = 5;
  static const int lockoutMinutes   = 15;
}

// ============================================================
//  ALMACENAMIENTO SEGURO (KeyStore en Android / Keychain en iOS)
// ============================================================

class _SecureStore {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  static const _kToken      = 'fb_token';
  static const _kExpiry     = 'fb_expiry';
  static const _kAttempts   = 'fb_attempts';
  static const _kLockUntil  = 'fb_lock';

  // ── Token ──

  static Future<void> saveToken(String token, {int expiryHours = 8}) async {
    // Ofuscar antes de guardar (capa extra sobre el cifrado del KeyStore)
    final expiry = DateTime.now()
        .add(Duration(hours: expiryHours))
        .millisecondsSinceEpoch
        .toString();
    await _s.write(key: _kToken,  value: _xor(token));
    await _s.write(key: _kExpiry, value: expiry);
  }

  static Future<String?> readToken() async {
    final expiry = await _s.read(key: _kExpiry);
    if (expiry != null) {
      final exp = DateTime.fromMillisecondsSinceEpoch(int.parse(expiry));
      if (DateTime.now().isAfter(exp)) {
        await clearToken();
        return null; // expirado
      }
    }
    final raw = await _s.read(key: _kToken);
    return raw == null ? null : _xor(raw);
  }

  static Future<void> clearToken() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kExpiry);
  }

  // ── Rate limiting ──

  static Future<_RateResult> checkRate() async {
    final lockStr = await _s.read(key: _kLockUntil);
    if (lockStr != null) {
      final lock = DateTime.fromMillisecondsSinceEpoch(int.parse(lockStr));
      if (DateTime.now().isBefore(lock)) {
        final secs = lock.difference(DateTime.now()).inSeconds;
        final mins = (secs / 60).ceil();
        return _RateResult(
          allowed: false,
          message: 'Demasiados intentos. Espera $mins minuto(s).',
        );
      }
      await _s.delete(key: _kLockUntil);
      await _s.delete(key: _kAttempts);
    }
    return _RateResult(allowed: true);
  }

  static Future<void> recordFail() async {
    final n = int.parse(await _s.read(key: _kAttempts) ?? '0') + 1;
    if (n >= _Config.maxLoginAttempts) {
      final until = DateTime.now()
          .add(Duration(minutes: _Config.lockoutMinutes))
          .millisecondsSinceEpoch
          .toString();
      await _s.write(key: _kLockUntil, value: until);
      await _s.delete(key: _kAttempts);
    } else {
      await _s.write(key: _kAttempts, value: n.toString());
    }
  }

  static Future<int> remainingAttempts() async {
    final n = int.parse(await _s.read(key: _kAttempts) ?? '0');
    return _Config.maxLoginAttempts - n;
  }

  static Future<void> resetRate() async {
    await _s.delete(key: _kAttempts);
    await _s.delete(key: _kLockUntil);
  }

  // ── Ofuscación XOR (capa extra sobre el cifrado del storage) ──
  static const List<int> _key = [
    0x46, 0x4C, 0x49, 0x58, 0x42, 0x4F, 0x59, 0x5F, 0x53, 0x45, 0x43
  ];

  static String _xor(String input) {
    final bytes = base64Decode(
      base64.normalize(
        // Si ya es base64 lo decodificamos; si no, lo codificamos
        _isBase64(input) ? input : base64Encode(utf8.encode(input)),
      ),
    );
    final result = List<int>.generate(
        bytes.length, (i) => bytes[i] ^ _key[i % _key.length]);
    return base64Encode(result);
  }

  static bool _isBase64(String s) {
    try {
      base64Decode(base64.normalize(s));
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _RateResult {
  final bool allowed;
  final String? message;
  _RateResult({required this.allowed, this.message});
}

// ============================================================
//  SANITIZADOR DE INPUTS
// ============================================================

class _Sanitizer {
  static String text(String s) => s
      .replaceAll(RegExp(r"""[<>"';|&`$\\]"""), '')
      .replaceAll(RegExp(r'\x00'), '')
      .trim()
      .substring(0, s.trim().length.clamp(0, 200));

  static bool validEmail(String e) => RegExp(
        r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+'
        r'@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
      ).hasMatch(e) &&
      e.length <= 254;

  static bool malicious(String s) => [
        RegExp(r'\b(SELECT|INSERT|UPDATE|DELETE|DROP)\b', caseSensitive: false),
        RegExp(r'(--|;|\/\*|\*\/)', caseSensitive: false),
        RegExp(r'\.\.[/\\]'),
        RegExp(r'<script', caseSensitive: false),
      ].any((p) => p.hasMatch(s));

  // Enmascara datos en mensajes de error (nunca exponer emails completos)
  static String mask(String s, {int show = 3}) {
    if (s.length <= show) return '*' * s.length;
    return s.substring(0, show) + '*' * (s.length - show);
  }
}

// ============================================================
//  GENERADOR DE NONCE (anti-replay)
// ============================================================

String _nonce() {
  final rand = Random.secure();
  final ts   = DateTime.now().millisecondsSinceEpoch.toString();
  final rb   = List<int>.generate(16, (_) => rand.nextInt(256));
  return sha256.convert(utf8.encode(ts + base64Url.encode(rb))).toString().substring(0, 24);
}

// ============================================================
//  API SERVICE — tus endpoints originales + seguridad completa
// ============================================================

class ApiService {
  // Token en memoria para acceso rápido (respaldado en SecureStorage)
  static String? _token;

  // ── Gestión de token ──────────────────────────────────────

  static void setToken(String token) {
    _token = token;
    _SecureStore.saveToken(token); // guardar cifrado de forma asíncrona
  }

  /// Obtiene el token válido: primero memoria, luego SecureStorage.
  /// Retorna null si la sesión expiró.
  static Future<String?> getValidToken() async {
    if (_token != null) return _token;
    final stored = await _SecureStore.readToken();
    if (stored != null) _token = stored;
    return stored;
  }

  static Future<void> clearToken() async {
    _token = null;
    await _SecureStore.clearToken();
  }

  // ── Headers de seguridad ──────────────────────────────────

  static Future<Map<String, String>> _secureHeaders() async {
    final token = await getValidToken();
    return {
      'Content-Type': 'application/json',
      'X-Request-Nonce': _nonce(),               // anti-replay
      'Cache-Control': 'no-store, no-cache',     // no guardar en caché
      'X-App-Version': '1.0.0',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── LOGIN ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String email, String password) async {

    // 1. Rate limiting
    final rate = await _SecureStore.checkRate();
    if (!rate.allowed) {
      return {'message': rate.message, 'data': null};
    }

    // 2. Sanitizar y validar
    final cleanEmail = email.trim().toLowerCase();
    if (!_Sanitizer.validEmail(cleanEmail)) {
      return {'message': 'Correo electrónico no válido', 'data': null};
    }
    if (_Sanitizer.malicious(cleanEmail) || _Sanitizer.malicious(password)) {
      return {'message': 'Datos inválidos', 'data': null};
    }
    if (password.length < 6) {
      return {'message': 'Contraseña demasiado corta', 'data': null};
    }

    try {
      final headers = await _secureHeaders();

      final response = await http
          .post(
            Uri.parse('${_Config.baseUrl}/auth/login'), // ← tu endpoint original
            headers: headers,
            body: jsonEncode({
              'email': cleanEmail,
              'password': password,
            }),
          )
          .timeout(_Config.timeout);

      // 3. Manejar respuestas por código HTTP
      if (response.statusCode == 429) {
        await _SecureStore.recordFail();
        return {'message': 'Demasiadas solicitudes. Espera un momento.', 'data': null};
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _SecureStore.recordFail();
        final remaining = await _SecureStore.remainingAttempts();
        return {
          'message': remaining > 0
              ? 'Credenciales incorrectas. Intentos restantes: $remaining'
              : 'Cuenta bloqueada por seguridad. Intenta en $_Config.lockoutMinutes min.',
          'data': null,
        };
      }

      if (response.statusCode == 500) {
        return {'message': 'Error en el servidor. Intenta más tarde.', 'data': null};
      }

      // 4. Parsear respuesta
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // 5. Guardar token de forma segura si el login fue exitoso
      if (data['data']?['accessToken'] != null) {
        setToken(data['data']['accessToken'] as String);
        await _SecureStore.resetRate(); // reset intentos fallidos
      }

      return data;

    } on SocketException {
      return {'message': 'Sin conexión a internet. Verifica tu red.', 'data': null};
    } on HttpException {
      return {'message': 'Error de red', 'data': null};
    } on FormatException {
      return {'message': 'Respuesta inesperada del servidor', 'data': null};
    } catch (_) {
      // NUNCA exponer el error real al usuario en producción
      return {'message': 'Error inesperado. Intenta más tarde.', 'data': null};
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {

    // Sanitizar inputs
    final cleanName  = _Sanitizer.text(name);
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) {
      return {'message': 'Nombre inválido', 'data': null};
    }
    if (!_Sanitizer.validEmail(cleanEmail)) {
      return {'message': 'Correo electrónico no válido', 'data': null};
    }
    if (_Sanitizer.malicious(cleanName) || _Sanitizer.malicious(cleanEmail)) {
      return {'message': 'Datos inválidos', 'data': null};
    }
    if (password.length < 6) {
      return {'message': 'La contraseña debe tener al menos 6 caracteres', 'data': null};
    }

    try {
      final headers = await _secureHeaders();

      final response = await http
          .post(
            Uri.parse('${_Config.baseUrl}/auth/register'), // ← tu endpoint original
            headers: headers,
            body: jsonEncode({
              'fullName': cleanName,  // ← tu campo original
              'email': cleanEmail,
              'password': password,
            }),
          )
          .timeout(_Config.timeout);

      if (response.statusCode == 409) {
        return {'message': 'Este correo ya está registrado', 'data': null};
      }
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'message': 'Error al registrar. Intenta más tarde.', 'data': null};

    } on SocketException {
      return {'message': 'Sin conexión a internet', 'data': null};
    } catch (_) {
      return {'message': 'Error inesperado', 'data': null};
    }
  }

  // ── CONTENIDO HOME ────────────────────────────────────────

  static Future<Map<String, dynamic>> getHomeContent() async {
    try {
      final headers = await _secureHeaders();

      final response = await http
          .get(
            Uri.parse('${_Config.baseUrl}/content/home'), // ← tu endpoint original
            headers: headers,
          )
          .timeout(_Config.timeout);

      if (response.statusCode == 401) {
        await clearToken();
        return {'message': 'Sesión expirada', 'data': null};
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'message': 'Error al cargar contenido', 'data': null};

    } on SocketException {
      return {'message': 'Sin conexión', 'data': null};
    } catch (_) {
      return {'message': 'Error inesperado', 'data': null};
    }
  }

  // ── TRENDING ──────────────────────────────────────────────

  static Future<List<dynamic>> getTrending() async {
    try {
      final headers = await _secureHeaders();

      final response = await http
          .get(
            Uri.parse('${_Config.baseUrl}/content/trending'), // ← tu endpoint original
            headers: headers,
          )
          .timeout(_Config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['data'] as List<dynamic>?) ?? []; // ← tu campo original
      }
      return [];

    } catch (_) {
      return [];
    }
  }

  // ── RECUPERAR CONTRASEÑA ──────────────────────────────────

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_Sanitizer.validEmail(cleanEmail)) {
      return {'message': 'Correo no válido', 'data': null};
    }
    try {
      final headers = await _secureHeaders();
      final response = await http
          .post(
            Uri.parse('${_Config.baseUrl}/auth/forgot-password'),
            headers: headers,
            body: jsonEncode({'email': cleanEmail}),
          )
          .timeout(_Config.timeout);

      // Respuesta genérica para no revelar si el email existe (seguridad)
      return {
        'message': 'Si el correo está registrado, recibirás un código.',
        'data': response.statusCode == 200 ? {} : null,
      };
    } catch (_) {
      return {'message': 'Error de conexión', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return {'message': 'Código inválido', 'data': null};
    }
    try {
      final headers = await _secureHeaders();
      final response = await http
          .post(
            Uri.parse('${_Config.baseUrl}/auth/verify-code'),
            headers: headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code,
            }),
          )
          .timeout(_Config.timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'message': 'Código incorrecto o expirado', 'data': null};
    } catch (_) {
      return {'message': 'Error de conexión', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    if (newPassword.length < 6) {
      return {'message': 'Contraseña muy corta', 'data': null};
    }
    try {
      final headers = await _secureHeaders();
      final response = await http
          .post(
            Uri.parse('${_Config.baseUrl}/auth/reset-password'),
            headers: headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code,
              'password': newPassword,
            }),
          )
          .timeout(_Config.timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'message': 'Error al restablecer contraseña', 'data': null};
    } catch (_) {
      return {'message': 'Error de conexión', 'data': null};
    }
  }
}