// ══════════════════════════════════════════════════════════════
//  FLIXBOY — SISTEMA RESPONSIVE COMPLETO
//  Soporta: TV (>1280px), Laptop (960-1280px),
//           Tablet (600-960px), Móvil (<600px)
//
//  INSTRUCCIONES DE USO:
//  1. Añade este archivo a tu proyecto: lib/responsive.dart
//  2. Envuelve tu MaterialApp con ResponsiveWrapper (opcional)
//  3. Usa FlixResponsive.of(context) en cualquier widget
//  4. Reemplaza los widgets indicados en main.dart y screens.dart
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════
//  1. BREAKPOINTS Y DEVICE TYPE
// ══════════════════════════════════════════════════════════════

enum DeviceType { mobile, tablet, laptop, tv }

class FlixResponsive {
  final double width;
  final double height;
  final DeviceType deviceType;
  final double pixelRatio;

  const FlixResponsive._({
    required this.width,
    required this.height,
    required this.deviceType,
    required this.pixelRatio,
  });

  factory FlixResponsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w  = mq.size.width;
    final h  = mq.size.height;
    final pr = mq.devicePixelRatio;

    DeviceType type;
    if (w >= 1280) {
      type = DeviceType.tv;
    } else if (w >= 960) {
      type = DeviceType.laptop;
    } else if (w >= 600) {
      type = DeviceType.tablet;
    } else {
      type = DeviceType.mobile;
    }

