import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/network_image_tile.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/presentation/course_summary_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  bool _loading = true;
  String? _error;
  List<Course> _courses = <Course>[];
  List<Course> _filtered = <Course>[];
  final TextEditingController _searchController = TextEditingController();

  /// Ordered list of category names (preserves API order).
  List<String> _categoryOrder = <String>[];

  /// Map from category name → courses in that category.
  Map<String, List<Course>> _grouped = <String, List<Course>>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _courses
          : _courses
                .where(
                  (course) =>
                      course.name.toLowerCase().contains(query) ||
                      course.subtitle.toLowerCase().contains(query),
                )
                .toList();
    });
  }

  void _buildGrouping(List<Course> courses) {
    final categoryOrder = <String>[];
    final grouped = <String, List<Course>>{};
    for (final course in courses) {
      final cat = course.categoryName;
      if (!grouped.containsKey(cat)) {
        categoryOrder.add(cat);
        grouped[cat] = <Course>[];
      }
      grouped[cat]!.add(course);
    }
    _categoryOrder = categoryOrder;
    _grouped = grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CoursesMessageView(
        title: 'No se pudieron cargar tus cursos',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _loadCourses,
      );
    }

    if (_courses.isEmpty) {
      return _CoursesMessageView(
        title: 'Aun no tienes cursos activos',
        message:
            'Cuando adquieras un curso en circulo-dorado.org aparecera aqui.',
        actionLabel: 'Actualizar',
        onAction: _loadCourses,
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Buscar mis cursos...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _searchController.clear,
                    )
                  : null,
            ),
          ),
        ),
        Expanded(child: isSearching ? _buildFlatList() : _buildGroupedList()),
      ],
    );
  }

  Widget _buildFlatList() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se encontraron cursos con ese criterio.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        itemCount: _filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final course = _filtered[index];
          return _CourseCard(course: course, onTap: () => _openCourse(course));
        },
      ),
    );
  }

  Widget _buildGroupedList() {
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          for (final category in _categoryOrder) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.deepBrown,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.deepBrown,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final course = _grouped[category]![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CourseCard(
                      course: course,
                      onTap: () => _openCourse(course),
                    ),
                  );
                }, childCount: _grouped[category]!.length),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 18)),
        ],
      ),
    );
  }

  Future<void> _loadCourses() async {
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
      final courses = await session.courseRepository.getMyCourses(user.id);
      if (!mounted) return;
      _buildGrouping(courses);
      setState(() {
        _courses = courses;
        _loading = false;
      });
      _applyFilter();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openCourse(Course course) async {
    final session = context.read<SessionController>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final lessons = await session.courseRepository.getAllLessonsByCourse(
        courseId: course.id,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CourseSummaryPage(course: course, lessons: lessons),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el curso: $error')),
      );
    }
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF6EBD8)],
          ),
          border: Border.all(color: const Color(0xFFE8DACA)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _CourseArtwork(course: course),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          course.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 25),
                        ),
                        const SizedBox(height: 2),
                        if (course.subtitle.isNotEmpty)
                          Text(
                            course.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.mutedText),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _Chip(
                              icon: Icons.menu_book_rounded,
                              text: '${course.lessonsCount} lecciones',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                course.description.isEmpty
                    ? 'Continua tu ruta de estudio en la app.'
                    : course.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Entrar al curso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseArtwork extends StatelessWidget {
  const _CourseArtwork({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final url = course.iconUrl.isNotEmpty ? course.iconUrl : course.bannerUrl;

    return NetworkImageTile(url: url, width: 80, height: 80, borderRadius: 12);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E4D1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppTheme.deepBrown),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.deepBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesMessageView extends StatelessWidget {
  const _CoursesMessageView({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

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
            const Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: AppTheme.deepBrown,
            ),
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
