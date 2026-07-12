// ══════════════════════════════════════════════════════════════
//  REEMPLAZA SOLO ESTE MÉTODO en tu HomeScreen (_HomeScreenState)
//  dentro de main.dart
//
//  Busca el método _loadContent() y reemplázalo con este.
// ══════════════════════════════════════════════════════════════

  Future<void> _loadContent() async {
    try {
      // Carga en paralelo para mayor velocidad
      final results = await Future.wait([
        ContentService.getAllContent(),
        ContentService.getTrending(),
        ContentService.getUpcoming(),
      ]);

      final all      = results[0];
      final trending = results[1];
      final upcoming = results[2];

      debugPrint('📦 Total: ${all.length} | Trending: ${trending.length} | Upcoming: ${upcoming.length}');

      if (!mounted) return;

      final filtered = ProfileManager.filterForProfile(all);

      setState(() {
        _allContent     = filtered;
        _trending       = trending.isNotEmpty
            ? ProfileManager.filterForProfile(trending)
            : filtered.take(6).toList();
        _upcoming       = upcoming;
        _loadingContent = false;
      });

    } catch (e) {
      // ✅ FIX: antes si fallaba, el skeleton quedaba infinito.
      // Ahora siempre termina de cargar aunque haya error.
      debugPrint('❌ _loadContent error: $e');
      if (mounted) setState(() => _loadingContent = false);
    }
  }