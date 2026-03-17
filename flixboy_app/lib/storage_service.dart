// lib/storage_service.dart
//
// Gestión de almacenamiento local de FlixBoy:
//   • Sesión/tokens → flutter_secure_storage (cifrado AES-256)
//   • Perfiles      → SharedPreferences (datos no sensibles, por usuario)
//   • Watchlist     → SharedPreferences (datos no sensibles, por usuario)

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {

  // ── Almacenamiento SEGURO para tokens (AES-256) ───────────
  static const _secure = FlutterSecureStorage(
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

  // Claves del almacenamiento seguro
  static const _kSessionActive = 'fb_session_active';
  static const _kUserEmail     = 'fb_user_email';
  static const _kUserName      = 'fb_user_name';

  // ── UID del usuario actual ────────────────────────────────
  // Cada usuario tiene sus propias claves → aislamiento de datos
  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  static String get _kProfiles  => 'fb_profiles_$_uid';
  static String get _kWatchlist => 'fb_watchlist_$_uid';

  // ============================================================
  //  SESIÓN (almacenamiento seguro cifrado)
  //  FIX: ya no usa SharedPreferences para datos de sesión
  // ============================================================

  static Future<void> saveSession({
    required String email,
    required String name,
  }) async {
    await _secure.write(key: _kSessionActive, value: 'true');
    await _secure.write(key: _kUserEmail,     value: email);
    await _secure.write(key: _kUserName,      value: name);
  }

  static Future<bool> hasActiveSession() async {
    try {
      final val = await _secure.read(key: _kSessionActive);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> getSessionUser() async {
    try {
      return {
        'email': await _secure.read(key: _kUserEmail) ?? '',
        'name':  await _secure.read(key: _kUserName)  ?? 'Usuario',
      };
    } catch (_) {
      return {'email': '', 'name': 'Usuario'};
    }
  }

  static Future<void> clearSession() async {
    try {
      await _secure.delete(key: _kSessionActive);
      await _secure.delete(key: _kUserEmail);
      await _secure.delete(key: _kUserName);
    } catch (_) {}
  }

  // ============================================================
  //  PERFILES (SharedPreferences — datos no sensibles)
  //  Los PINs se guardan hasheados en SecureStorage por separado
  // ============================================================

  static Future<void> saveProfiles(
      List<Map<String, dynamic>> profiles) async {
    try {
      final p = await SharedPreferences.getInstance();
      // No guardamos el PIN en texto plano en SharedPreferences
      final sanitized = profiles.map((profile) {
        final copy = Map<String, dynamic>.from(profile);
        copy.remove('pin'); // El PIN se guarda por separado cifrado
        return copy;
      }).toList();
      await p.setString(_kProfiles, jsonEncode(sanitized));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadProfiles() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kProfiles);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── PIN de perfil (cifrado seguro) ────────────────────────

  static Future<void> saveProfilePin(String profileName, String pin) async {
    // El PIN se hashea con SHA-256 antes de guardar
    // Clave: pin_profileName_uid
    final key = 'pin_${profileName}_$_uid';
    await _secure.write(key: key, value: pin); // ya hasheado desde security_service
  }

  static Future<String?> getProfilePin(String profileName) async {
    try {
      final key = 'pin_${profileName}_$_uid';
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteProfilePin(String profileName) async {
    try {
      final key = 'pin_${profileName}_$_uid';
      await _secure.delete(key: key);
    } catch (_) {}
  }

  // ============================================================
  //  WATCHLIST (SharedPreferences — datos no sensibles)
  // ============================================================

  static Future<void> saveWatchlist(
      List<Map<String, String>> watchlist) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kWatchlist, jsonEncode(watchlist));
    } catch (_) {}
  }

  static Future<List<Map<String, String>>> loadWatchlist() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kWatchlist);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(
              (e as Map).map((k, v) => MapEntry(
                  k.toString(), v?.toString() ?? ''))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  //  WIPE COMPLETO (para logout seguro)
  // ============================================================

  static Future<void> clearAll() async {
    try {
      // Limpiar datos seguros
      await clearSession();
      // Limpiar SharedPreferences del usuario actual
      final p = await SharedPreferences.getInstance();
      await p.remove(_kProfiles);
      await p.remove(_kWatchlist);
    } catch (_) {}
  }
}