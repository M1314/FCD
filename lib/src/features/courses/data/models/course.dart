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

const List<String> _lessonCountTokens = <String>[
  'total',
  'cantidad',
  'numero',
  'count',
  'cant',
  'num',
];

const List<String> _lessonIdTokens = <String>[
  'idleccion',
  'lesson_id',
  'idlesson',
];

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
    if (trimmed.startsWith('[')) {
      // Some API responses return a JSON-encoded list string for lessons.
      final decoded = decodeJsonArray(trimmed);
      return decoded.length;
    }
  }
  return null;
}

int? _inferLessonCount(Map<String, dynamic> json) {
  int? preferred;
  int? preferredPriority;
  int? fallback;

  for (final entry in json.entries) {
    final lower = entry.key.toLowerCase();
    if (!lower.contains('leccion') && !lower.contains('lesson')) {
      continue;
    }
    if (_isIdLikeKey(lower)) {
      continue;
    }
    final parsed = _parseLessonCountValue(entry.value);
    if (parsed == null) {
      continue;
    }

    final priority = _priorityForKey(lower, _lessonCountTokens);
    if (priority != null) {
      final currentPriority = preferredPriority;
      if (currentPriority == null || priority < currentPriority) {
        preferredPriority = priority;
        preferred = parsed;
        if (priority == 0) {
          return preferred;
        }
      }
      continue;
    }

    fallback ??= parsed;
  }
  return preferred ?? fallback;
}

int? _priorityForKey(String key, List<String> tokens) {
  for (var i = 0; i < tokens.length; i++) {
    if (key.contains(tokens[i])) {
      return i;
    }
  }
  return null;
}

bool _isIdLikeKey(String key) {
  if (_lessonIdTokens.contains(key)) {
    return true;
  }
  if (key.endsWith('_id') || key.startsWith('id_')) {
    return true;
  }
  if (key.startsWith('id')) {
    // Treat id-prefixed keys with count tokens as counts, not identifiers.
    return !_containsLessonCountToken(key);
  }
  return false;
}

bool _containsLessonCountToken(String key) {
  for (final token in _lessonCountTokens) {
    if (key.contains(token)) {
      return true;
    }
  }
  return false;
}
