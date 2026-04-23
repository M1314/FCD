import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Course.fromJson reads alternate API keys and numeric strings', () {
    final course = Course.fromJson(<String, dynamic>{
      'intId': '7',
      'strNombre': 'Introduccion',
      'strSubtitulo': 'Nivel inicial',
      'strDescripcion': 'Contenido base',
      'fileIcon': 'https://cdn/icon.png',
      'fileBanner': 'https://cdn/banner.png',
      'precio': ' 10.5 ',
      'doublePrecioDolar': ' 12 ',
      'totalLessons': '6',
      'availableLessons': 3,
      'strCategoria': 'General',
      'strUrl': 'https://circulo-dorado.org/curso/7',
    });

    expect(course.id, 7);
    expect(course.name, 'Introduccion');
    expect(course.subtitle, 'Nivel inicial');
    expect(course.description, 'Contenido base');
    expect(course.iconUrl, 'https://cdn/icon.png');
    expect(course.bannerUrl, 'https://cdn/banner.png');
    expect(course.price, 10.5);
    expect(course.priceUsd, 12);
    expect(course.lessonsCount, 6);
    expect(course.maxLessons, 3);
    expect(course.category, 'General');
    expect(course.webUrl, 'https://circulo-dorado.org/curso/7');
  });

  test(
    'categoryName falls back to mapped categoryId when category is empty',
    () {
      final course = Course.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Curso',
        'categoryId': 1,
      });

      expect(course.categoryName, 'Formación Básica');
    },
  );

  test(
    'categoryName falls back to General when id is unknown and empty category',
    () {
      final course = Course.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Curso',
        'categoryId': 999,
      });

      expect(course.categoryName, 'General');
    },
  );
}
