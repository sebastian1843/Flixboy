// lib/firebase_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ContentModel {
  final String id;
  final String title;
  final String genre;
  final String year;
  final String duration;
  final String type;
  final String description;
  final String videoUrl;
  final String imagenUrl;
  final String trailerUrl;
  final String seriesId;
  final bool isPremium;
  final bool isTrending;
  final bool isUpcoming;

  ContentModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.duration,
    required this.type,
    required this.description,
    required this.videoUrl,
    this.imagenUrl  = '',
    this.trailerUrl = '',
    this.seriesId   = '',
    this.isPremium  = false,
    this.isTrending = false,
    this.isUpcoming = false,
  });

  ContentModel copyWith({String? seriesId}) => ContentModel(
    id:          id,
    title:       title,
    genre:       genre,
    year:        year,
    duration:    duration,
    type:        type,
    description: description,
    videoUrl:    videoUrl,
    imagenUrl:   imagenUrl,
    trailerUrl:  trailerUrl,
    seriesId:    seriesId ?? this.seriesId,
    isPremium:   isPremium,
    isTrending:  isTrending,
    isUpcoming:  isUpcoming,
  );

  static bool _parseBool(dynamic v) {
    if (v is bool)   return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is int)    return v == 1;
    return false;
  }

  factory ContentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // ── isUpcoming: acepta campo booleano O genre con variantes de texto ──
    final rawBool   = _parseBool(d['isUpcoming']);
    final rawGenre  = (d['genre'] ?? '').toString().trim().toLowerCase()
        .replaceAll('ó', 'o').replaceAll('é', 'e')
        .replaceAll('á', 'a').replaceAll('í', 'i').replaceAll('ú', 'u');
    final isUpcoming = rawBool || rawGenre.contains('proximo') || rawGenre.contains('upcoming');

    return ContentModel(
      id:          doc.id,
      title:       (d['title']       ?? '').toString().trim(),
      genre:       (d['genre']       ?? '').toString().trim(),
      year:        (d['year']        ?? '').toString().trim(),
      duration:    (d['duration']    ?? '').toString().trim(),
      type:        (d['type']        ?? 'Película').toString().trim(),
      description: (d['description'] ?? '').toString().trim(),
      videoUrl:    (d['videoUrl']    ?? '').toString().trim(),
      imagenUrl:   (d['imagenUrl']   ?? '').toString().trim(),
      trailerUrl:  (d['trailerUrl']  ?? '').toString().trim(),
      isPremium:   _parseBool(d['isPremium']),
      isTrending:  _parseBool(d['isTrending']),
      isUpcoming:  isUpcoming,
    );
  }

  factory ContentModel.fromJson(Map<String, dynamic> d) {
    final rawBool  = _parseBool(d['isUpcoming']);
    final rawGenre = (d['genre'] ?? '').toString().trim().toLowerCase()
        .replaceAll('ó', 'o').replaceAll('é', 'e')
        .replaceAll('á', 'a').replaceAll('í', 'i').replaceAll('ú', 'u');
    final isUpcoming = rawBool || rawGenre.contains('proximo') || rawGenre.contains('upcoming');

    return ContentModel(
      id:          (d['id']          ?? '').toString().trim(),
      title:       (d['title']       ?? '').toString().trim(),
      genre:       (d['genre']       ?? '').toString().trim(),
      year:        (d['year']        ?? '').toString().trim(),
      duration:    (d['duration']    ?? '').toString().trim(),
      type:        (d['type']        ?? 'Película').toString().trim(),
      description: (d['description'] ?? '').toString().trim(),
      videoUrl:    (d['videoUrl']    ?? '').toString().trim(),
      imagenUrl:   (d['imagenUrl']   ?? '').toString().trim(),
      trailerUrl:  (d['trailerUrl']  ?? '').toString().trim(),
      isPremium:   _parseBool(d['isPremium']),
      isTrending:  _parseBool(d['isTrending']),
      isUpcoming:  isUpcoming,
    );
  }

  Map<String, String> toMap() => {
    'id':          id,
    'title':       title,
    'genre':       genre,
    'year':        year,
    'duration':    duration,
    'type':        type,
    'description': description,
    'videoUrl':    videoUrl,
    'imagenUrl':   imagenUrl,
    'trailerUrl':  trailerUrl,
    'seriesId':    seriesId,
  };

  bool get isPelicula {
    final t = type.toLowerCase()
        .replaceAll('í', 'i').replaceAll('é', 'e')
        .replaceAll('á', 'a').replaceAll('ó', 'o').replaceAll('ú', 'u');
    return t.contains('pel') || t == 'movie';
  }

  bool get isSerie {
    final t = type.toLowerCase();
    return t.contains('serie') || t == 's' || t == 'series';
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String plan;
  final DateTime createdAt;
  final DateTime? expiresAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.plan,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isPremium =>
      plan == 'premium' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:       doc.id,
      name:      (d['name']  ?? 'Usuario').toString(),
      email:     (d['email'] ?? '').toString(),
      plan:      (d['plan']  ?? 'free').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AuthResult {
  final bool success;
  final String? message;
  AuthResult({required this.success, this.message});
}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  static User?         get currentUser       => _auth.currentUser;
  static bool          get isLoggedIn        => _auth.currentUser != null;
  static Stream<User?> get authStateChanges  => _auth.authStateChanges();

  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await _db.collection('users').doc(credential.user!.uid).set({
        'name':      name.trim(),
        'email':     email.trim().toLowerCase(),
        'plan':      'free',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
      });
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _errorMsg(e.code));
    } catch (_) {
      return AuthResult(success: false, message: 'Error inesperado. Intenta de nuevo.');
    }
  }

  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email:    email.trim().toLowerCase(),
        password: password,
      );
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _errorMsg(e.code));
    } catch (_) {
      return AuthResult(success: false, message: 'Error inesperado. Intenta de nuevo.');
    }
  }

  static Future<void> logout() async => _auth.signOut();

  static Future<AuthResult> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return AuthResult(
        success: true,
        message: 'Si el correo está registrado, recibirás un enlace de recuperación.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _errorMsg(e.code));
    } catch (_) {
      return AuthResult(success: false, message: 'Error de conexión.');
    }
  }

  static Future<UserModel?> getUserData() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return null;
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  static String _errorMsg(String code) {
    switch (code) {
      case 'email-already-in-use':   return 'Este correo ya está registrado.';
      case 'invalid-email':          return 'Correo electrónico no válido.';
      case 'weak-password':          return 'Contraseña muy débil. Usa mínimo 6 caracteres.';
      case 'user-not-found':         return 'No existe una cuenta con ese correo.';
      case 'wrong-password':         return 'Contraseña incorrecta.';
      case 'invalid-credential':     return 'Correo o contraseña incorrectos.';
      case 'too-many-requests':      return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed': return 'Sin conexión a internet.';
      case 'user-disabled':          return 'Esta cuenta fue deshabilitada.';
      default:                       return 'Error de autenticación. Intenta de nuevo.';
    }
  }
}

