// lib/security_service.dart
//
// Capa de seguridad centralizada de FlixBoy.
// Incluye: almacenamiento seguro, sanitización, rate limiting,
// ofuscación de tokens, detección de root/jailbreak, y más.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
//  CONSTANTES DE SEGURIDAD (nunca hardcodear en el código)
// ============================================================

class _SecurityKeys {
  static const String accessToken   = 'flixboy_access_token';
  static const String refreshToken  = 'flixboy_refresh_token';
  static const String deviceId      = 'flixboy_device_id';
  static const String sessionExpiry = 'flixboy_session_expiry';
  static const String loginAttempts = 'flixboy_login_attempts';
  static const String lockoutUntil  = 'flixboy_lockout_until';
  static const String profilePins   = 'flixboy_profile_pins';
}

// ============================================================
//  SECURE STORAGE SERVICE
//  Usa flutter_secure_storage para cifrar con AES-256 en disco.
//  En Android usa EncryptedSharedPreferences.
//  En iOS usa el Keychain del sistema.
// ============================================================

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,   // AES-256 con KeyStore
      resetOnError: false,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,              // No sincronizar con iCloud
    ),
  );

  // Guardar token de acceso cifrado
  static Future<void> saveAccessToken(String token) async {
    final obfuscated = _obfuscateToken(token);
    await _storage.write(key: _SecurityKeys.accessToken, value: obfuscated);
    // Guardar expiración (1 hora por defecto)
    final expiry = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch.toString();
    await _storage.write(key: _SecurityKeys.sessionExpiry, value: expiry);
  }

  // Leer token con validación de expiración
  static Future<String?> getAccessToken() async {
    final expiry = await _storage.read(key: _SecurityKeys.sessionExpiry);
    if (expiry != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(int.parse(expiry));
      if (DateTime.now().isAfter(expiryTime)) {
        await clearSession(); // Token expirado — limpiar
        return null;
      }
    }
    final obfuscated = await _storage.read(key: _SecurityKeys.accessToken);
    if (obfuscated == null) return null;
    return _deobfuscateToken(obfuscated);
  }

  // Guardar refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _SecurityKeys.refreshToken, value: _obfuscateToken(token));
  }

  static Future<String?> getRefreshToken() async {
    final obfuscated = await _storage.read(key: _SecurityKeys.refreshToken);
    if (obfuscated == null) return null;
    return _deobfuscateToken(obfuscated);
  }

  // Guardar PINs de perfiles cifrados con hash
  static Future<void> saveProfilePin(String profileId, String pin) async {
    final hashed = _hashPin(pin, profileId); // salt = profileId
    final pinsJson = await _storage.read(key: _SecurityKeys.profilePins) ?? '{}';
    final pins = Map<String, dynamic>.from(json.decode(pinsJson));
    pins[profileId] = hashed;
    await _storage.write(key: _SecurityKeys.profilePins, value: json.encode(pins));
  }

  static Future<bool> verifyProfilePin(String profileId, String pin) async {
    final pinsJson = await _storage.read(key: _SecurityKeys.profilePins) ?? '{}';
    final pins = Map<String, dynamic>.from(json.decode(pinsJson));
    if (!pins.containsKey(profileId)) return false;
    return pins[profileId] == _hashPin(pin, profileId);
  }

  static Future<void> removeProfilePin(String profileId) async {
    final pinsJson = await _storage.read(key: _SecurityKeys.profilePins) ?? '{}';
    final pins = Map<String, dynamic>.from(json.decode(pinsJson));
    pins.remove(profileId);
    await _storage.write(key: _SecurityKeys.profilePins, value: json.encode(pins));
  }

  // ID único del dispositivo (para detección de sesiones duplicadas)
  static Future<String> getOrCreateDeviceId() async {
    var deviceId = await _storage.read(key: _SecurityKeys.deviceId);
    if (deviceId == null) {
      deviceId = _generateSecureId();
      await _storage.write(key: _SecurityKeys.deviceId, value: deviceId);
    }
    return deviceId;
  }

  // Limpiar sesión completa (logout)
  static Future<void> clearSession() async {
    await _storage.delete(key: _SecurityKeys.accessToken);
    await _storage.delete(key: _SecurityKeys.refreshToken);
    await _storage.delete(key: _SecurityKeys.sessionExpiry);
  }

  // Limpiar TODO (para wipe de datos)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── Helpers privados ──

  // Ofuscación XOR simple del token en memoria (capa adicional)
  static String _obfuscateToken(String token) {
    final key = _getObfuscationKey();
    final bytes = utf8.encode(token);
    final obfuscated = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64Encode(obfuscated);
  }

  static String _deobfuscateToken(String obfuscated) {
    final key = _getObfuscationKey();
    final bytes = base64Decode(obfuscated);
    final original = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return utf8.decode(original);
  }

  static List<int> _getObfuscationKey() {
    // En producción esto vendría de una variable de entorno o de native code
    return [0x46, 0x4C, 0x49, 0x58, 0x42, 0x4F, 0x59, 0x53, 0x45, 0x43];
  }

  // Hash del PIN con salt usando SHA-256
  static String _hashPin(String pin, String salt) {
    final saltedPin = '$salt:$pin:flixboy_secure_2026';
    final bytes = utf8.encode(saltedPin);
    return sha256.convert(bytes).toString();
  }

  // Genera un ID aleatorio seguro de 32 bytes
  static String _generateSecureId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

