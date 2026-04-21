import 'package:fcd_app/src/core/storage/favorites_storage.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesStorage _favoritesStorage = FavoritesStorage();

  bool _loading = true;
  String? _error;

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
        _error = 'Sesion no valida. Vuelve a iniciar sesion.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Get the set of favorited lesson IDs.
      final favoriteIds = await _favoritesStorage.getFavorites(user.id);

      if (favoriteIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _favorites = <_FavoriteEntry>[];
          _loading = false;
        });
        return;
      }

      // 2. Fetch all user courses.
      final courses = await session.courseRepository.getMyCourses(user.id);

      // 3. For each course, fetch lessons and find favorited ones.
      final entries = <_FavoriteEntry>[];
      for (final course in courses) {
        if (!mounted) return;
        final maxLessons = course.maxLessons <= 0
            ? (course.lessonsCount <= 0 ? 12 : course.lessonsCount)
            : course.maxLessons;
        final lessons = await session.courseRepository.getLessonsByCourse(
          courseId: course.id,
          maxLessons: maxLessons,
        );
        for (final lesson in lessons) {
          if (favoriteIds.contains(lesson.id)) {
            entries.add(_FavoriteEntry(course: course, lessons: lessons, lesson: lesson));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _favorites = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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
        title: 'Sin favoritos aun',
        message:
            'Guarda lecciones como favoritas desde el reproductor y apareceran aqui.',
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
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FavoriteCard(
              entry: entryItem.entry,
              onTap: () => _openLesson(entryItem.entry),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLesson(_FavoriteEntry entry) async {
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
  const _FavoriteCard({required this.entry, required this.onTap});

  final _FavoriteEntry entry;
  final VoidCallback onTap;

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
              const Icon(
                Icons.bookmark_rounded,
                color: AppTheme.deepBrown,
                size: 28,
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
              const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText),
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
