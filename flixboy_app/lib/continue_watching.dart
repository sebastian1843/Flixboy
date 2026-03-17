// lib/continue_watching.dart
//
// Dos widgets para la Fase 2:
//
//   1. ContinueWatchingSection — fila horizontal de "Continuar viendo"
//      para insertar en HomeScreen encima de las demás secciones.
//
//   2. EpisodeSelector — pantalla de selección de temporada/episodio
//      para series, con progreso visual por episodio.

import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'progress_service.dart';
import 'video_player_screen.dart';
import 'main.dart'; // cloudinaryOptimized, genreColor

// ══════════════════════════════════════════════════════════════
//  1. ContinueWatchingSection
// ══════════════════════════════════════════════════════════════

class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({super.key});

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  List<ProgressEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ProgressService.getAll();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_entries.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
        child: Row(children: [
          const Text('Continuar viendo',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFFE50914), shape: BoxShape.circle),
          ),
        ]),
      ),
      SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _entries.length,
          itemBuilder: (_, i) => _ContinueCard(
            entry: _entries[i],
            onRemove: () async {
              await ProgressService.delete(_entries[i].contentId);
              setState(() => _entries.removeAt(i));
            },
            onPlay: _load, // refresca al volver
          ),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _ContinueCard extends StatelessWidget {
  final ProgressEntry entry;
  final VoidCallback  onRemove;
  final VoidCallback  onPlay;

  const _ContinueCard({
    required this.entry,
    required this.onRemove,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = entry.imagenUrl.isNotEmpty
        ? cloudinaryOptimized(entry.imagenUrl, w: 120, h: 160)
        : '';

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          final content = ContentModel(
            id:          entry.contentId,
            title:       entry.title,
            genre:       entry.genre,
            year:        '',
            duration:    '',
            type:        entry.type,
            description: '',
            videoUrl:    entry.videoUrl,
            imagenUrl:   entry.imagenUrl,
          );
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              videoUrl:     entry.videoUrl,
              title:        entry.title,
              content:      content,
              seasonNum:    entry.seasonNum,
              episodeNum:   entry.episodeNum,
              episodeTitle: entry.episodeTitle,
            ),
          )).then((_) => onPlay());
        },
        onLongPress: () => _showRemoveDialog(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            // Póster
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imgUrl.isNotEmpty
                  ? Image.network(imgUrl,
                      width: 120, height: 160, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            // Overlay oscuro
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  )),
            ),
            // Botón play centrado
            const Center(child: Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 36)),
            // Barra de progreso abajo
            Positioned(bottom: 0, left: 0, right: 0,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Text(entry.progressLabel,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  child: LinearProgressIndicator(
                    value:            entry.percent,
                    backgroundColor:  Colors.white24,
                    color:            const Color(0xFFE50914),
                    minHeight:        3,
                  ),
                ),
              ]),
            ),
          ])),
          const SizedBox(height: 6),
          Text(entry.title,
              style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: genreColor(entry.genre), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(entry.genre,
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 120, height: 160,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          genreColor(entry.genre).withValues(alpha: 0.8),
          const Color(0xFF111111),
        ],
      ),
    ),
    child: Icon(
      entry.type.toLowerCase().contains('serie')
          ? Icons.tv_rounded : Icons.movie_rounded,
      size: 32, color: Colors.white.withValues(alpha: 0.2),
    ),
  );

  void _showRemoveDialog(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Quitar de continuar viendo',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Text('¿Quitar "${entry.title}"?',
          style: const TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white),
          onPressed: () { Navigator.pop(context); onRemove(); },
          child: const Text('Quitar'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  2. EpisodeSelector
//  Pantalla completa para elegir temporada y episodio de una serie.
//  Uso:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => EpisodeSelector(series: content, seasons: seasons)));
// ══════════════════════════════════════════════════════════════

class SeasonModel {
  final int    number;
  final String title;
  final List<EpisodeModel> episodes;
  SeasonModel({required this.number, required this.title, required this.episodes});
}

class EpisodeModel {
  final int    number;
  final String title;
  final String description;
  final String videoUrl;
  final String imagenUrl;
  final String duration;
  EpisodeModel({
    required this.number,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.imagenUrl,
    required this.duration,
  });
}

class EpisodeSelector extends StatefulWidget {
  final ContentModel        series;
  final List<SeasonModel>   seasons;

  const EpisodeSelector({
    super.key,
    required this.series,
    required this.seasons,
  });

  @override
  State<EpisodeSelector> createState() => _EpisodeSelectorState();
}

class _EpisodeSelectorState extends State<EpisodeSelector> {
  int _selectedSeason = 0;
  Map<String, ProgressEntry> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final all = await ProgressService.getAll();
    final map = <String, ProgressEntry>{};
    for (final e in all) {
      if (e.contentId == widget.series.id &&
          e.seasonNum != null && e.episodeNum != null) {
        map['${e.seasonNum}_${e.episodeNum}'] = e;
      }
    }
    if (mounted) setState(() => _progress = map);
  }

  SeasonModel get _season => widget.seasons[_selectedSeason];

  void _playEpisode(EpisodeModel ep) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        videoUrl:     ep.videoUrl,
        title:        widget.series.title,
        content:      widget.series,
        seasonNum:    _season.number,
        episodeNum:   ep.number,
        episodeTitle: ep.title,
      ),
    )).then((_) => _loadProgress());
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
      title: Text(widget.series.title,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [
      // ── Selector de temporadas ──
      if (widget.seasons.length > 1)
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.seasons.length,
            itemBuilder: (_, i) {
              final sel = i == _selectedSeason;
              return GestureDetector(
                onTap: () => setState(() => _selectedSeason = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFE50914)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.seasons[i].title,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.grey,
                      fontWeight: sel
                          ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

      const SizedBox(height: 12),

      // ── Lista de episodios ──
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _season.episodes.length,
        itemBuilder: (_, i) {
          final ep  = _season.episodes[i];
          final key = '${_season.number}_${ep.number}';
          final prog = _progress[key];

          return GestureDetector(
            onTap: () => _playEpisode(ep),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  // Thumbnail del episodio
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft:    const Radius.circular(12),
                      bottomLeft: Radius.circular(prog != null ? 0 : 12),
                    ),
                    child: Stack(children: [
                      ep.imagenUrl.isNotEmpty
                          ? Image.network(
                              cloudinaryOptimized(ep.imagenUrl, w:120, h:70),
                              width: 120, height: 70, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _epPlaceholder(120, 70))
                          : _epPlaceholder(120, 70),
                      // Ícono play
                      Positioned.fill(child: Center(
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 20),
                        ),
                      )),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${ep.number}. ${ep.title}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(ep.description,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(ep.duration,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 11)),
                        if (prog != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(prog.progressLabel,
                                style: const TextStyle(
                                    color: Color(0xFFE50914), fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                    ]),
                  )),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  const SizedBox(width: 8),
                ]),
                // Barra de progreso si existe
                if (prog != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft:  Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value:           prog.percent,
                      backgroundColor: Colors.white12,
                      color:           const Color(0xFFE50914),
                      minHeight:       3,
                    ),
                  ),
              ]),
            ),
          );
        },
      )),
    ]),
  );

  Widget _epPlaceholder(double w, double h) => Container(
    width: w, height: h,
    color: const Color(0xFF2A2A2A),
    child: const Icon(Icons.tv_rounded,
        size: 24, color: Colors.white24),
  );
}