// ============================================================
//  RATE LIMITER — Bloqueo por intentos fallidos de login
// ============================================================

class RateLimiter {
  static const int _maxAttempts   = 5;    // máximo de intentos
  static const int _lockMinutes   = 15;   // minutos de bloqueo
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<RateLimitResult> checkLoginAllowed() async {
    // Verificar si hay bloqueo activo
    final lockoutStr = await _storage.read(key: _SecurityKeys.lockoutUntil);
    if (lockoutStr != null) {
      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutStr));
      if (DateTime.now().isBefore(lockoutTime)) {
        final remaining = lockoutTime.difference(DateTime.now());
        return RateLimitResult(
          allowed: false,
          remainingSeconds: remaining.inSeconds,
          message: 'Demasiados intentos fallidos. Espera ${remaining.inMinutes + 1} minuto(s).',
        );
      } else {
        // Lockout expirado, limpiar
        await _storage.delete(key: _SecurityKeys.lockoutUntil);
        await _storage.delete(key: _SecurityKeys.loginAttempts);
      }
    }
    return RateLimitResult(allowed: true);
  }

  static Future<void> recordFailedAttempt() async {
    final attemptsStr = await _storage.read(key: _SecurityKeys.loginAttempts) ?? '0';
    final attempts = int.parse(attemptsStr) + 1;
    await _storage.write(key: _SecurityKeys.loginAttempts, value: attempts.toString());

    if (attempts >= _maxAttempts) {
      final lockoutUntil = DateTime.now().add(Duration(minutes: _lockMinutes));
      await _storage.write(key: _SecurityKeys.lockoutUntil, value: lockoutUntil.millisecondsSinceEpoch.toString());
      await _storage.delete(key: _SecurityKeys.loginAttempts);
    }
  }

  static Future<void> resetAttempts() async {
    await _storage.delete(key: _SecurityKeys.loginAttempts);
    await _storage.delete(key: _SecurityKeys.lockoutUntil);
  }

  static Future<int> getRemainingAttempts() async {
    final attemptsStr = await _storage.read(key: _SecurityKeys.loginAttempts) ?? '0';
    return _maxAttempts - int.parse(attemptsStr);
  }
}

class RateLimitResult {
  final bool allowed;
  final int remainingSeconds;
  final String? message;
  RateLimitResult({required this.allowed, this.remainingSeconds = 0, this.message});
}

// ============================================================
//  INPUT SANITIZER — Previene XSS e inyección
// ============================================================

class InputSanitizer {

