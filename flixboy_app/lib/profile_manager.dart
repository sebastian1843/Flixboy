// lib/profile_manager.dart
//
// Gestión completa de perfiles con:
//   • Historial de visualización separado por perfil
//   • Modo niños (filtra contenido por categorías permitidas)
//   • Perfil activo global (accesible desde cualquier pantalla)
//   • Persistencia en Firestore y SharedPreferences

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

// ══════════════════════════════════════════════════════════════
//  MODELO DE PERFIL EXTENDIDO
// ══════════════════════════════════════════════════════════════

class ProfileData {
  final String  id;
  String        name;
  String        image;
  String?       pin;
  bool          isOwner;
  bool          isKidsMode;
  List<String>  kidsAllowedGenres;
  DateTime?     createdAt;

  ProfileData({
    required this.id,
    required this.name,
    required this.image,
    this.pin,
    this.isOwner        = false,
    this.isKidsMode     = false,
    this.kidsAllowedGenres = const ['Animación', 'Aventura', 'Comedia'],
    this.createdAt,
  });

  factory ProfileData.fromMap(Map<String, dynamic> d) => ProfileData(
    id:                 d['id']          ?? '',
    name:               d['name']        ?? 'Perfil',
    image:              d['image']       ?? 'assets/images/profile1.jpg',
    pin:                d['pin']         as String?,
    isOwner:            d['isOwner']     as bool? ?? false,
    isKidsMode:         d['isKidsMode']  as bool? ?? false,
    kidsAllowedGenres: List<String>.from(
        d['kidsAllowedGenres'] ?? ['Animación', 'Aventura', 'Comedia']),
    createdAt: d['createdAt'] != null
        ? (d['createdAt'] as dynamic).toDate()
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id':                id,
    'name':              name,
    'image':             image,
    'pin':               pin,
    'isOwner':           isOwner,
    'isKidsMode':        isKidsMode,
    'kidsAllowedGenres': kidsAllowedGenres,
  };

  // Géneros permitidos en modo niños
  static const List<String> defaultKidsGenres = [
    'Animación', 'Aventura', 'Comedia',
  ];

  static const List<String> allGenres = [
    'Animación', 'Aventura', 'Comedia', 'Acción',
    'Drama', 'Terror', 'Sci-Fi', 'Fantasía',
  ];
}

// ══════════════════════════════════════════════════════════════
//  HISTORIAL DE VISUALIZACIÓN
// ══════════════════════════════════════════════════════════════

class HistoryEntry {
  final String contentId;
  final String title;
  final String imagenUrl;
  final String genre;
  final String type;
  final String videoUrl;
  final DateTime watchedAt;

  HistoryEntry({
    required this.contentId,
    required this.title,
    required this.imagenUrl,
    required this.genre,
    required this.type,
    required this.videoUrl,
    required this.watchedAt,
  });

  factory HistoryEntry.fromFirestore(Map<String, dynamic> d) => HistoryEntry(
    contentId: d['contentId'] ?? '',
    title:     d['title']     ?? '',
    imagenUrl: d['imagenUrl'] ?? '',
    genre:     d['genre']     ?? '',
    type:      d['type']      ?? '',
    videoUrl:  d['videoUrl']  ?? '',
    watchedAt: (d['watchedAt'] as dynamic?)?.toDate() ?? DateTime.now(),
  );
}

// ══════════════════════════════════════════════════════════════
//  PROFILE MANAGER — singleton global
// ══════════════════════════════════════════════════════════════

class ProfileManager {
  static final _db = FirebaseFirestore.instance;

  // Perfil activo en memoria
  static ProfileData? _activeProfile;
  static ProfileData? get activeProfile => _activeProfile;
  static bool get isKidsMode => _activeProfile?.isKidsMode ?? false;

  // ── Activar perfil ────────────────────────────────────────

  static Future<void> setActiveProfile(ProfileData profile) async {
    _activeProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_profile_id', profile.id);
  }

  static Future<void> clearActiveProfile() async {
    _activeProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_profile_id');
  }

