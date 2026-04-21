import 'package:fcd_app/src/features/account/presentation/account_page.dart';
import 'package:fcd_app/src/features/ai/presentation/ai_chat_page.dart';
import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/features/courses/presentation/courses_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/features/favorites/presentation/favorites_page.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_titleForIndex(_selectedIndex)),
            Text(
              _subtitleForIndex(_selectedIndex),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
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
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const <NavigationDestination>[
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
          ],
        ),
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

  String _subtitleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Explora nuevas rutas de aprendizaje';
      case 2:
        return 'Resuelve dudas y profundiza';
      case 3:
        return 'Tus lecciones guardadas';
      case 4:
        return 'Contenido disponible sin conexion';
      case 5:
        return 'Gestiona tu sesion y perfil';
      default:
        return 'Retoma tu practica donde la dejaste';
    }
  }
}
