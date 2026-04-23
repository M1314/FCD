import 'package:fcd_app/src/features/account/presentation/account_page.dart';
import 'package:fcd_app/src/features/ai/presentation/ai_chat_page.dart';
import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/features/courses/presentation/courses_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/features/favorites/presentation/favorites_page.dart';
import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
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
          label: 'Catalogo',
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
          label: Text('Catalogo'),
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

    final content = IndexedStack(index: _selectedIndex, children: _pages);

    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_selectedIndex))),
      body: isTablet
          ? Row(
              children: <Widget>[
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    destinations: _railDestinations,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SafeArea(left: false, child: content),
                ),
              ],
            )
          : SafeArea(child: content),
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: _bottomDestinations,
            ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Catalogo';
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
}