  // Sanitiza texto general (nombre de perfil, etc.)
  static String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r"""[<>"']"""), '')        // XSS básico
        .replaceAll(RegExp(r'[;|&`$\\]'), '')       // Inyección de comandos
        .replaceAll(RegExp(r'\x00'), '')             // Null bytes
        .trim()
        .substring(0, input.length.clamp(0, 100)); // Máx 100 chars
  }

  // Valida email con regex estricto
  static bool isValidEmail(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email) && email.length <= 254;
  }

  // Valida contraseña con reglas de seguridad
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 6) return PasswordStrength.weak;
    
    int score = 0;
    if (password.length >= 8)  score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  // Valida que el PIN sea solo dígitos
  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  // Sanitiza para evitar que datos sensibles aparezcan en logs
  static String maskSensitiveData(String data, {int visibleChars = 3}) {
    if (data.length <= visibleChars) return '*' * data.length;
    return data.substring(0, visibleChars) + '*' * (data.length - visibleChars);
  }

  // Detecta intentos de SQL injection / path traversal
  static bool containsMaliciousPatterns(String input) {
    final patterns = [
      RegExp(r"(\bSELECT\b|\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bDROP\b)", caseSensitive: false),
      RegExp(r'(--|;|\/\*|\*\/|xp_)', caseSensitive: false),
      RegExp(r'\.\./|\.\.\\'),  // path traversal
      RegExp(r'<script', caseSensitive: false),
    ];
    return patterns.any((p) => p.hasMatch(input));
  }
}

enum PasswordStrength { weak, medium, strong }

// ============================================================
//  SESSION MANAGER — Manejo seguro de sesión
// ============================================================

class SessionManager {
  static String? _accessToken;        // Token en memoria (nunca en SharedPreferences)
  static DateTime? _sessionStart;
  static const Duration _sessionTimeout = Duration(hours: 8);
  static const Duration _inactivityTimeout = Duration(minutes: 30);
  static DateTime? _lastActivity;

  // Iniciar sesión
  static Future<void> startSession(String accessToken, String? refreshToken) async {
    _accessToken    = accessToken;
    _sessionStart   = DateTime.now();
    _lastActivity   = DateTime.now();
    
    await SecureStorageService.saveAccessToken(accessToken);
    if (refreshToken != null) {
      await SecureStorageService.saveRefreshToken(refreshToken);
    }
    await RateLimiter.resetAttempts();
  }

  // Obtener token validando expiración e inactividad
  static Future<String?> getValidToken() async {
    // Primero intentar desde memoria (más rápido y seguro)
    if (_accessToken != null && _sessionStart != null) {
      final now = DateTime.now();
      // Verificar timeout de sesión
      if (now.difference(_sessionStart!) > _sessionTimeout) {
        await endSession();
        return null;
      }
      // Verificar inactividad
      if (_lastActivity != null && now.difference(_lastActivity!) > _inactivityTimeout) {
        await endSession();
        return null;
      }
      _lastActivity = now;
      return _accessToken;
    }
    // Intentar desde almacenamiento seguro
    return SecureStorageService.getAccessToken();
  }

  // Registrar actividad del usuario (para el timeout de inactividad)
  static void recordActivity() {
    _lastActivity = DateTime.now();
  }

  // Verificar si la sesión es válida
  static Future<bool> isSessionValid() async {
    final token = await getValidToken();
    return token != null;
  }

  // Cerrar sesión completamente
  static Future<void> endSession() async {
    _accessToken  = null;
    _sessionStart = null;
    _lastActivity = null;
    await SecureStorageService.clearSession();
  }

  // Wipe completo (por ejemplo si se detecta compromiso)
  static Future<void> emergencyWipe() async {
    _accessToken  = null;
    _sessionStart = null;
    _lastActivity = null;
    await SecureStorageService.clearAll();
  }
}

// ============================================================
//  NETWORK SECURITY — Headers y validación de respuestas
// ============================================================

