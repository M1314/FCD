import 'package:fcd_app/src/features/account/presentation/account_page.dart';
import 'package:fcd_app/src/features/ai/presentation/ai_chat_page.dart';
import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/features/courses/presentation/courses_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/favorites/presentation/favorites_page.dart';
import 'package:flutter/material.dart';
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

  static const List<Widget> _defaultPages = <Widget>[
    CoursesPage(),
    CatalogPage(),
    AiChatPage(),
    FavoritesPage(),
    DownloadsPage(),
    AccountPage(),
  ];

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
    final wrappedPages = List<Widget>.generate(_pages.length, (index) {
      return PrimaryScrollController(
        controller: _tabScrollControllers[index],
        child: _pages[index],
      );
    });
    final downloadController = context.watch<DownloadTaskController>();
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
      body: Column(
        children: <Widget>[
          if (downloadController.isDownloading)
            _BackgroundDownloadBanner(
              progress: downloadController.progress,
              resourceName: downloadController.resourceName,
            ),
          Expanded(child: shellBody),
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
}

class _BackgroundDownloadBanner extends StatelessWidget {
  const _BackgroundDownloadBanner({
    required this.progress,
    required this.resourceName,
  });

  static const Color _bannerColor = Color(0xFFFFF5E8);
  static const Color _bannerBorderColor = Color(0xFFE8DACA);

  final double progress;
  final String resourceName;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Material(
      color: _bannerColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _bannerBorderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Descargando en segundo plano: $resourceName ($percent%)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            ],
          ),
        ),
      ),
    );
  }
}