class ContentService {
  static final _db = FirebaseFirestore.instance;

  static void clearCache() {}

  static Future<List<ContentModel>> getAllContent() async {
    try {
      final snapshot = await _db.collection('content').get();
      return snapshot.docs.map((doc) => ContentModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getAllContent: $e');
      return [];
    }
  }

  static Future<List<ContentModel>> getTrending() async {
    try {
      final snapshot = await _db
          .collection('content')
          .where('isTrending', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => ContentModel.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Trae contenido próximo usando DOS estrategias en paralelo:
  /// 1. Campo booleano isUpcoming == true  (recomendado para nuevas películas)
  /// 2. Fallback: genre contiene "proximo" o "upcoming" (sin importar tildes)
  /// Así funciona sin importar cómo hayas subido la película a Firestore.
  static Future<List<ContentModel>> getUpcoming() async {
    try {
      // Estrategia 1: campo booleano
      final snap1 = await _db
          .collection('content')
          .where('isUpcoming', isEqualTo: true)
          .get();

      // Estrategia 2: todo el contenido, filtrado por genre en cliente
      // (cubre casos donde isUpcoming no está seteado pero el genre indica "próximo")
      final snap2 = await _db.collection('content').get();

      final Map<String, ContentModel> seen = {};

      for (final doc in snap1.docs) {
        final m = ContentModel.fromFirestore(doc);
        seen[m.id] = m;
      }

      for (final doc in snap2.docs) {
        if (seen.containsKey(doc.id)) continue;
        final m = ContentModel.fromFirestore(doc);
        if (m.isUpcoming) seen[m.id] = m; // isUpcoming ya evalúa el genre también
      }

      final result = seen.values.toList();
      debugPrint('getUpcoming → ${result.length} items encontrados');
      for (final c in result) {
        debugPrint('  • ${c.title} | isUpcoming=${c.isUpcoming} | genre="${c.genre}"');
      }
      return result;
    } catch (e) {
      debugPrint('Error getUpcoming: $e');
      return [];
    }
  }

  static Future<List<ContentModel>> getMovies() async {
    try {
      final snapshot = await _db
          .collection('content')
          .where('type', isEqualTo: 'Película')
          .get();
      return snapshot.docs.map((doc) => ContentModel.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ContentModel>> getSeries() async {
    try {
      final snapshot = await _db
          .collection('content')
          .where('type', isEqualTo: 'Serie')
          .get();
      return snapshot.docs.map((doc) => ContentModel.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ContentModel>> search(String query) async {
    try {
      final snapshot = await _db.collection('content').get();
      final q = query.toLowerCase();
      return snapshot.docs
          .map((doc) => ContentModel.fromFirestore(doc))
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.genre.toLowerCase().contains(q))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ContentModel>> getEpisodes(String seriesId) async {
    try {
      final snapshot = await _db
          .collection('content')
          .doc(seriesId)
          .collection('episodes')
          .orderBy('episode')
          .get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return ContentModel(
          id:          doc.id,
          title:       (d['title']    ?? '').toString(),
          genre:       'Drama',
          year:        '2009',
          duration:    (d['duration'] ?? '42m').toString(),
          type:        'Serie',
          description: '',
          videoUrl:    (d['videoUrl'] ?? '').toString(),
          imagenUrl:   '',
          seriesId:    seriesId,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getEpisodes: $e');
      return [];
    }
  }
}

class SubscriptionService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> getUserPlan() async {
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return 'free';
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return 'free';
      final d         = doc.data() as Map<String, dynamic>;
      final plan      = (d['plan'] ?? 'free').toString();
      final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
      if (plan == 'premium' &&
          expiresAt != null &&
          expiresAt.isBefore(DateTime.now())) {
        await _db.collection('users').doc(uid).update({
          'plan':      'free',
          'expiresAt': null,
        });
        return 'free';
      }
      return plan;
    } catch (_) {
      return 'free';
    }
  }

  static Future<bool> activatePremium({int months = 1}) async {
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return false;
      final expiresAt = DateTime.now().add(Duration(days: 30 * months));
      await _db.collection('users').doc(uid).update({
        'plan':      'premium',
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancelPremium() async {
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return false;
      await _db.collection('users').doc(uid).update({
        'plan':      'free',
        'expiresAt': null,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}