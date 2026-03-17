// lib/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
//  MODELO DE CONTENIDO
//  Estructura esperada en Firestore colección 'content':
//
//  {
//    title:       "Oppenheimer",
//    genre:       "Drama",           // Acción|Drama|Comedia|Terror|Aventura|Sci-Fi|Fantasía|Animación
//    year:        "2023",
//    duration:    "3h 1m",
//    type:        "Película",        // "Película" o "Serie"  ← con tilde
//    description: "La historia...",
//    videoUrl:    "https://s3.amazonaws.com/tu-bucket/videos/oppenheimer.mp4",
//    imagenUrl:   "https://res.cloudinary.com/.../oppenheimer.jpg",
//    trailerUrl:  "https://s3.amazonaws.com/tu-bucket/trailers/oppenheimer_trailer.mp4",
//    isPremium:   false,
//    isTrending:  true,
//    isUpcoming:  false,
//    createdAt:   Timestamp
//  }
// ============================================================

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
    this.isPremium  = false,
    this.isTrending = false,
    this.isUpcoming = false,
  });

  // FIX: parseBool acepta bool, String, int
  static bool _parseBool(dynamic v) {
    if (v is bool)   return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is int)    return v == 1;
    return false;
  }

  factory ContentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
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
      isUpcoming:  _parseBool(d['isUpcoming']),
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
  };

  // Compara tipo ignorando tildes y mayúsculas
  bool get isPelicula => type.toLowerCase().contains('pel');
  bool get isSerie    => type.toLowerCase().contains('serie') || type.toLowerCase() == 's';
}

// ============================================================
//  MODELO DE USUARIO
// ============================================================

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

// ============================================================
//  AUTH SERVICE
// ============================================================

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

  // ── Registro ──────────────────────────────────────────────

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
      // Crear documento de usuario en Firestore
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

  // ── Login ─────────────────────────────────────────────────

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

  // ── Logout ────────────────────────────────────────────────

  static Future<void> logout() async => _auth.signOut();

  // ── Recuperar contraseña ──────────────────────────────────

  static Future<AuthResult> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      // Respuesta genérica — no revelar si el email existe
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

  // ── Datos del usuario ─────────────────────────────────────

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

  // ── Mensajes de error amigables ───────────────────────────

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

// ============================================================
//  CONTENT SERVICE
//  Colección en Firestore: 'content'
// ============================================================

class ContentService {
  static final _db = FirebaseFirestore.instance;

  // Cache en memoria para evitar lecturas repetidas a Firestore
  static List<ContentModel>? _cache;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  static bool get _cacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;

  static void clearCache() { _cache = null; _cacheTime = null; }

  // ── Obtener todo el contenido ─────────────────────────────

  static Future<List<ContentModel>> getAllContent() async {
    if (_cacheValid) return _cache!;
    try {
      final snap = await _db
          .collection('content')
          .orderBy('createdAt', descending: true)
          .get();
      _cache     = snap.docs.map((d) => ContentModel.fromFirestore(d)).toList();
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (_) {
      return _cache ?? [];
    }
  }

  // ── Trending ──────────────────────────────────────────────

  static Future<List<ContentModel>> getTrending() async {
    try {
      final snap = await _db
          .collection('content')
          .where('isTrending', isEqualTo: true)
          .limit(10)
          .get();
      return snap.docs.map((d) => ContentModel.fromFirestore(d)).toList();
    } catch (_) {
      // Fallback: primeros 6 del cache
      final all = await getAllContent();
      return all.take(6).toList();
    }
  }

  // ── Próximos estrenos ─────────────────────────────────────
  // FIX: isUpcoming se guarda como bool en Firestore, no como String

  static Future<List<ContentModel>> getUpcoming() async {
    try {
      final snap = await _db
          .collection('content')
          .where('isUpcoming', isEqualTo: true)  // ← FIX: bool, no String
          .get();
      return snap.docs.map((d) => ContentModel.fromFirestore(d)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Películas ─────────────────────────────────────────────

  static Future<List<ContentModel>> getMovies() async {
    try {
      final all = await getAllContent();
      // FIX: usa isPelicula que normaliza con y sin tilde
      return all.where((c) => c.isPelicula && !c.isUpcoming).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Series ────────────────────────────────────────────────

  static Future<List<ContentModel>> getSeries() async {
    try {
      final all = await getAllContent();
      // FIX: usa isSerie que normaliza variantes
      return all.where((c) => c.isSerie && !c.isUpcoming).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Búsqueda ──────────────────────────────────────────────

  static Future<List<ContentModel>> search(String query) async {
    try {
      final all = await getAllContent();
      final q   = query.toLowerCase().trim();
      if (q.isEmpty) return [];
      return all.where((c) =>
          c.title.toLowerCase().contains(q) ||
          c.genre.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.type.toLowerCase().contains(q)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Agregar contenido (desde admin) ──────────────────────

  static Future<bool> addContent(Map<String, dynamic> data) async {
    try {
      await _db.collection('content').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      clearCache(); // invalidar cache
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Actualizar contenido ──────────────────────────────────

  static Future<bool> updateContent(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection('content').doc(id).update(data);
      clearCache();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Eliminar contenido ────────────────────────────────────

  static Future<bool> deleteContent(String id) async {
    try {
      await _db.collection('content').doc(id).delete();
      clearCache();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
//  SUBSCRIPTION SERVICE
// ============================================================

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
      // Verificar si el plan premium expiró
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