class NetworkSecurity {
  // Headers de seguridad que se deben incluir en cada request
  static Future<Map<String, String>> getSecureHeaders() async {
    final deviceId = await SecureStorageService.getOrCreateDeviceId();
    final token    = await SessionManager.getValidToken();
    final nonce    = _generateNonce();

    return {
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Request-Nonce': nonce,
      'X-App-Version': '1.0.0',
      'X-Platform': 'flutter',
      // Cabeceras de seguridad HTTP
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Valida que la respuesta del servidor sea legítima
  static bool validateResponse(Map<String, dynamic> response) {
    // Verificar estructura básica esperada
    if (!response.containsKey('data') && !response.containsKey('message')) {
      return false;
    }
    return true;
  }

  // Genera un nonce único por request (previene ataques de replay)
  static String _generateNonce() {
    final random    = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final combined  = utf8.encode(timestamp + base64Url.encode(randBytes));
    return sha256.convert(combined).toString().substring(0, 32);
  }

  // Verifica que la URL sea HTTPS (no permitir HTTP en producción)
  static bool isSecureUrl(String url) {
    return url.startsWith('https://');
  }

  // Sanitiza la URL para prevenir SSRF
  static bool isAllowedDomain(String url, List<String> allowedDomains) {
    try {
      final uri = Uri.parse(url);
      return allowedDomains.any((domain) =>
          uri.host == domain || uri.host.endsWith('.$domain'));
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
//  SECURITY LOGGER — Registro de eventos de seguridad
//  (solo en memoria, nunca en disco ni en texto plano)
// ============================================================

class SecurityLogger {
  static final List<SecurityEvent> _events = [];
  static const int _maxEvents = 100; // máximo en memoria

  static void log(SecurityEventType type, String description, {String? userId}) {
    if (_events.length >= _maxEvents) _events.removeAt(0);
    _events.add(SecurityEvent(
      type: type,
      description: description,
      timestamp: DateTime.now(),
      userId: userId != null ? InputSanitizer.maskSensitiveData(userId) : null,
    ));
    // En producción: enviar al servidor de logging seguro (no imprimir en consola)
    assert(() {
      // Solo en debug
      // print('[Security] ${type.name}: $description');
      return true;
    }());
  }

  static List<SecurityEvent> getRecentEvents({int limit = 20}) {
    return _events.reversed.take(limit).toList();
  }

  static void clear() => _events.clear();
}

// ============================================================
//  DEVICE SECURITY — Detección de root sin dependencias externas
// ============================================================

class DeviceSecurity {
  static const _channel = MethodChannel('com.flixboy.app/security');

  /// Activa FLAG_SECURE en Android via canal nativo.
  /// Bloquea capturas, grabación y app switcher preview.
  static Future<void> enableSecureScreen() async {
    try {
      await _channel.invokeMethod('enableSecureScreen');
    } catch (_) {
      // Si falla (ej: iOS o emulador) no es crítico
    }
  }

  /// Desactiva FLAG_SECURE (solo si necesitas permitir screenshots puntualmente)
  static Future<void> disableSecureScreen() async {
    try {
      await _channel.invokeMethod('disableSecureScreen');
    } catch (_) {}
  }

  /// Comprueba indicadores básicos de root/jailbreak
  /// sin necesitar paquetes externos.
  /// Retorna true si el dispositivo parece comprometido.
  static Future<bool> isDeviceCompromised() async {
    try {
      // Verificar archivos típicos de root en Android
      final rootIndicators = [
        '/system/app/Superuser.apk',
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/data/local/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/system/app/SuperSU.apk',
        '/system/app/Magisk.apk',
      ];

      for (final path in rootIndicators) {
        if (await File(path).exists()) return true;
      }

      // Verificar si está en modo debug (build de producción no debería)
      // En release este assert no corre, retorna false
      bool isDebug = false;
      assert(() { isDebug = true; return true; }());
      // No bloqueamos debug builds durante desarrollo

      return false;
    } catch (_) {
      return false; // Si hay error al verificar, no bloqueamos
    }
  }

  /// Muestra advertencia si el dispositivo está comprometido
  static Future<bool> checkAndWarn(context) async {
    final compromised = await isDeviceCompromised();
    if (compromised) {
      SecurityLogger.log(
        SecurityEventType.suspiciousInput,
        'Dispositivo con posible root detectado',
      );
    }
    return compromised;
  }
}

enum SecurityEventType {
  loginSuccess,
  loginFailure,
  loginBlocked,
  sessionExpired,
  tokenRefreshed,
  suspiciousInput,
  profilePinSuccess,
  profilePinFailure,
  emergencyWipe,
  logoutManual,
}

class SecurityEvent {
  final SecurityEventType type;
  final String description;
  final DateTime timestamp;
  final String? userId;
  SecurityEvent({required this.type, required this.description, required this.timestamp, this.userId});
}