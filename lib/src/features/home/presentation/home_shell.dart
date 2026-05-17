import 'package:fcd_app/src/features/account/presentation/account_page.dart';
import 'package:fcd_app/src/features/ai/presentation/ai_chat_page.dart';
import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloaded_audio_page.dart';
import 'package:fcd_app/src/features/courses/presentation/courses_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_progress_banner.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/features/favorites/presentation/favorites_page.dart';
import 'package:fcd_app/src/state/audio_playback_controller.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/scrolling_text.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final List<ScrollController> _tabScrollControllers;
  bool _downloadsExpanded = false;
  late final List<Widget> _defaultPages;

  static const List<NavigationDestination> _bottomDestinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Mis Cursos',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Catálogo',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'IA',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline_rounded),
          selectedIcon: Icon(Icons.bookmark_rounded),
          label: 'Favoritos',
        ),
        NavigationDestination(
          icon: Icon(Icons.download_outlined),
          selectedIcon: Icon(Icons.download_rounded),
          label: 'Descargas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Cuenta',
        ),
      ];

  List<Widget> get _pages => widget.pages ?? _defaultPages;

  @override
  void initState() {
    super.initState();
    _defaultPages = <Widget>[
      const CoursesPage(),
      const CatalogPage(),
      const AiChatPage(),
      const FavoritesPage(),
      DownloadsPage(onGoToCourses: () => _onDestinationSelected(0)),
      const AccountPage(),
    ];
    assert(
      _pages.length == _bottomDestinations.length,
      'HomeShell pages length must match navigation destinations length.',
    );
    final pageCount = _pages.length;
    _tabScrollControllers = List<ScrollController>.generate(
      pageCount,
      (_) => ScrollController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static const List<NavigationRailDestination> _railDestinations =
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: Text('Mis Cursos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('Catálogo'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: Text('IA'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bookmark_outline_rounded),
          selectedIcon: Icon(Icons.bookmark_rounded),
          label: Text('Favoritos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.download_outlined),
          selectedIcon: Icon(Icons.download_rounded),
          label: Text('Descargas'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Cuenta'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final pages = widget.pages ?? _defaultPages;
    final wrappedPages = List<Widget>.generate(pages.length, (index) {
      return PrimaryScrollController(
        controller: _tabScrollControllers[index],
        child: pages[index],
      );
    });
    final downloadController = context.watch<DownloadTaskController>();
    final playbackController = context.watch<AudioPlaybackController>();
    final hasDownloads = downloadController.hasActiveDownloads;
    final isDownloadsExpanded = _downloadsExpanded && hasDownloads;
    if (_downloadsExpanded && !hasDownloads) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _downloadsExpanded = false;
          });
        }
      });
    }
    final content = IndexedStack(index: _selectedIndex, children: wrappedPages);
    final shellBody = isTablet
        ? Row(
            children: <Widget>[
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: _railDestinations,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: SafeArea(left: false, child: content)),
            ],
          )
        : SafeArea(child: content);

    final shellContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (isDownloadsExpanded && notification is ScrollStartNotification) {
          _collapseDownloadsBanner();
        }
        return false;
      },
      child: shellBody,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _titleForIndex(_selectedIndex),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _subtitleForIndex(_selectedIndex),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: shellContent),
          if (playbackController.player != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 6),
                child: _GlobalMiniPlayer(controller: playbackController),
              ),
            ),
          if (isDownloadsExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: _collapseDownloadsBanner,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          if (hasDownloads)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DownloadProgressBanner(
                controller: downloadController,
                expanded: isDownloadsExpanded,
                onToggle: _toggleDownloadsBanner,
              ),
            ),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF5E8D5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(top: BorderSide(color: Color(0xFFE8DACA))),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                indicatorColor: const Color(0xFFE7C89C),
                onDestinationSelected: _onDestinationSelected,
                destinations: _bottomDestinations,
              ),
            ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Catálogo';
      case 2:
        return 'Asistente IA';
      case 3:
        return 'Mis Favoritos';
      case 4:
        return 'Mis Descargas';
      case 5:
        return 'Mi Cuenta';
      default:
        return 'Mis Cursos';
    }
  }

  String _subtitleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Explora nuevas rutas de aprendizaje';
      case 2:
        return 'Resuelve dudas y profundiza';
      case 3:
        return 'Tus lecciones guardadas';
      case 4:
        return 'Contenido disponible sin conexión';
      case 5:
        return 'Gestiona tu sesión y perfil';
      default:
        return 'Retoma tu práctica donde la dejaste';
    }
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      _scrollTabToTop(index);
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }


  void _scrollTabToTop(int index) {
    if (index < 0 || index >= _tabScrollControllers.length) {
      return;
    }
    final controller = _tabScrollControllers[index];
    if (!controller.hasClients) {
      return;
    }
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleDownloadsBanner() {
    setState(() {
      _downloadsExpanded = !_downloadsExpanded;
    });
  }

  void _collapseDownloadsBanner() {
    if (!_downloadsExpanded) {
      return;
    }
    setState(() {
      _downloadsExpanded = false;
    });
  }
}

class _GlobalMiniPlayer extends StatelessWidget {
  const _GlobalMiniPlayer({required this.controller});

  final AudioPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    if (player == null) {
      return const SizedBox.shrink();
    }
    final title = controller.resourceTitle ?? 'Mini reproductor';

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processing = playerState?.processingState;
        final playing = playerState?.playing ?? false;
        final isBuffering =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Container(
          decoration: const BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFFFF5E8),
                border: Border.all(color: const Color(0xFFE8DACA)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openLesson(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                          if (isBuffering)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          else
                            IconButton.filled(
                              onPressed: () => _toggleAudioPlayback(player),
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.deepBrown,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                ScrollingText(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  velocity: 26,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  playing ? 'Reproduciendo' : 'En pausa',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.mutedText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: controller.stopAndClear,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cerrar reproductor',
                            visualDensity: VisualDensity.compact,
                            color: AppTheme.deepBrown,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final total = player.duration ?? Duration.zero;
                          final totalMs = total.inMilliseconds;
                          final progress = totalMs <= 0
                              ? 0.0
                              : (position.inMilliseconds / totalMs)
                                  .clamp(0.0, 1.0);

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: progress,
                              backgroundColor: const Color(0xFFE8DACA),
                              color: AppTheme.deepBrown,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAudioPlayback(AudioPlayer player) async {
    if (player.playing) {
      await player.pause();
      return;
    }
    await player.play();
  }

  Future<void> _openLesson(BuildContext context) async {
    final course = controller.course;
    final lessons = controller.lessons;
    final lessonIndex = controller.lessonIndex;
    final resourceIndex = controller.resourceIndex;
    final downloadedFile = controller.downloadedFile;
    if (downloadedFile != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DownloadedAudioPage(file: downloadedFile),
        ),
      );
      return;
    }
    if (course == null || lessons == null) {
      return;
    }
    if (lessonIndex == null || resourceIndex == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerPage(
          course: course,
          lessons: lessons,
          initialLessonIndex: lessonIndex,
          initialResourceIndex: resourceIndex,
        ),
      ),
    );
  }
}
