import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:fcd_app/src/core/config/api_config.dart';
import 'package:fcd_app/src/core/navigation/route_observer.dart';
import 'package:fcd_app/src/core/storage/favorites_storage.dart';
import 'package:fcd_app/src/core/storage/progress_storage.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/audio_mini_player.dart';
import 'package:fcd_app/src/core/widgets/audio_player_widget.dart';
import 'package:fcd_app/src/core/widgets/scrolling_text.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_progress_banner.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloaded_audio_page.dart';
import 'package:fcd_app/src/state/audio_playback_controller.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

@visibleForTesting
bool shouldKeepExistingAudioPlayer({
  required LessonResource? nextResource,
  required bool hasPreviousAudioPlayer,
}) {
  return hasPreviousAudioPlayer && (nextResource?.isDocument ?? false);
}

@visibleForTesting
String normalizeResourceUrl(String url) {
  final queryIndex = url.indexOf('?');
  final fragmentIndex = url.indexOf('#');
  var endIndex = url.length;
  if (queryIndex != -1 && queryIndex < endIndex) {
    endIndex = queryIndex;
  }
  if (fragmentIndex != -1 && fragmentIndex < endIndex) {
    endIndex = fragmentIndex;
  }
  return endIndex == url.length ? url : url.substring(0, endIndex);
}

@visibleForTesting
String resourceDownloadKeyFor(LessonResource resource) {
  return '${resource.type.name}:${normalizeResourceUrl(resource.url)}';
}

class CoursePlayerPage extends StatefulWidget {
  const CoursePlayerPage({
    super.key,
    required this.course,
    required this.lessons,
    this.forceStart = false,
    this.initialLessonIndex,
    this.initialResourceIndex,
  });

  final Course course;
  final List<CourseLesson> lessons;

  /// When true the player always starts from lesson 0, ignoring saved progress.
  final bool forceStart;

  /// When set, the player starts at this lesson index, ignoring saved progress.
  final int? initialLessonIndex;

  /// When set, the player starts at this resource index (with initialLessonIndex).
  final int? initialResourceIndex;

  @override
  State<CoursePlayerPage> createState() => _CoursePlayerPageState();
}

