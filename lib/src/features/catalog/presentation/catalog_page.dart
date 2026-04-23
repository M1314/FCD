import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/network_image_tile.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  bool _loading = true;
  String? _error;
  List<Course> _allCourses = <Course>[];
  List<Course> _filtered = <Course>[];
  final TextEditingController _searchController = TextEditingController();

  /// Ordered list of category names (preserves insertion / API order).
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
          ? _allCourses
          : _allCourses
              .where(
                (course) =>
                    course.name.toLowerCase().contains(query) ||
                    course.subtitle.toLowerCase().contains(query) ||
                    course.category.toLowerCase().contains(query),
              )
              .toList();
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final courses = await session.courseRepository.getCourses();
      if (!mounted) {
        return;
      }

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

      setState(() {
        _allCourses = courses;
        _filtered = courses;
        _categoryOrder = categoryOrder;
        _grouped = grouped;
        _loading = false;
      });
      _applyFilter();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CatalogMessageView(
        title: 'No se pudo cargar el catalogo',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _loadCourses,
      );
    }

    return Column(
      children: <Widget>[
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar cursos...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isSearching = _searchController.text.trim().isNotEmpty;

    if (isSearching) {
      return _buildFlatList(_filtered);
    }

    return _buildGroupedList();
  }

  /// Flat list used while the user is searching.
  Widget _buildFlatList(List<Course> courses) {
    if (courses.isEmpty) {
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        itemCount: courses.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _CatalogCard(course: courses[index]),
      ),
    );
  }

  /// Grouped list used when no search query is active.
  Widget _buildGroupedList() {
    if (_allCourses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay cursos disponibles.', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          for (final category in _categoryOrder)
            ...<Widget>[
              _CategoryHeader(title: category),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final courses = _grouped[category]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CatalogCard(course: courses[index]),
                      );
                    },
                    childCount: _grouped[category]!.length,
                  ),
                ),
              ),
            ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 18)),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
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
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.deepBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final priceFormatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    final hasPrice = course.price > 0;

    return Ink(
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
                NetworkImageTile(
                  url: course.iconUrl.isNotEmpty
                      ? course.iconUrl
                      : course.bannerUrl,
                  width: 80,
                  height: 80,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        course.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 20),
                      ),
                      if (course.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          course.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.mutedText),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          if (course.lessonsCount > 0)
                            _Chip(
                              icon: Icons.menu_book_rounded,
                              text: '${course.lessonsCount} lecciones',
                            ),
                          if (hasPrice)
                            _Chip(
                              icon: Icons.sell_rounded,
                              text: priceFormatter.format(course.price),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (course.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                course.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openWeb(context),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Ver en web'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWeb(BuildContext context) async {
    final uri = Uri.parse('https://circulo-dorado.org');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
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
          Icon(icon, size: 15, color: AppTheme.deepBrown),
          const SizedBox(width: 5),
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

class _CatalogMessageView extends StatelessWidget {
  const _CatalogMessageView({
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
              Icons.storefront_rounded,
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
