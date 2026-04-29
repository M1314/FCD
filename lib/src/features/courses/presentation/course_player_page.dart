import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:fcd_app/src/core/config/api_config.dart';
import 'package:fcd_app/src/core/storage/favorites_storage.dart';
import 'package:fcd_app/src/core/storage/progress_storage.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CoursePlayerPage extends StatefulWidget {
  const CoursePlayerPage({
    super.key,
    required this.course,
    required this.lessons,
    this.forceStart = false,
    this.initialLessonIndex,
  });

  final Course course;
  final List<CourseLesson> lessons;

  /// When true the player always starts from lesson 0, ignoring saved progress.
  final bool forceStart;

  /// When set, the player starts at this lesson index, ignoring saved progress.
  final int? initialLessonIndex;

  @override
  State<CoursePlayerPage> createState() => _CoursePlayerPageState();
}

class _CoursePlayerPageState extends State<CoursePlayerPage>
    with WidgetsBindingObserver {
  final ProgressStorage _progressStorage = ProgressStorage();
  final FavoritesStorage _favoritesStorage = FavoritesStorage();

  int _lessonIndex = 0;
  int _resourceIndex = 0;
  bool _isLoading = true;
  bool _isCompleted = false;
  bool _isCurrentFavorite = false;
  String? _initializationError;
  bool _isVideoReady = false;
  bool _videoInitFailed = false;
  bool _isAudioLoading = false;
  int _savedMediaPositionMs = 0;
  int _resourcePreparationRequestId = 0;
  String? _activeMediaResourceKey;
  bool _showSessionExpiredBanner = false;

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
    _initializeProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSessionStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<SessionController>();
    if (_cachedSession == null) {
      session.addListener(_onSessionChanged);
      _cachedSession = session;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgressOnDispose();
    _videoController?.dispose(forceDispose: true);
    _audioPlayer?.dispose();
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
      _resourceIndex = 0;
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

    return Scaffold(
      drawer: _buildLessonsDrawer(context),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_showSessionExpiredBanner) _buildSessionExpiredBanner(context),
            _buildTopBar(context),
            _buildProgressBanner(context),
            Expanded(
              child: SingleChildScrollView(
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
        ),
      ),
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
                  'Leccion ${_lessonIndex + 1} de ${widget.lessons.length}',
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
                ? 'Incluye evaluacion al final.'
                : 'Leccion de estudio y practica.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: downloadController.isDownloading
                ? null
                : _downloadCurrentResource,
            icon: downloadController.isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              downloadController.isDownloading
                  ? 'Descargando ${(downloadController.progress * 100).toStringAsFixed(0)}%'
                  : 'Descargar al telefono',
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
                onTap: () async {
                  setState(() {
                    _resourceIndex = index;
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
          'No se pudo inicializar el video. Toca el recurso de nuevo para reintentar.',
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
    final player = _audioPlayer;
    if (player == null || _isAudioLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF6E7D2), Color(0xFFEDD0A6)],
          ),
        ),
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(height: 12),
              Text(
                'Cargando audio...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

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
          Text(
            resource.name.isEmpty ? 'Audio de la leccion' : resource.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _AudioWidget(player: player),
        ],
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
          const SnackBar(content: Text('Leccion marcada como completada.')),
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

    final downloadController = context.read<DownloadTaskController>();
    final result = await downloadController.downloadResource(
      resource,
      courseName: widget.course.name,
      lessonName: currentLesson.name,
    );
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case DownloadTaskStatus.busy:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya hay una descarga en progreso.')),
        );
        return;
      case DownloadTaskStatus.alreadyDownloaded:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este recurso ya fue descargado previamente.'),
          ),
        );
        return;
      case DownloadTaskStatus.failed:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo descargar.')));
        return;
      case DownloadTaskStatus.completed:
        final file = result.file;
        if (file == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Archivo descargado.')));
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

  void _saveProgressOnDispose() {
    var mediaPositionMs = _savedMediaPositionMs;
    if (_currentMediaResourceKey == _activeMediaResourceKey) {
      final resource = currentResource;
      if (resource != null) {
        if (resource.isAudio && _audioPlayer != null) {
          mediaPositionMs = _audioPlayer!.position.inMilliseconds;
        } else if (resource.isVideo && _videoController != null) {
          final controller = _videoController!.videoPlayerController;
          if (controller != null) {
            mediaPositionMs = controller.value.position.inMilliseconds;
          }
        }
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
    final resource = currentResource;
    if (resource == null) {
      return 0;
    }
    // Only persist position when the currently selected resource is the same
    // resource that actually owns the active player instance.
    if (_currentMediaResourceKey != _activeMediaResourceKey) {
      return 0;
    }

    if (resource.isAudio && _audioPlayer != null) {
      return _audioPlayer!.position.inMilliseconds;
    }

    if (resource.isVideo && _videoController != null) {
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
                ? 'Leccion guardada en favoritos.'
                : 'Leccion eliminada de favoritos.',
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
    final previousVideoController = _videoController;
    final previousAudioPlayer = _audioPlayer;

    _videoController = null;
    _audioPlayer = null;
    _webViewController = null;
    _activeMediaResourceKey = null;

    previousVideoController?.dispose(forceDispose: true);
    if (previousAudioPlayer != null) {
      await previousAudioPlayer.stop();
      await previousAudioPlayer.dispose();
    }

    if (!mounted || requestId != _resourcePreparationRequestId) {
      return;
    }

    final resource = currentResource;
    if (resource == null) {
      return;
    }

    if (resource.isVideo) {
      final videoController = _buildVideoController(resource.url);
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
      _isAudioLoading = true;
      setState(() {});
      final audioPlayer = AudioPlayer();
      await audioPlayer.setUrl(resource.url);
      if (!mounted || requestId != _resourcePreparationRequestId) {
        await audioPlayer.dispose();
        _isAudioLoading = false;
        return;
      }
      _audioPlayer = audioPlayer;
      _isAudioLoading = false;
      _activeMediaResourceKey = _currentMediaResourceKey;
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
      await audioPlayer.dispose();
      return;
    }

    _setupDocument(resource.url);
  }

  BetterPlayerController _buildVideoController(String url) {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: 8 * 1024 * 1024,
      ),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 12000,
        maxBufferMs: 90000,
        bufferForPlaybackMs: 3000,
        bufferForPlaybackAfterRebufferMs: 5000,
      ),
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: true,
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
        if (restorePositionMs > 0) {
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
    required this.onTap,
  });

  final LessonResource resource;
  final bool selected;
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
              if (selected)
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

class _AudioWidget extends StatefulWidget {
  const _AudioWidget({required this.player});

  final AudioPlayer player;

  @override
  State<_AudioWidget> createState() => _AudioWidgetState();
}

class _AudioWidgetState extends State<_AudioWidget> {
  double? _dragValueMs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processing = playerState?.processingState;
        final playing = playerState?.playing ?? false;

        final isBuffering =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton.filled(
                  onPressed: isBuffering ? null : _toggle,
                  icon: isBuffering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playing ? 'Reproduciendo...' : 'Pausado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<Duration>(
              stream: widget.player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final total = widget.player.duration ?? Duration.zero;
                final canSeek = total.inMilliseconds > 0;
                final max = total.inMilliseconds <= 0
                    ? 1.0
                    : total.inMilliseconds.toDouble();
                final liveValue = position.inMilliseconds
                    .clamp(0, max.toInt())
                    .toDouble();
                final sliderValue = (_dragValueMs ?? liveValue).clamp(0.0, max);
                final displayPosition = _dragValueMs == null
                    ? position
                    : Duration(milliseconds: sliderValue.round());

                return Column(
                  children: <Widget>[
                    Slider(
                      value: sliderValue,
                      max: max,
                      onChangeStart: canSeek
                          ? (newValue) {
                              setState(() => _dragValueMs = newValue);
                            }
                          : null,
                      onChanged: canSeek
                          ? (newValue) {
                              setState(() => _dragValueMs = newValue);
                            }
                          : null,
                      onChangeEnd: canSeek
                          ? (newValue) async {
                              setState(() => _dragValueMs = null);
                              await widget.player.seek(
                                Duration(milliseconds: newValue.round()),
                              );
                            }
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _formatDuration(displayPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatDuration(total),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (widget.player.playing) {
      await widget.player.pause();
      return;
    }
    await widget.player.play();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
