import 'package:fcd_app/src/core/errors/error_ui.dart';
import 'package:fcd_app/src/core/storage/favorites_storage.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
import 'package:fcd_app/src/features/favorites/data/favorites_cache_storage.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AnimatedFavoriteItem extends StatefulWidget {
  const AnimatedFavoriteItem({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AnimatedFavoriteItem> createState() => _AnimatedFavoriteItemState();
}

class _AnimatedFavoriteItemState extends State<AnimatedFavoriteItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesStorage _favoritesStorage = FavoritesStorage();
  final Map<int, GlobalKey<_AnimatedFavoriteItemState>> _itemKeys = {};
  final FavoritesCacheStorage _favoritesCacheStorage = FavoritesCacheStorage();

  bool _loading = true;
  bool _isRefreshing = false;
  String? _error;
  String? _notice;

  /// Each entry pairs the lesson with its parent course (needed to open player).
  List<_FavoriteEntry> _favorites = <_FavoriteEntry>[];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final session = context.read<SessionController>();
    final user = session.user;

    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no válida. Vuelve a iniciar sesión.';
      });
      return;
    }

    try {
      // 1. Get the set of favorited lesson IDs.
      final favoriteIds = await _favoritesStorage.getFavorites(user.id);

      if (favoriteIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _favorites = <_FavoriteEntry>[];
          _loading = false;
          _isRefreshing = false;
          _notice = null;
        });
        return;
      }

      final coursesFromCache = await _favoritesCacheStorage.read(user.id);
      final cachedEntries = _buildEntries(
        favoriteIds: favoriteIds,
        courses: coursesFromCache,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = cachedEntries.isEmpty;
        _isRefreshing = true;
        _error = null;
        _notice = null;
        if (cachedEntries.isNotEmpty) {
          _favorites = cachedEntries;
        }
      });

      // 2. Refresh from API and replace cache.
      final courses = await session.courseRepository.getMyCourses(user.id);

      final results = await Future.wait(
        courses.map((course) async {
          try {
            final lessons = await session.courseRepository
                .getAllLessonsByCourse(courseId: course.id);
            return _CourseLessonsResult(
              course: course,
              lessons: lessons,
              failed: false,
            );
          } catch (_) {
            return _CourseLessonsResult(
              course: course,
              lessons: const <CourseLesson>[],
              failed: true,
            );
          }
        }),
      );

      final apiCourses = <CachedFavoriteCourse>[];
      var failedCount = 0;
      for (final result in results) {
        if (result.failed) {
          failedCount++;
          continue;
        }
        apiCourses.add(
          CachedFavoriteCourse(course: result.course, lessons: result.lessons),
        );
      }

      if (apiCourses.isNotEmpty) {
        await _favoritesCacheStorage.save(user.id, apiCourses);
      }

      final sourceCourses = apiCourses.isNotEmpty ? apiCourses : coursesFromCache;
      final entries = _buildEntries(
        favoriteIds: favoriteIds,
        courses: sourceCourses,
      );
      final shouldShowCacheFallbackNotice =
          apiCourses.isEmpty && cachedEntries.isNotEmpty;

      if (!mounted) return;
      setState(() {
        _favorites = entries;
        _loading = false;
        _isRefreshing = false;
        _error = entries.isEmpty && failedCount == courses.length
            ? 'No se pudieron cargar tus cursos favoritos. Intenta nuevamente.'
            : null;
        _notice = shouldShowCacheFallbackNotice
            ? 'Mostrando copia local mientras se restablece la conexión.'
            : failedCount > 0
            ? 'No se pudieron cargar $failedCount curso(s). Intenta actualizar.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isRefreshing = false;
        if (_favorites.isNotEmpty) {
          _notice =
              'Mostrando copia local. Revisa tu conexión e intenta actualizar.';
        } else {
          _error = userMessageFromError(
            e,
            fallbackMessage: 'No se pudieron cargar los favoritos.',
          );
        }
      });
    }
  }

  List<_FavoriteEntry> _buildEntries({
    required Set<int> favoriteIds,
    required List<CachedFavoriteCourse> courses,
  }) {
    final entries = <_FavoriteEntry>[];
    for (final courseItem in courses) {
      for (final lesson in courseItem.lessons) {
        if (favoriteIds.contains(lesson.id)) {
          entries.add(
            _FavoriteEntry(
              course: courseItem.course,
              lessons: courseItem.lessons,
              lesson: lesson,
            ),
          );
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageView(
        icon: Icons.error_outline_rounded,
        title: 'No se pudieron cargar los favoritos',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _loadFavorites,
      );
    }

    if (_favorites.isEmpty) {
      return _MessageView(
        icon: Icons.bookmark_border_rounded,
        title: 'Sin favoritos aún',
        message:
            'Guarda lecciones como favoritas desde el reproductor y aparecerán aquí.',
        actionLabel: 'Actualizar',
        onAction: _loadFavorites,
      );
    }

    // Group favorites by course, preserving insertion order.
    final grouped = <Course, List<_FavoriteEntry>>{};
    for (final entry in _favorites) {
      (grouped[entry.course] ??= <_FavoriteEntry>[]).add(entry);
    }

    // Build a flat list of items: course heading + lesson cards per group.
    final items = <_ListItem>[];
    for (final course in grouped.keys) {
      items.add(_HeadingItem(course));
      for (final entry in grouped[course]!) {
        items.add(_EntryItem(entry));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        itemCount:
            items.length + (_notice != null ? 1 : 0) + (_isRefreshing ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isRefreshing && index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 3),
            );
          }

          final noticeIndex = _isRefreshing ? 1 : 0;
          if (_notice != null && index == noticeIndex) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8DACA)),
              ),
              child: Text(
                _notice!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.deepBrown),
              ),
            );
          }

          final adjustedIndex =
              index - (_isRefreshing ? 1 : 0) - (_notice != null ? 1 : 0);
          final item = items[adjustedIndex];
          if (item is _HeadingItem) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                item.course.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.deepBrown,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          final entryItem = item as _EntryItem;
          final itemKey = _itemKeys.putIfAbsent(
            entryItem.entry.lesson.id,
            () => GlobalKey<_AnimatedFavoriteItemState>(),
          );
          return AnimatedFavoriteItem(
            key: itemKey,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FavoriteCard(
                entry: entryItem.entry,
                onTap: () => _openLesson(entryItem.entry),
                onRemove: () => _removeFavorite(entryItem.entry),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeFavorite(_FavoriteEntry entry) async {
    // Trigger animation first
    final itemKey = _itemKeys[entry.lesson.id];
    if (itemKey?.currentState != null) {
      await itemKey!.currentState!.dismiss();
    }

    if (!mounted) return;

    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) return;

    try {
      await _favoritesStorage.toggleFavorite(user.id, entry.lesson.id);
      if (!mounted) return;
      setState(() {
        _favorites = _favorites
            .where((e) => e.lesson.id != entry.lesson.id)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leccion eliminada de favoritos.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar de favoritos. Intenta de nuevo.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openLesson(_FavoriteEntry entry) async {
    if (entry.lessons.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta lección ya no tiene contenido disponible.'),
        ),
      );
      return;
    }
    final lessonIndex = entry.lessons.indexOf(entry.lesson);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerPage(
          course: entry.course,
          lessons: entry.lessons,
          initialLessonIndex: lessonIndex < 0 ? 0 : lessonIndex,
        ),
      ),
    );
    // Refresh in case the user removed the favorite while in the player.
    _loadFavorites();
  }
}

class _CourseLessonsResult {
  const _CourseLessonsResult({
    required this.course,
    required this.lessons,
    required this.failed,
  });

  final Course course;
  final List<CourseLesson> lessons;
  final bool failed;
}

class _ListItem {}

class _HeadingItem extends _ListItem {
  _HeadingItem(this.course);
  final Course course;
}

class _EntryItem extends _ListItem {
  _EntryItem(this.entry);
  final _FavoriteEntry entry;
}

class _FavoriteEntry {
  const _FavoriteEntry({
    required this.course,
    required this.lessons,
    required this.lesson,
  });

  final Course course;
  final List<CourseLesson> lessons;
  final CourseLesson lesson;
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final _FavoriteEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF6EBD8)],
          ),
          border: Border.all(color: const Color(0xFFE8DACA)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.bookmark_rounded,
                  color: AppTheme.deepBrown,
                  size: 28,
                ),
                tooltip: 'Quitar de favoritos',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.lesson.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppTheme.deepBrown),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
