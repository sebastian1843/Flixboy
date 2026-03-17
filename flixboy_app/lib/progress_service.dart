// lib/progress_service.dart
//
// Guarda y recupera el progreso de reproducción por usuario y perfil.
// Estructura en Firestore:
//
//   users/{uid}/progress/{contentId}
//   {
//     contentId:   "abc123",
//     title:       "Oppenheimer",
//     imagenUrl:   "https://...",
//     type:        "Película",
//     genre:       "Drama",
//     videoUrl:    "https://...",
//     position:    3420,        ← segundos
//     duration:    7260,        ← segundos totales
//     percent:     0.47,        ← 0.0 a 1.0
//     seasonNum:   null,        ← solo para series
//     episodeNum:  null,
//     episodeTitle: null,
//     updatedAt:   Timestamp
//   }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class ProgressEntry {
  final String  contentId;
  final String  title;
  final String  imagenUrl;
  final String  type;
  final String  genre;
  final String  videoUrl;
  final int     position;   // segundos
  final int     duration;   // segundos
  final double  percent;    // 0.0 – 1.0
  final int?    seasonNum;
  final int?    episodeNum;
  final String? episodeTitle;
  final DateTime updatedAt;

  ProgressEntry({
    required this.contentId,
    required this.title,
    required this.imagenUrl,
    required this.type,
    required this.genre,
    required this.videoUrl,
    required this.position,
    required this.duration,
    required this.percent,
    this.seasonNum,
    this.episodeNum,
    this.episodeTitle,
    required this.updatedAt,
  });

  bool get isFinished => percent >= 0.95;
  bool get isStarted  => percent > 0.02;

  /// Texto para mostrar debajo del título: "T1 E3 · 45%" o "47%"
  String get progressLabel {
    final pct = '${(percent * 100).round()}%';
    if (seasonNum != null && episodeNum != null) {
      return 'T$seasonNum E$episodeNum · $pct';
    }
    return pct;
  }

  factory ProgressEntry.fromFirestore(Map<String, dynamic> d) => ProgressEntry(
    contentId:    d['contentId']    ?? '',
    title:        d['title']        ?? '',
    imagenUrl:    d['imagenUrl']    ?? '',
    type:         d['type']         ?? '',
    genre:        d['genre']        ?? '',
    videoUrl:     d['videoUrl']     ?? '',
    position:     (d['position']    ?? 0) as int,
    duration:     (d['duration']    ?? 0) as int,
    percent:      (d['percent']     ?? 0.0).toDouble(),
    seasonNum:    d['seasonNum']    as int?,
    episodeNum:   d['episodeNum']   as int?,
    episodeTitle: d['episodeTitle'] as String?,
    updatedAt:    (d['updatedAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'contentId':    contentId,
    'title':        title,
    'imagenUrl':    imagenUrl,
    'type':         type,
    'genre':        genre,
    'videoUrl':     videoUrl,
    'position':     position,
    'duration':     duration,
    'percent':      percent,
    'seasonNum':    seasonNum,
    'episodeNum':   episodeNum,
    'episodeTitle': episodeTitle,
    'updatedAt':    FieldValue.serverTimestamp(),
  };
}

class ProgressService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('progress');
  }

  // ── Guardar / actualizar progreso ────────────────────────

  static Future<void> save({
    required ContentModel content,
    required Duration position,
    required Duration duration,
    int? seasonNum,
    int? episodeNum,
    String? episodeTitle,
  }) async {
    final col = _col();
    if (col == null) return;
    if (duration.inSeconds == 0) return;

    final percent = position.inSeconds / duration.inSeconds;

    // Si terminó (>95%) eliminar para no mostrar en "Continuar viendo"
    if (percent >= 0.95) {
      await col.doc(content.id).delete();
      return;
    }

    await col.doc(content.id).set({
      'contentId':    content.id,
      'title':        content.title,
      'imagenUrl':    content.imagenUrl,
      'type':         content.type,
      'genre':        content.genre,
      'videoUrl':     content.videoUrl,
      'position':     position.inSeconds,
      'duration':     duration.inSeconds,
      'percent':      percent,
      'seasonNum':    seasonNum,
      'episodeNum':   episodeNum,
      'episodeTitle': episodeTitle,
      'updatedAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Obtener progreso de un contenido ─────────────────────

  static Future<ProgressEntry?> get(String contentId) async {
    final col = _col();
    if (col == null) return null;
    try {
      final doc = await col.doc(contentId).get();
      if (!doc.exists) return null;
      return ProgressEntry.fromFirestore(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ── Obtener todos (para "Continuar viendo") ───────────────

  static Future<List<ProgressEntry>> getAll() async {
    final col = _col();
    if (col == null) return [];
    try {
      final snap = await col
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
      return snap.docs
          .map((d) => ProgressEntry.fromFirestore(d.data()))
          .where((e) => e.isStarted && !e.isFinished)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Eliminar progreso (al terminar o manualmente) ─────────

  static Future<void> delete(String contentId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(contentId).delete();
  }

  // ── Stream en tiempo real (opcional) ─────────────────────

  static Stream<List<ProgressEntry>> stream() {
    final col = _col();
    if (col == null) return const Stream.empty();
    return col
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProgressEntry.fromFirestore(d.data()))
            .where((e) => e.isStarted && !e.isFinished)
            .toList());
  }
}