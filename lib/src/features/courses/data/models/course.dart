import 'package:fcd_app/src/core/utils/json_utils.dart';

/// Maps the numeric idCategoria from the API to a human-readable category name.
const Map<int, String> courseCategoryNames = <int, String>{
  1: 'Formación Básica',
  2: 'Cursos de Qabalah',
  3: 'Curso Principal',
  20: 'Cursos Varios',
  22: 'Talleres y Conferencias',
  23: 'Misterios Egipcios',
};

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.iconUrl,
    required this.bannerUrl,
    required this.price,
    required this.priceUsd,
    required this.lessonsCount,
    required this.maxLessons,
    this.categoryId = 0,
    this.category = '',
    this.webUrl = '',
  });

  final int id;
  final String name;
  final String subtitle;
  final String description;
  final String iconUrl;
  final String bannerUrl;
  final double price;
  final double priceUsd;
  final int lessonsCount;
  final int maxLessons;
  final int categoryId;
  final String category;
  final String webUrl;

  /// Returns the resolved category name, preferring the API string if present,
  /// falling back to the hardcoded map, then a generic label.
  String get categoryName {
    if (category.isNotEmpty) return category;
    return courseCategoryNames[categoryId] ?? 'General';
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    final lessonsCount = _readLessonsCount(json);
    return Course(
      id: readInt(json, const <String>['idcurso', 'intId', 'id']),
      name: readString(json, const <String>['nombre', 'strNombre', 'name']),
      subtitle: readString(json, const <String>[
        'subtitulo',
        'strSubtitulo',
        'subtitle',
      ]),
      description: readString(json, const <String>[
        'descripcion',
        'strDescripcion',
        'description',
      ]),
      iconUrl: readString(json, const <String>['icono', 'icon', 'fileIcon']),
      bannerUrl: readString(json, const <String>[
        'portada',
        'banner',
        'fileBanner',
      ]),
      price: readDouble(json, const <String>['doublePrecio', 'precio']),
      priceUsd: readDouble(json, const <String>['doublePrecioDolar']),
      lessonsCount: lessonsCount,
      maxLessons: readInt(json, const <String>[
        'lecciones_por_mes',
        'intCantidadMeses',
        'maxLessons',
        'availableLessons',
      ]),
      categoryId: readInt(json, const <String>['idCategoria', 'categoryId']),
      category: readString(json, const <String>[
        'categoria',
        'strCategoria',
        'category',
      ]),
      webUrl: readString(json, const <String>[
        'url',
        'strUrl',
        'link',
        'enlace',
        'courseUrl',
      ]),
    );
  }
}

int _readLessonsCount(Map<String, dynamic> json) {
  const keys = <String>[
    'total_lecciones_curso',
    'total_lecciones',
    'totalLecciones',
    'intTotalLecciones',
    'intCantidadLecciones',
    'intNumeroLecciones',
    'intNumberOfLessons',
    'lessonsCount',
    'totalLessons',
    'cantidad_lecciones',
    'cantidadLecciones',
    'numero_lecciones',
    'numeroLecciones',
  ];

  final explicit = _parseLessonCountValue(readFirst(json, keys));
  if (explicit != null) {
    return explicit;
  }

  final lessons = readFirst(json, const <String>['lecciones', 'lessons']);
  final listCount = _parseLessonCountValue(lessons);
  if (listCount != null) {
    return listCount;
  }

  final inferred = _inferLessonCount(json);
  return inferred ?? 0;
}

int? _parseLessonCountValue(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is List) {
    return raw.length;
  }
  if (raw is String) {
    final trimmed = raw.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return parsed;
    }
    final decoded = decodeJsonArray(trimmed);
    if (decoded.isNotEmpty) {
      return decoded.length;
    }
  }
  return null;
}

int? _inferLessonCount(Map<String, dynamic> json) {
  int? best;
  json.forEach((key, value) {
    final lower = key.toLowerCase();
    if (!lower.contains('leccion') && !lower.contains('lesson')) {
      return;
    }
    final parsed = _parseLessonCountValue(value);
    if (parsed == null) {
      return;
    }
    if (best == null || parsed > best!) {
      best = parsed;
    }
  });
  return best;
}