    return FlixResponsive._(
      width: w, height: h, deviceType: type, pixelRatio: pr,
    );
  }

  bool get isMobile  => deviceType == DeviceType.mobile;
  bool get isTablet  => deviceType == DeviceType.tablet;
  bool get isLaptop  => deviceType == DeviceType.laptop;
  bool get isTV      => deviceType == DeviceType.tv;
  bool get isDesktop => isLaptop || isTV;
  bool get isLarge   => isTablet || isLaptop || isTV;

  // ── Columnas para grids ──────────────────────────────────────
  int get gridColumns {
    switch (deviceType) {
      case DeviceType.tv:     return 6;
      case DeviceType.laptop: return 5;
      case DeviceType.tablet: return 3;
      case DeviceType.mobile: return 3;
    }
  }

  int get profileGridColumns {
    switch (deviceType) {
      case DeviceType.tv:     return 5;
      case DeviceType.laptop: return 5;
      case DeviceType.tablet: return 4;
      case DeviceType.mobile: return 2;
    }
  }

  // ── Tamaño de tarjetas de contenido ─────────────────────────
  double get cardWidth {
    switch (deviceType) {
      case DeviceType.tv:     return 200;
      case DeviceType.laptop: return 170;
      case DeviceType.tablet: return 140;
      case DeviceType.mobile: return 120;
    }
  }

  double get cardHeight {
    switch (deviceType) {
      case DeviceType.tv:     return 290;
      case DeviceType.laptop: return 250;
      case DeviceType.tablet: return 200;
      case DeviceType.mobile: return 170;
    }
  }

  double get top10CardWidth {
    switch (deviceType) {
      case DeviceType.tv:     return 230;
      case DeviceType.laptop: return 190;
      case DeviceType.tablet: return 160;
      case DeviceType.mobile: return 140;
    }
  }

  // ── Padding general de la app ────────────────────────────────
  EdgeInsets get screenPadding {
    switch (deviceType) {
      case DeviceType.tv:     return const EdgeInsets.symmetric(horizontal: 64, vertical: 24);
      case DeviceType.laptop: return const EdgeInsets.symmetric(horizontal: 40, vertical: 20);
      case DeviceType.tablet: return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case DeviceType.mobile: return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.tv:     return 64;
      case DeviceType.laptop: return 40;
      case DeviceType.tablet: return 24;
      case DeviceType.mobile: return 16;
    }
  }

  // ── Tipografía escalada ──────────────────────────────────────
  double get titleFontSize {
    switch (deviceType) {
      case DeviceType.tv:     return 52;
      case DeviceType.laptop: return 42;
      case DeviceType.tablet: return 34;
      case DeviceType.mobile: return 28;
    }
  }

  double get sectionTitleSize {
    switch (deviceType) {
      case DeviceType.tv:     return 28;
      case DeviceType.laptop: return 22;
      case DeviceType.tablet: return 20;
      case DeviceType.mobile: return 18;
    }
  }

  double get bodyFontSize {
    switch (deviceType) {
      case DeviceType.tv:     return 18;
      case DeviceType.laptop: return 15;
      case DeviceType.tablet: return 14;
      case DeviceType.mobile: return 13;
    }
  }

  double get captionFontSize {
    switch (deviceType) {
      case DeviceType.tv:     return 15;
      case DeviceType.laptop: return 13;
      case DeviceType.tablet: return 12;
      case DeviceType.mobile: return 11;
    }
  }

  // ── Logo y branding ──────────────────────────────────────────
  double get logoFontSize {
    switch (deviceType) {
      case DeviceType.tv:     return 36;
      case DeviceType.laptop: return 28;
      case DeviceType.tablet: return 22;
      case DeviceType.mobile: return 16;
    }
  }

  // ── AppBar ───────────────────────────────────────────────────
  double get appBarHeight {
    switch (deviceType) {
      case DeviceType.tv:     return 80;
      case DeviceType.laptop: return 70;
      case DeviceType.tablet: return 64;
      case DeviceType.mobile: return 60;
    }
  }

  // ── Hero banner ──────────────────────────────────────────────
  double get heroBannerHeight {
    switch (deviceType) {
      case DeviceType.tv:     return height * 0.70;
      case DeviceType.laptop: return height * 0.65;
      case DeviceType.tablet: return height * 0.55;
      case DeviceType.mobile: return height * 0.60;
    }
  }

  // ── Sidebar (TV/Laptop siempre visible, Tablet/Móvil overlay) ─
  bool get hasPersistentSidebar => isLaptop || isTV;
  double get sidebarWidth {
    switch (deviceType) {
      case DeviceType.tv:     return 280;
      case DeviceType.laptop: return 240;
      default:                return 220;
    }
  }

  // ── Perfil avatar ────────────────────────────────────────────
  double get profileAvatarSize {
    switch (deviceType) {
      case DeviceType.tv:     return 140;
      case DeviceType.laptop: return 110;
      case DeviceType.tablet: return 90;
      case DeviceType.mobile: return 90;
    }
  }

  // ── Botones ──────────────────────────────────────────────────
  double get buttonHeight {
    switch (deviceType) {
      case DeviceType.tv:     return 64;
      case DeviceType.laptop: return 56;
      case DeviceType.tablet: return 52;
      case DeviceType.mobile: return 52;
    }
  }

  double get buttonFontSize {
    switch (deviceType) {
      case DeviceType.tv:     return 20;
      case DeviceType.laptop: return 17;
      case DeviceType.tablet: return 16;
      case DeviceType.mobile: return 16;
    }
  }

  // ── Iconos ───────────────────────────────────────────────────
  double get iconSize {
    switch (deviceType) {
      case DeviceType.tv:     return 32;
      case DeviceType.laptop: return 26;
      case DeviceType.tablet: return 24;
      case DeviceType.mobile: return 22;
    }
  }

  // ── Scroll horizontal row height ─────────────────────────────
  double get rowHeight {
    switch (deviceType) {
      case DeviceType.tv:     return 310;
      case DeviceType.laptop: return 260;
      case DeviceType.tablet: return 215;
      case DeviceType.mobile: return 185;
    }
  }

  double get top10RowHeight {
    switch (deviceType) {
      case DeviceType.tv:     return 260;
      case DeviceType.laptop: return 220;
      case DeviceType.tablet: return 210;
      case DeviceType.mobile: return 200;
    }
  }

  // ── Ancho máximo de contenido centrado (TV/Laptop) ───────────
  double? get maxContentWidth {
    switch (deviceType) {
      case DeviceType.tv:     return 1600;
      case DeviceType.laptop: return 1280;
      default:                return null;
    }
  }

  // ── Orientación preferida ────────────────────────────────────
  List<DeviceOrientation> get preferredOrientations {
    if (isDesktop || isTablet) {
      return [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
    return [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];
  }
}

// ══════════════════════════════════════════════════════════════
//  2. RESPONSIVE WRAPPER — Centra el contenido en pantallas grandes
// ══════════════════════════════════════════════════════════════

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  const ResponsiveCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);
    final maxW = r.maxContentWidth;
    if (maxW == null) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  3. RESPONSIVE SCAFFOLD — Sidebar persistente en TV/Laptop
// ══════════════════════════════════════════════════════════════

class FlixScaffold extends StatelessWidget {
  final Widget body;
  final Widget sidebar;
  final Widget? appBar;
  final bool sidebarVisible;