  // ── Filtrar contenido por modo niños ─────────────────────

  static List<ContentModel> filterForProfile(List<ContentModel> all) {
    if (_activeProfile == null || !_activeProfile!.isKidsMode) return all;
    final allowed = _activeProfile!.kidsAllowedGenres;
    return all.where((c) => allowed.contains(c.genre)).toList();
  }

  // ── Historial por perfil ──────────────────────────────────

  static CollectionReference<Map<String, dynamic>>? _historyCol() {
    final uid = AuthService.currentUser?.uid;
    final pid = _activeProfile?.id;
    if (uid == null || pid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .doc(pid)
        .collection('history');
  }

  static Future<void> addToHistory(ContentModel content) async {
    final col = _historyCol();
    if (col == null) return;
    await col.doc(content.id).set({
      'contentId': content.id,
      'title':     content.title,
      'imagenUrl': content.imagenUrl,
      'genre':     content.genre,
      'type':      content.type,
      'videoUrl':  content.videoUrl,
      'watchedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<HistoryEntry>> getHistory({int limit = 30}) async {
    final col = _historyCol();
    if (col == null) return [];
    try {
      final snap = await col
          .orderBy('watchedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => HistoryEntry.fromFirestore(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removeFromHistory(String contentId) async {
    final col = _historyCol();
    if (col == null) return;
    await col.doc(contentId).delete();
  }

  static Future<void> clearHistory() async {
    final col = _historyCol();
    if (col == null) return;
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // ── Guardar perfiles en Firestore ─────────────────────────

  static Future<void> saveProfiles(List<ProfileData> profiles) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'profiles': profiles.map((p) => p.toMap()).toList(),
    });
  }

  static Future<List<ProfileData>> loadProfiles() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return [];
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return [];
      final list = data['profiles'] as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((p) => ProfileData.fromMap(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA DE HISTORIAL
// ══════════════════════════════════════════════════════════════

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await ProfileManager.getHistory();
    if (mounted) setState(() { _history = h; _loading = false; });
  }

  String _formatDate(DateTime d) {
    final now  = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60)  return 'Hace ${diff.inMinutes} min';
    if (diff.inHours   < 24)  return 'Hace ${diff.inHours} h';
    if (diff.inDays    == 1)  return 'Ayer';
    if (diff.inDays    < 7)   return 'Hace ${diff.inDays} días';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Historial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        if (_history.isNotEmpty)
          TextButton(
            onPressed: () => _confirmClear(),
            child: const Text('Limpiar',
                style: TextStyle(color: Color(0xFFE50914))),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(
            color: Color(0xFFE50914)))
        : _history.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 72,
                      color: Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('Sin historial',
                      style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Las películas y series que veas\naparecerán aquí',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center),
                ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final item = _history[i];
                  return Dismissible(
                    key: Key(item.contentId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 26),
                    ),
                    onDismissed: (_) async {
                      await ProfileManager.removeFromHistory(item.contentId);
                      setState(() => _history.removeAt(i));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft:    Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          child: item.imagenUrl.isNotEmpty
                              ? Image.network(item.imagenUrl,
                                  width: 80, height: 80, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(item))
                              : _placeholder(item),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(item.type,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(_formatDate(item.watchedAt),
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 11)),
                            ],
                          ),
                        )),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  );
                },
              ),
  );

  Widget _placeholder(HistoryEntry item) => Container(
    width: 80, height: 80,
    color: const Color(0xFF2A2A2A),
    child: Icon(
      item.type.toLowerCase().contains('serie')
          ? Icons.tv_rounded : Icons.movie_rounded,
      color: Colors.white24, size: 28,
    ),
  );

  void _confirmClear() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Limpiar historial',
          style: TextStyle(color: Colors.white)),
      content: const Text('¿Eliminar todo el historial de este perfil?',
          style: TextStyle(color: Colors.grey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white),
          onPressed: () async {
            await ProfileManager.clearHistory();
            Navigator.pop(context);
            setState(() => _history.clear());
          },
          child: const Text('Limpiar todo'),
        ),
      ],
    ),
  );
}