class _CoursePlayerPageState extends State<CoursePlayerPage>
    with WidgetsBindingObserver, RouteAware {
  late final AudioPlaybackController _playbackController;
  final ProgressStorage _progressStorage = ProgressStorage();
  final FavoritesStorage _favoritesStorage = FavoritesStorage();
  late final DownloadRepository _downloadRepository;

  int _lessonIndex = 0;
  int _resourceIndex = 0;
  bool _isLoading = true;
  bool _isCompleted = false;
  bool _isCurrentFavorite = false;
  String? _initializationError;
  bool _isVideoReady = false;
  bool _videoInitFailed = false;
  bool _showVideoDurationWarning = false;
  bool _isAudioLoading = false;
  int _savedMediaPositionMs = 0;
  int _resourcePreparationRequestId = 0;
  String? _activeMediaResourceKey;
  bool _showSessionExpiredBanner = false;
  bool _downloadsExpanded = false;
  Set<String> _downloadedResourceKeys = <String>{};
  Map<String, DownloadedFile> _downloadedResourceFiles =
      <String, DownloadedFile>{};
  bool _reuseSharedAudio = false;
  bool _resumeSharedAudio = false;

  BetterPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  WebViewController? _webViewController;

  final Set<int> _completedLessonIds = <int>{};
  Set<int> _favoriteIds = <int>{};

  SessionController? _cachedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playbackController = context.read<AudioPlaybackController>();
    // Do not adopt whatever shared/global audio session is currently active.
    // This page should only attach `_audioPlayer` and `_activeMediaResourceKey`
    // when it starts or resumes playback for one of this course's resources.
    _downloadRepository = DownloadRepository(
      apiClient: context.read<SessionController>().apiClient,
    );
    _initializeProgress();
    _refreshDownloadedResources();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSessionStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context) as ModalRoute<void>?;
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
    final session = context.read<SessionController>();
    if (_cachedSession == null) {
      session.addListener(_onSessionChanged);
      _cachedSession = session;
    }
    _refreshDownloadedResources();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _saveProgressOnDispose();
    _videoController?.dispose(forceDispose: true);
    if (_audioPlayer != null && _audioPlayer != _playbackController.player) {
      _audioPlayer?.dispose();
    }
    _cachedSession?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _checkSessionStatus() {
    final session = context.read<SessionController>();
    if (session.isUnauthenticated && session.sessionExpired) {
      setState(() {
        _showSessionExpiredBanner = true;
      });
    }
  }

  void _onSessionChanged() {
    final session = context.read<SessionController>();
    if (session.isUnauthenticated && session.sessionExpired) {
      if (!_showSessionExpiredBanner) {
        setState(() {
          _showSessionExpiredBanner = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
    }
    if (state == AppLifecycleState.resumed) {
      _refreshDownloadedResources();
    }
  }

  @override
  void didPopNext() {
    _refreshDownloadedResources();
  }

  Future<void> _initializeProgress() async {
    if (widget.lessons.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _initializationError = 'Este curso aún no tiene lecciones disponibles.';
      });
      return;
    }

    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _initializationError = 'Sesión no válida. Vuelve a iniciar sesión.';
      });
      return;
    }

    try {
      final completed = await session.courseRepository.getCompletedLessonIds(
        userId: user.id,
        courseId: widget.course.id,
      );

      _completedLessonIds
        ..clear()
        ..addAll(completed);
    } catch (_) {
      _completedLessonIds.clear();
    }

    // Load favorites
    try {
      _favoriteIds = await _favoritesStorage.getFavorites(user.id);
    } catch (_) {
      _favoriteIds = <int>{};
    }

    if (!mounted) {
      return;
    }
    if (widget.initialLessonIndex != null) {
      _lessonIndex = widget.initialLessonIndex!.clamp(
        0,
        widget.lessons.length - 1,
      );
      final resources = widget.lessons[_lessonIndex].resources;
      if (resources.isEmpty) {
        _resourceIndex = 0;
      } else {
        final initialResourceIndex = widget.initialResourceIndex ?? 0;
        _resourceIndex =
            initialResourceIndex.clamp(0, resources.length - 1);
      }
      final targetKey = _currentMediaResourceKey;
      if (_playbackController.player != null &&
          targetKey != null &&
          targetKey == _playbackController.activeMediaResourceKey) {
        _reuseSharedAudio = true;
        _resumeSharedAudio = _playbackController.player!.playing;
        _savedMediaPositionMs =
            _playbackController.player!.position.inMilliseconds;
      }
    } else if (!widget.forceStart) {
      final saved = await _progressStorage.getProgress(widget.course.id);
      if (!mounted) {
        return;
      }
      if (saved != null && saved.lessonIndex < widget.lessons.length) {
        _lessonIndex = saved.lessonIndex;
        final resources = widget.lessons[saved.lessonIndex].resources;
        _resourceIndex = resources.isEmpty
            ? 0
            : saved.resourceIndex.clamp(0, resources.length - 1);
        _savedMediaPositionMs = saved.mediaPositionMs;
      } else {
        final firstPending = widget.lessons.indexWhere(
          (lesson) => !_completedLessonIds.contains(lesson.id),
        );
        _lessonIndex = firstPending == -1 ? 0 : firstPending;
        _resourceIndex = 0;
        _savedMediaPositionMs = 0;
      }
    } else {
      _lessonIndex = 0;
      _resourceIndex = 0;
      _savedMediaPositionMs = 0;
    }

    _isCompleted = _completedLessonIds.contains(currentLesson.id);
    _isCurrentFavorite = _favoriteIds.contains(currentLesson.id);
    if (_reuseSharedAudio) {
      _isAudioLoading = false;
      _activeMediaResourceKey = _currentMediaResourceKey;
      _reuseSharedAudio = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    await _prepareCurrentResource();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });
  }

  CourseLesson get currentLesson => widget.lessons[_lessonIndex];

  List<LessonResource> get currentResources => currentLesson.resources;

  int? _clampedResourceIndexOrNull() {
    if (currentResources.isEmpty) {
      return null;
    }
    return _resourceIndex.clamp(0, currentResources.length - 1);
  }

  LessonResource? get currentResource {
    final clampedResourceIndex = _clampedResourceIndexOrNull();
    if (clampedResourceIndex == null) {
      return null;
    }
    return currentResources[clampedResourceIndex];
  }

  String? get _currentMediaResourceKey {
    final clampedResourceIndex = _clampedResourceIndexOrNull();
    if (clampedResourceIndex == null) {
      return null;
    }
    return '$_lessonIndex:$clampedResourceIndex';
  }

  LessonResource? get _activeMediaResource {
    final key = _activeMediaResourceKey;
    if (key == null) {
      return null;
    }
    final parts = key.split(':');
    if (parts.length != 2) {
      return null;
    }
    final lessonIndex = int.tryParse(parts[0]);
    final resourceIndex = int.tryParse(parts[1]);
    if (lessonIndex == null || resourceIndex == null) {
      return null;
    }
    if (lessonIndex < 0 || lessonIndex >= widget.lessons.length) {
      return null;
    }
    final resources = widget.lessons[lessonIndex].resources;
    if (resourceIndex < 0 || resourceIndex >= resources.length) {
      return null;
    }
    return resources[resourceIndex];
  }

  bool get _showMiniAudioPlayer {
    return _playbackController.player != null;
  }

  bool get _hasPreviousLesson => _lessonIndex > 0;

  bool get _hasNextLesson => _lessonIndex < widget.lessons.length - 1;

  double get _progress {
    if (widget.lessons.isEmpty) {
      return 0;
    }
    final raw = _completedLessonIds.length / widget.lessons.length;
    if (!raw.isFinite) {
      return 0;
    }
    return raw.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_initializationError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_initializationError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final content = Column(
      children: <Widget>[
        if (_showSessionExpiredBanner) _buildSessionExpiredBanner(context),
        _buildTopBar(context),
        _buildProgressBanner(context),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: _showMiniAudioPlayer ? 86 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildViewer(context),
                _buildBottomPanel(context),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      drawer: _buildLessonsDrawer(context),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (_downloadsExpanded &&
                    notification is ScrollStartNotification) {
                  _collapseDownloadsBanner();
                }
                return false;
              },
              child: content,
            ),
            if (_downloadsExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _collapseDownloadsBanner,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDownloadsBanner(context),
            ),
            if (_showMiniAudioPlayer) _buildMiniAudioPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsBanner(BuildContext context) {
    final downloadController = context.watch<DownloadTaskController>();
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

    if (!hasDownloads) {
      return const SizedBox.shrink();
    }

    return DownloadProgressBanner(
      controller: downloadController,
      expanded: isDownloadsExpanded,
      onToggle: _toggleDownloadsBanner,
    );
  }

  Widget _buildSessionExpiredBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu sesión expiró. Por favor, inicia sesión de nuevo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Ir al login'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () async {
              await _saveProgress();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lección ${_lessonIndex + 1} de ${widget.lessons.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
          Builder(
            builder: (drawerContext) => IconButton(
              onPressed: () => Scaffold.of(drawerContext).openDrawer(),
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: 'Temario',
            ),
          ),
          IconButton(
            onPressed: _hasPreviousLesson ? _previousLesson : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            onPressed: _hasNextLesson ? _nextLesson : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Temario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_showVideoDurationWarning)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video sin duración. Recarga para reintentar.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.lessons.length,
                itemBuilder: (context, index) {
                  final lesson = widget.lessons[index];
                  final selected = index == _lessonIndex;
                  final resourcesCount = lesson.resources.length;
                  final resourcesLabel = resourcesCount == 1
                      ? '1 recurso'
                      : '$resourcesCount recursos';
                  return ListTile(
                    selected: selected,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      lesson.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(resourcesLabel),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: selected
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _goToLesson(index);
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBanner(BuildContext context) {
    final percent = NumberFormat.percentPattern('es').format(_progress);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF1DFC6), Color(0xFFE7C89C)],
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Progreso del curso: $percent',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: _progress,
                      backgroundColor: const Color(0xFFF6EBDD),
                      color: AppTheme.deepBrown,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: _isCompleted ? null : _markCompleted,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(204),
                foregroundColor: AppTheme.deepBrown,
              ),
              child: const Text('Marcar completa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final resource = currentResource;
    if (resource == null) {
      return _buildEmptyViewer(
        'Esta lección aún no tiene recursos disponibles.',
      );
    }

    if (resource.isVideo) {
      return _buildVideoViewer();
    }
    if (resource.isAudio) {
      return _buildAudioViewer(resource);
    }
    return _buildDocumentViewer();
  }

  Widget _buildBottomPanel(BuildContext context) {
    final downloadController = context.watch<DownloadTaskController>();
    final resource = currentResource;
    final isDownloading =
        resource != null && downloadController.isDownloadingResource(resource);
    final isDownloaded = resource != null && _isResourceDownloaded(resource);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  currentLesson.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isCurrentFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: _isCurrentFavorite
                      ? AppTheme.bronze
                      : AppTheme.mutedText,
                ),
                tooltip: _isCurrentFavorite
                    ? 'Quitar de favoritos'
                    : 'Guardar en favoritos',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currentLesson.hasEvaluation
                ? 'Incluye evaluación al final.'
                : 'Lección de estudio y práctica.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                isDownloading || isDownloaded ? null : _downloadCurrentResource,
            icon: const Icon(Icons.download_rounded),
            label: Text(
              isDownloading
                  ? 'Descargando'
                  : (isDownloaded ? 'Ya descargado' : 'Descargar al teléfono'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Recursos de la lección',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...List.generate(currentResources.length, (index) {
            final item = currentResources[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < currentResources.length - 1 ? 8 : 0,
              ),
              child: _ResourceTile(
                resource: item,
                selected: index == _resourceIndex,
                downloaded: _isResourceDownloaded(item),
                onTap: () async {
                  setState(() {
                    _resourceIndex = index;
                    _showVideoDurationWarning = false;
                  });
                  _savedMediaPositionMs = 0;
                  await _saveProgress();
                  await _prepareCurrentResource();
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoViewer() {
    final controller = _videoController;
    if (controller == null) {
      return _buildEmptyViewer('No se pudo cargar el video.');
    }

    if (!_isVideoReady) {
      if (_videoInitFailed) {
        return _buildEmptyViewer(
          'No se pudo inicializar el video. Verifica tener buena conexión a internet y toca el recurso de nuevo para reintentar.',
        );
      }
      return _buildLoadingViewer();
    }

    return SizedBox(
      height: 240,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: BetterPlayer(controller: controller),
      ),
    );
  }

  Widget _buildAudioViewer(LessonResource resource) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF6E7D2), Color(0xFFEDD0A6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.multitrack_audio_rounded, size: 36),
          const SizedBox(height: 10),
          ScrollingText(
            resource.name.isEmpty ? 'Audio de la lección' : resource.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          if (_isAudioLoading || _audioPlayer == null)
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Cargando audio...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )
          else
            AudioPlayerWidget(player: _audioPlayer!),
        ],
      ),
    );
  }

  Widget _buildMiniAudioPlayer() {
    final player = _playbackController.player;
    if (player == null) {
      return const SizedBox.shrink();
    }
    final title = _activeMediaResource?.name ??
        _playbackController.resourceTitle ??
        'Mini reproductor';

    return Positioned(
      left: 12,
      right: 12,
      bottom: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: AudioMiniPlayer(
          player: player,
          title: title,
          onTap: _openActiveAudioResource,
          onClose: _playbackController.stopAndClear,
          showCloseButton: true,
        ),
      ),
    );
  }

  Future<void> _openActiveAudioResource() async {
    final course = _playbackController.course;
    final lessons = _playbackController.lessons;
    final lessonIndex = _playbackController.lessonIndex;
    final resourceIndex = _playbackController.resourceIndex;
    final downloadedFile = _playbackController.downloadedFile;
    
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

    if (course.id == widget.course.id) {
      setState(() {
        _lessonIndex = lessonIndex;
        _resourceIndex = resourceIndex.clamp(0, lessons.length - 1);
        _isCompleted = _completedLessonIds.contains(currentLesson.id);
        _isCurrentFavorite = _favoriteIds.contains(currentLesson.id);
        _showVideoDurationWarning = false;
      });
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

  Widget _buildDocumentViewer() {
    final controller = _webViewController;
    if (controller == null) {
      return _buildEmptyViewer('No se pudo abrir el documento.');
    }

    return SizedBox(
      height: 420,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8DACA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: WebViewWidget(controller: controller),
      ),
    );
  }

  Widget _buildEmptyViewer(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8DACA)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingViewer() {
    return SizedBox(
      height: 240,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      ),
    );
  }

  Future<void> _markCompleted() async {
    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      return;
    }

    try {
      await session.courseRepository.markLessonAsCompleted(
        userId: user.id,
        courseId: widget.course.id,
        lessonId: currentLesson.id,
      );

      setState(() {
        _completedLessonIds.add(currentLesson.id);
        _isCompleted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lección marcada como completada.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar progreso: $error')),
      );
    }
  }

  Future<void> _downloadCurrentResource() async {
    final resource = currentResource;
    if (resource == null) {
      return;
    }

    if (_isResourceDownloaded(resource)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este recurso ya está descargado.')),
      );
      return;
    }

    final downloadResource = resource.copyWithCourseMedia(
      courseBannerUrl: widget.course.bannerUrl,
      courseIconUrl: widget.course.iconUrl,
    );

    final downloadController = context.read<DownloadTaskController>();
    final result = await downloadController.downloadResource(
      downloadResource,
      courseName: widget.course.name,
      lessonName: currentLesson.name,
    );
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case DownloadTaskStatus.busy:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este recurso ya se está descargando.')),
        );
        return;
      case DownloadTaskStatus.alreadyDownloaded:
        await _refreshDownloadedResources();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este recurso ya fue descargado previamente.'),
          ),
        );
        return;
      case DownloadTaskStatus.canceled:
        // User canceled, no error message needed
        return;
      case DownloadTaskStatus.failed:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo descargar.')));
        return;
      case DownloadTaskStatus.completed:
        await _refreshDownloadedResources();
        final file = result.file;
        if (file == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Archivo descargado.')));
          return;
        }
        if (resource.isAudio || resource.isVideo) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo descargado. Disponible en Descargas.'),
            ),
          );
          return;
        }
        final openResult = await OpenFilex.open(file.path);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              openResult.type == ResultType.done
                  ? 'Archivo descargado y abierto.'
                  : 'Archivo descargado: ${file.path}',
            ),
          ),
        );
        return;
    }
  }

  bool _isResourceDownloaded(LessonResource resource) {
    return _downloadedResourceKeys.contains(_resourceKey(resource));
  }

  String _resourceKey(LessonResource resource) {
    return resourceDownloadKeyFor(resource);
  }

  DownloadedFile? _downloadedFileForResource(LessonResource resource) {
    final normalizedKey = _resourceKey(resource);
    return _downloadedResourceFiles[normalizedKey] ??
        _downloadedResourceFiles['${resource.type.name}:${resource.url}'];
  }

  Future<void> _refreshDownloadedResources() async {
    final cleanup = await _downloadRepository.removeMissingDownloads();
    if (!mounted) {
      return;
    }
    setState(() {
      final keys = <String>{};
      final filesByKey = <String, DownloadedFile>{};
      for (final file in cleanup.files) {
        if (file.id.isNotEmpty) {
          keys.add(file.id);
          filesByKey[file.id] = file;
        }
        if (file.url.isNotEmpty) {
          final normalizedUrl = normalizeResourceUrl(file.url);
          final urlKey = '${file.type}:$normalizedUrl';
          keys.add(urlKey);
          filesByKey[urlKey] = file;
        }
      }
      _downloadedResourceKeys = keys;
      _downloadedResourceFiles = filesByKey;
    });
  }


  Future<void> _nextLesson() async {
    await _markCurrentAsSeen();
    if (!_hasNextLesson) {
      return;
    }
    await _switchToLesson(_lessonIndex + 1);
  }

  Future<void> _previousLesson() async {
    if (!_hasPreviousLesson) {
      return;
    }
    await _switchToLesson(_lessonIndex - 1);
  }

  Future<void> _goToLesson(int index) async {
    if (index < 0 || index >= widget.lessons.length || index == _lessonIndex) {
      return;
    }
    await _switchToLesson(index);
  }

  Future<void> _switchToLesson(int index) async {
    setState(() {
      _lessonIndex = index;
      _resourceIndex = 0;
      _isCompleted = _completedLessonIds.contains(currentLesson.id);
      _isCurrentFavorite = _favoriteIds.contains(currentLesson.id);
      _showVideoDurationWarning = false;
    });
    _savedMediaPositionMs = 0;

    await _saveProgress();
    await _prepareCurrentResource();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProgress() async {
    try {
      final mediaPositionMs = await _readCurrentMediaPositionMs();
      _savedMediaPositionMs = mediaPositionMs;
      await _progressStorage.saveProgress(
        courseId: widget.course.id,
        lessonIndex: _lessonIndex,
        resourceIndex: _resourceIndex,
        mediaPositionMs: mediaPositionMs,
      );
    } catch (_) {}
  }

  Future<void> _persistSharedPlaybackProgress({
    required int courseId,
    required int lessonIndex,
    required int resourceIndex,
    required int mediaPositionMs,
  }) async {
    try {
      _savedMediaPositionMs = mediaPositionMs;
      await _progressStorage.saveProgress(
        courseId: courseId,
        lessonIndex: lessonIndex,
        resourceIndex: resourceIndex,
        mediaPositionMs: mediaPositionMs,
      );
    } catch (_) {}
  }

  void _saveProgressOnDispose() {
    var mediaPositionMs = _savedMediaPositionMs;
    if (_audioPlayer != null) {
      mediaPositionMs = _audioPlayer!.position.inMilliseconds;
    } else if (_videoController != null) {
      final controller = _videoController!.videoPlayerController;
      if (controller != null) {
        mediaPositionMs = controller.value.position.inMilliseconds;
      }
    }
    _savedMediaPositionMs = mediaPositionMs;
    // Best-effort fallback for exits where we cannot await async work (dispose).
    // Primary path is the awaited save when user leaves via back navigation.
    unawaited(
      _progressStorage
          .saveProgress(
            courseId: widget.course.id,
            lessonIndex: _lessonIndex,
            resourceIndex: _resourceIndex,
            mediaPositionMs: mediaPositionMs,
          )
          .catchError((_) {}),
    );
  }

  Future<int> _readCurrentMediaPositionMs() async {
    if (_audioPlayer != null) {
      return _audioPlayer!.position.inMilliseconds;
    }

    if (_videoController != null) {
      final controller = _videoController!.videoPlayerController;
      if (controller == null) {
        return 0;
      }
      final position = await controller.position;
      return position?.inMilliseconds ?? 0;
    }

    return 0;
  }

  Future<void> _toggleFavorite() async {
    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      return;
    }

    try {
      final nowFav = await _favoritesStorage.toggleFavorite(
        user.id,
        currentLesson.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isCurrentFavorite = nowFav;
        if (nowFav) {
          _favoriteIds.add(currentLesson.id);
        } else {
          _favoriteIds.remove(currentLesson.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFav
                ? 'Lección guardada en favoritos.'
                : 'Lección eliminada de favoritos.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  Future<void> _markCurrentAsSeen() async {
    if (_completedLessonIds.contains(currentLesson.id)) {
      return;
    }

    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      return;
    }

    try {
      await session.courseRepository.markLessonAsCompleted(
        userId: user.id,
        courseId: widget.course.id,
        lessonId: currentLesson.id,
      );
      _completedLessonIds.add(currentLesson.id);
    } catch (_) {}
  }

  Future<void> _prepareCurrentResource() async {
    final requestId = ++_resourcePreparationRequestId;
    final resource = currentResource;
    final previousVideoController = _videoController;
    final previousAudioPlayer = _audioPlayer;
    final previousActiveMediaResourceKey = _activeMediaResourceKey;
    final keepExistingAudioPlayer = shouldKeepExistingAudioPlayer(
      nextResource: resource,
      hasPreviousAudioPlayer: previousAudioPlayer != null,
    );

    _videoController = null;
    _audioPlayer = keepExistingAudioPlayer ? previousAudioPlayer : null;
    _webViewController = null;
    _activeMediaResourceKey = keepExistingAudioPlayer
        ? previousActiveMediaResourceKey
        : null;

    previousVideoController?.dispose(forceDispose: true);
    if (!keepExistingAudioPlayer && previousAudioPlayer != null) {
      await previousAudioPlayer.stop();
    }

    if (!mounted || requestId != _resourcePreparationRequestId) {
      return;
    }

    if (resource == null) {
      return;
    }

    if (resource.isVideo) {
      _playbackController.clearSession();
      final artworkUrl = widget.course.iconUrl.isNotEmpty
          ? widget.course.iconUrl
          : widget.course.bannerUrl;
      var videoSourceUrl = resource.url;
      var isLocalFile = false;
      var notificationImageUrl = artworkUrl.isNotEmpty ? artworkUrl : null;
      final downloadedFile = _downloadedFileForResource(resource);
      if (downloadedFile != null && downloadedFile.localPath.isNotEmpty) {
        final localFile = File(downloadedFile.localPath);
        if (await localFile.exists()) {
          if (!mounted || requestId != _resourcePreparationRequestId) {
            return;
          }
          videoSourceUrl = localFile.path;
          isLocalFile = true;
          if (downloadedFile.localArtworkPath.isNotEmpty) {
            notificationImageUrl = 'file://${downloadedFile.localArtworkPath}';
          }
        }
      }
      final videoController = _buildVideoController(
        videoSourceUrl,
        title: resource.name.isEmpty ? 'Video de la lección' : resource.name,
        imageUrl: notificationImageUrl,
        isLocalFile: isLocalFile,
      );
      if (!mounted || requestId != _resourcePreparationRequestId) {
        videoController.dispose(forceDispose: true);
        return;
      }
      _videoController = videoController;
      _activeMediaResourceKey = _currentMediaResourceKey;
      _isVideoReady = false;
      _videoInitFailed = false;
      _startVideoInitializationCheck(
        videoController,
        requestId,
        restorePositionMs: _savedMediaPositionMs,
      );
      return;
    }
    if (resource.isAudio) {
      if (_reuseSharedAudio &&
          _audioPlayer != null &&
          _currentMediaResourceKey == _playbackController.activeMediaResourceKey) {
        _isAudioLoading = false;
        _activeMediaResourceKey = _currentMediaResourceKey;
        if (_resumeSharedAudio && !_audioPlayer!.playing) {
          await _audioPlayer!.play();
        }
        _reuseSharedAudio = false;
        _resumeSharedAudio = false;
        return;
      }
      _isAudioLoading = true;
      setState(() {});
      final audioPlayer =
          _audioPlayer ??= _playbackController.player ?? AudioPlayer();
      final artworkUrl = widget.course.iconUrl.isNotEmpty
          ? widget.course.iconUrl
          : widget.course.bannerUrl;
      await audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(resource.url),
          tag: MediaItem(
            id: resource.url,
            title: resource.name.isEmpty
                ? 'Audio de la lección'
                : resource.name,
            artist: widget.course.name,
            artUri: artworkUrl.isNotEmpty ? Uri.parse(artworkUrl) : null,
          ),
        ),
      );
      if (!mounted || requestId != _resourcePreparationRequestId) {
        _isAudioLoading = false;
        return;
      }
      _audioPlayer = audioPlayer;
      _isAudioLoading = false;
      _activeMediaResourceKey = _currentMediaResourceKey;
      _reuseSharedAudio = false;
      _resumeSharedAudio = false;
      _playbackController.setSession(
        player: audioPlayer,
        courseId: widget.course.id,
        lessonIndex: _lessonIndex,
        resourceIndex: _resourceIndex,
        resourceTitle:
            resource.name.isEmpty ? 'Audio de la lección' : resource.name,
        courseTitle: widget.course.name,
        course: widget.course,
        lessons: widget.lessons,
        onPersistCourseProgress: _persistSharedPlaybackProgress,
      );
      if (_savedMediaPositionMs > 0) {
        try {
          await audioPlayer.seek(Duration(milliseconds: _savedMediaPositionMs));
        } catch (_) {
          if (requestId == _resourcePreparationRequestId) {
            rethrow;
          }
          // The request became stale while seeking; cleanup is handled below.
        }
      }
      if (mounted && requestId == _resourcePreparationRequestId) {
        return;
      }
      if (_audioPlayer == audioPlayer) {
        _audioPlayer = null;
        _isAudioLoading = false;
        setState(() {});
      }
      _activeMediaResourceKey = null;
      await audioPlayer.stop();
      return;
    }

    _setupDocument(resource.url);
  }

  BetterPlayerController _buildVideoController(
    String url, {
    String? title,
    String? imageUrl,
    bool isLocalFile = false,
  }) {
    final dataSource = BetterPlayerDataSource(
      isLocalFile
          ? BetterPlayerDataSourceType.file
          : BetterPlayerDataSourceType.network,
      url,
      cacheConfiguration: isLocalFile
          ? null
          : const BetterPlayerCacheConfiguration(
              useCache: true,
              preCacheSize: 8 * 1024 * 1024,
            ),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 12000,
        maxBufferMs: 90000,
        bufferForPlaybackMs: 3000,
        bufferForPlaybackAfterRebufferMs: 5000,
      ),
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: title ?? 'Video de la lección',
        imageUrl: imageUrl,
      ),
    );

    final videoController = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: false,
        fit: BoxFit.contain,
        allowedScreenSleep: false,
        handleLifecycle: false,
        autoDispose: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSkips: true,
          enablePlaybackSpeed: true,
          enablePip: true,
          loadingColor: AppTheme.gold,
          progressBarBackgroundColor: Color(0x44FFFFFF),
          progressBarPlayedColor: AppTheme.gold,
          playerTheme: BetterPlayerTheme.material,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    return videoController;
  }

  void _startVideoInitializationCheck(
    BetterPlayerController controller,
    int requestId, {
    required int restorePositionMs,
  }) {
    _debugVideoInitLog(
      'start requestId=$requestId resource=$_currentMediaResourceKey restoreMs=$restorePositionMs',
    );
    int attempts = 0;
    const maxAttempts = 120;
    const fallbackAttempts = 50; // 5 seconds
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted ||
          requestId != _resourcePreparationRequestId ||
          _videoController != controller) {
        _debugVideoInitLog(
          'cancel requestId=$requestId mounted=$mounted activeRequest=$_resourcePreparationRequestId controllerChanged=${_videoController != controller}',
        );
        timer.cancel();
        return;
      }

      final videoPlayerController = controller.videoPlayerController;
      final value = videoPlayerController?.value;
      final duration = value?.duration;
      final hasDuration = duration != null && duration > Duration.zero;
      final isReady = value != null && value.initialized && hasDuration;

      // Debug-only telemetry to understand readiness timing differences across
      // devices/simulators without flooding release logs.
      if (attempts == 0 || attempts % 10 == 0) {
        _debugVideoInitLog(
          'poll requestId=$requestId attempt=$attempts initialized=${value?.initialized} duration=$duration',
        );
      }

      if (isReady) {
        timer.cancel();
        _debugVideoInitLog(
          'ready requestId=$requestId attempt=$attempts duration=$duration',
        );
        if (restorePositionMs > 0 && hasDuration) {
          final durationMs = duration.inMilliseconds;
          final clampedPositionMs = restorePositionMs.clamp(0, durationMs);
          try {
            controller.seekTo(Duration(milliseconds: clampedPositionMs));
            _debugVideoInitLog(
              'seek requestId=$requestId targetMs=$clampedPositionMs durationMs=$durationMs',
            );
          } catch (_) {}
        }
        if (mounted && requestId == _resourcePreparationRequestId) {
          setState(() {
            _isVideoReady = true;
            _videoInitFailed = false;
            _showVideoDurationWarning = false;
          });
        }
        return;
      }

      // Fallback: show video after 5 seconds even without duration
      if (attempts >= fallbackAttempts) {
        timer.cancel();
        _debugVideoInitLog(
          'fallback requestId=$requestId attempt=$attempts showing without duration',
        );
        if (mounted && requestId == _resourcePreparationRequestId) {
          setState(() {
            _isVideoReady = true;
            _showVideoDurationWarning = true;
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _showVideoDurationWarning = false;
              });
            }
          });
        }
        return;
      }

      attempts++;
      if (attempts >= maxAttempts) {
        timer.cancel();
        _debugVideoInitLog(
          'timeout requestId=$requestId attempts=$attempts initialized=${value?.initialized} duration=$duration',
        );
        if (mounted && requestId == _resourcePreparationRequestId) {
          setState(() {
            _videoInitFailed = true;
          });
        }
      }
    });
  }

  // Purpose: provide deep diagnostics for video initialization races in debug
  // builds only. Using assert keeps logs out of release/profile builds.
  void _debugVideoInitLog(String message) {
    assert(() {
      debugPrint('[CoursePlayer:VideoInit] $message');
      return true;
    }());
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

  void _setupDocument(String url) {
    final viewerUrl =
        '${ApiConfig.googleViewerUrlPrefix}${Uri.encodeComponent(url)}';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.contains('download')) {
              launchUrl(Uri.parse(request.url));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.selected,
    required this.downloaded,
    required this.onTap,
  });

  final LessonResource resource;
  final bool selected;
  final bool downloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF2E1C8) : const Color(0xFFF8F1E7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(_iconForType(resource.type), color: AppTheme.deepBrown),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resource.name.isEmpty
                      ? _defaultName(resource.type)
                      : resource.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (downloaded)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.deepBrown,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(LessonResourceType type) {
    switch (type) {
      case LessonResourceType.audio:
        return Icons.headphones_rounded;
      case LessonResourceType.video:
        return Icons.play_circle_fill_rounded;
      case LessonResourceType.document:
        return Icons.description_rounded;
    }
  }

  String _defaultName(LessonResourceType type) {
    switch (type) {
      case LessonResourceType.audio:
        return 'Audio';
      case LessonResourceType.video:
        return 'Video';
      case LessonResourceType.document:
        return 'Documento';
    }
  }
}