  const FlixScaffold({
    super.key,
    required this.body,
    required this.sidebar,
    this.appBar,
    this.sidebarVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    if (r.hasPersistentSidebar) {
      // TV / Laptop: sidebar siempre visible a la izquierda
      return Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: Row(
          children: [
            SizedBox(width: r.sidebarWidth, child: sidebar),
            Container(width: 1, color: const Color(0xFF1A1A1A)),
            Expanded(
              child: Column(
                children: [
                  if (appBar != null) appBar!,
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet / Móvil: sidebar como overlay
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          Column(
            children: [
              if (appBar != null) appBar!,
              Expanded(child: body),
            ],
          ),
          if (sidebarVisible) ...[
            GestureDetector(
              onTap: () {},
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: r.sidebarWidth,
              child: sidebar,
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  4. RESPONSIVE GRID — Para el contenido en pantallas grandes
// ══════════════════════════════════════════════════════════════

class FlixGrid extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const FlixGrid({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);
    return GridView.count(
      crossAxisCount: r.gridColumns,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio ?? 0.65,
      children: children,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  5. RESPONSIVE TEXT — Escala automática de tipografía
// ══════════════════════════════════════════════════════════════

class FlixText extends StatelessWidget {
  final String text;
  final _FlixTextStyle style;
  final Color? color;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const FlixText(
    this.text, {
    super.key,
    this.style = _FlixTextStyle.body,
    this.color,
    this.fontWeight,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  const FlixText.title(this.text, {super.key, this.color, this.fontWeight, this.maxLines, this.overflow, this.textAlign})
      : style = _FlixTextStyle.title;

  const FlixText.sectionTitle(this.text, {super.key, this.color, this.fontWeight, this.maxLines, this.overflow, this.textAlign})
      : style = _FlixTextStyle.sectionTitle;

  const FlixText.body(this.text, {super.key, this.color, this.fontWeight, this.maxLines, this.overflow, this.textAlign})
      : style = _FlixTextStyle.body;

  const FlixText.caption(this.text, {super.key, this.color, this.fontWeight, this.maxLines, this.overflow, this.textAlign})
      : style = _FlixTextStyle.caption;

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);
    double size;
    switch (style) {
      case _FlixTextStyle.title:       size = r.titleFontSize;       break;
      case _FlixTextStyle.sectionTitle: size = r.sectionTitleSize;   break;
      case _FlixTextStyle.body:        size = r.bodyFontSize;        break;
      case _FlixTextStyle.caption:     size = r.captionFontSize;     break;
    }

    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: size,
        color: color ?? Colors.white,
        fontWeight: fontWeight,
      ),
    );
  }
}

enum _FlixTextStyle { title, sectionTitle, body, caption }

// ══════════════════════════════════════════════════════════════
//  6. RESPONSIVE CARD ROW — Fila horizontal de tarjetas
// ══════════════════════════════════════════════════════════════

class FlixCardRow extends StatelessWidget {
  final List<Widget> children;
  final bool isTop10;

  const FlixCardRow({
    super.key,
    required this.children,
    this.isTop10 = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);
    final h = isTop10 ? r.top10RowHeight : r.rowHeight;

    return SizedBox(
      height: h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: r.horizontalPadding, top: 10),
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  7. RESPONSIVE CONTENT CARD — Tarjeta de película/serie
// ══════════════════════════════════════════════════════════════

class FlixContentCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String genre;
  final String type;
  final VoidCallback onTap;
  final bool isTop10;
  final int? rank;

  const FlixContentCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.genre,
    required this.type,
    required this.onTap,
    this.isTop10 = false,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);
    final w = isTop10 ? r.top10CardWidth : r.cardWidth;
    final h = r.cardHeight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.isTV ? 12 : 8),
                    child: _buildImage(w, h, r),
                  ),
                  if (isTop10 && rank != null) _buildRankOverlay(rank!, r),
                ],
              ),
            ),
            if (r.isLarge) ...[
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.captionFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(double w, double h, FlixResponsive r) {
    if (imageUrl.isEmpty) {
      return Container(
        width: w, height: h,
        color: const Color(0xFF1A1A1A),
        child: Icon(
          type == 'Serie' ? Icons.tv_rounded : Icons.movie_rounded,
          color: Colors.white24,
          size: r.iconSize * 1.5,
        ),
      );
    }
    // Usa tu FlixImage existente aquí con cloudinaryOptimized
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildRankOverlay(int rank, FlixResponsive r) {
    final fontSize = r.isTV ? 90.0 : r.isLaptop ? 72.0 : 72.0;
    return Positioned(
      bottom: 0, left: 0,
      child: Stack(
        children: [
          Text('$rank', style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white24,
          )),
          Text('$rank', style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w900,
            color: Colors.white,
          )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  8. RESPONSIVE LOGIN / REGISTER — Layout de 2 columnas en TV/Laptop
// ══════════════════════════════════════════════════════════════

class ResponsiveAuthLayout extends StatelessWidget {
  final Widget form;
  final String? backgroundUrl;

  const ResponsiveAuthLayout({
    super.key,
    required this.form,
    this.backgroundUrl,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    if (r.isDesktop) {
      // TV/Laptop: imagen a la derecha, formulario a la izquierda
      return Scaffold(
        body: Row(
          children: [
            // Panel del formulario
            SizedBox(
              width: r.isTV ? 520 : 440,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
                  ),
                ),
                child: SafeArea(child: SingleChildScrollView(child: form)),
              ),
            ),
            // Panel de imagen/branding
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backgroundUrl != null && backgroundUrl!.isNotEmpty)
                    Image.network(backgroundUrl!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [Color(0xFF3A0000), Color(0xFF0A0A0A)],
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF0A0A0A),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'FLIXBOY',
                          style: TextStyle(
                            fontSize: r.isTV ? 72 : 56,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFE50914),
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tu entretenimiento sin límites',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: r.bodyFontSize + 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet / Móvil: diseño original de pantalla completa
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundUrl != null && backgroundUrl!.isNotEmpty)
            Image.network(backgroundUrl!, fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x44000000), Color(0xCC000000)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: r.isTablet
                ? Center(
                    child: SizedBox(
                      width: 480, // Tablet: formulario centrado y acotado
                      child: SingleChildScrollView(child: form),
                    ),
                  )
                : SingleChildScrollView(child: form),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  9. RESPONSIVE PROFILE GRID
// ══════════════════════════════════════════════════════════════

class ResponsiveProfileGrid extends StatelessWidget {
  final List<Widget> children;

  const ResponsiveProfileGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    // TV/Laptop: grid horizontal centrado
    if (r.isDesktop) {
      return Center(
        child: Wrap(
          spacing: 32,
          runSpacing: 32,
          alignment: WrapAlignment.center,
          children: children,
        ),
      );
    }

    // Tablet/Móvil: grid de 2 columnas como antes
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.profileGridColumns,
        mainAxisSpacing: r.isTablet ? 32 : 24,
        crossAxisSpacing: r.isTablet ? 32 : 24,
        childAspectRatio: r.isTablet ? 0.80 : 0.85,
      ),
      padding: EdgeInsets.symmetric(
          horizontal: r.isTablet ? 60 : 40),
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  10. RESPONSIVE DETAIL SCREEN LAYOUT
// ══════════════════════════════════════════════════════════════

class ResponsiveDetailLayout extends StatelessWidget {
  final String imageUrl;
  final Widget infoPanel;

  const ResponsiveDetailLayout({
    super.key,
    required this.imageUrl,
    required this.infoPanel,
  });

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    if (r.isDesktop) {
      // TV/Laptop: imagen a la izquierda (40%), info a la derecha (60%)
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            SizedBox(
              width: r.width * 0.38,
              height: r.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(imageUrl, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF3A0000), Color(0xFF0A0A0A)],
                        ),
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFF0A0A0A), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Panel de info con scroll
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(r.horizontalPadding),
                child: infoPanel,
              ),
            ),
          ],
        ),
      );
    }

    if (r.isTablet) {
      // Tablet: hero arriba (45%), info abajo con scroll
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: r.height * 0.45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(imageUrl, fit: BoxFit.cover),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF0A0A0A), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(r.horizontalPadding),
                child: infoPanel,
              ),
            ),
          ],
        ),
      );
    }

    // Móvil: diseño original
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Container(color: const Color(0xFF1A0000)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: r.height * 0.36),
                  Container(
                    color: const Color(0xFF0A0A0A),
                    padding: EdgeInsets.all(r.horizontalPadding),
                    child: infoPanel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  11. RESPONSIVE NAV (Bottom Nav en móvil, Rail en TV/Laptop)
// ══════════════════════════════════════════════════════════════

class FlixNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const FlixNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

const kFlixNavItems = [
  FlixNavItem(icon: Icons.home_outlined,      activeIcon: Icons.home_rounded,           label: 'Inicio',       index: 0),
  FlixNavItem(icon: Icons.search_outlined,    activeIcon: Icons.search_rounded,         label: 'Buscar',       index: 1),
  FlixNavItem(icon: Icons.upcoming_outlined,  activeIcon: Icons.upcoming_rounded,       label: 'Próx.',        index: 2),
  FlixNavItem(icon: Icons.tv_outlined,        activeIcon: Icons.tv_rounded,             label: 'Series',       index: 3),
  FlixNavItem(icon: Icons.bookmark_outline,   activeIcon: Icons.bookmark_rounded,       label: 'Mi lista',     index: 4),
  FlixNavItem(icon: Icons.person_outline,     activeIcon: Icons.person_rounded,         label: 'Perfil',       index: 5),
];

// ══════════════════════════════════════════════════════════════
//  12. ORIENTACIÓN DINÁMICA — Aplica en main()
// ══════════════════════════════════════════════════════════════

/// Llama esto en main() en lugar del setPreferredOrientations fijo.
/// Permite paisaje en TV/Laptop/Tablet y solo vertical en móvil.
Future<void> applyResponsiveOrientations() async {
  // Por defecto permitir todas las orientaciones —
  // Flutter detecta el dispositivo automáticamente.
  // Si quieres forzar solo portrait en móvil puedes
  // usar un WidgetsBinding.instance.addPostFrameCallback
  // dentro del primer build de la app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

// ══════════════════════════════════════════════════════════════
//  13. RESPONSIVE HOME LAYOUT — Sidebar + Contenido
// ══════════════════════════════════════════════════════════════

/// Widget que envuelve el HomeScreen body y aplica el sidebar persistente
/// cuando el dispositivo es TV o Laptop.
class ResponsiveHomeWrapper extends StatefulWidget {
  final Widget Function(BuildContext, bool sidebarVisible) bodyBuilder;
  final Widget Function(BuildContext) sidebarBuilder;
  final Widget Function(BuildContext) appBarBuilder;

  const ResponsiveHomeWrapper({
    super.key,
    required this.bodyBuilder,
    required this.sidebarBuilder,
    required this.appBarBuilder,
  });

  @override
  State<ResponsiveHomeWrapper> createState() => _ResponsiveHomeWrapperState();
}

class _ResponsiveHomeWrapperState extends State<ResponsiveHomeWrapper> {
  bool _sidebarVisible = false;

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    if (r.hasPersistentSidebar) {
      // TV / Laptop: sidebar siempre visible
      return Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: Row(
          children: [
            SizedBox(
              width: r.sidebarWidth,
              child: widget.sidebarBuilder(context),
            ),
            Container(width: 1, color: const Color(0xFF1A1A1A)),
            Expanded(
              child: Column(
                children: [
                  widget.appBarBuilder(context),
                  Expanded(
                    child: widget.bodyBuilder(context, false),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet / Móvil: sidebar como overlay deslizable
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          widget.bodyBuilder(context, _sidebarVisible),
          // Gesture para abrir sidebar deslizando desde la izquierda
          if (!_sidebarVisible)
            Positioned(
              left: 0, top: 0, bottom: 0, width: 30,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) {
                  if (d.delta.dx > 3) setState(() => _sidebarVisible = true);
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
          // Overlay oscuro
          if (_sidebarVisible)
            GestureDetector(
              onTap: () => setState(() => _sidebarVisible = false),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          // Sidebar deslizante
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            left: _sidebarVisible ? 0 : -r.sidebarWidth,
            top: 0, bottom: 0, width: r.sidebarWidth,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                if (d.delta.dx < -5) setState(() => _sidebarVisible = false);
              },
              child: widget.sidebarBuilder(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  14. RESPONSIVE SEARCH RESULTS — Grid en TV, Lista en Móvil
// ══════════════════════════════════════════════════════════════

class ResponsiveSearchResults extends StatelessWidget {
  final List<Widget> items;

  const ResponsiveSearchResults({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final r = FlixResponsive.of(context);

    if (r.isDesktop || r.isTablet) {
      // Grid de resultados en pantallas grandes
      return GridView.builder(
        padding: EdgeInsets.all(r.horizontalPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: r.isTV ? 4 : r.isLaptop ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.5,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      );
    }

    // Móvil: lista original
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  15. HELPER — Obtener orientación actual
// ══════════════════════════════════════════════════════════════

extension BuildContextResponsive on BuildContext {
  FlixResponsive get responsive => FlixResponsive.of(this);
  bool get isMobile  => responsive.isMobile;
  bool get isTablet  => responsive.isTablet;
  bool get isLaptop  => responsive.isLaptop;
  bool get isTV      => responsive.isTV;
  bool get isDesktop => responsive.isDesktop;
}