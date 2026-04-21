import 'package:fcd_app/src/core/utils/json_utils.dart';

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
    this.category = '',
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
  final String category;

  factory Course.fromJson(Map<String, dynamic> json) {
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
      lessonsCount: readInt(json, const <String>[
        'total_lecciones_curso',
        'intNumberOfLessons',
        'lessonsCount',
        'totalLessons',
      ]),
      maxLessons: readInt(json, const <String>[
        'lecciones_por_mes',
        'intCantidadMeses',
        'maxLessons',
        'availableLessons',
      ]),
      category: readString(json, const <String>[
        'categoria',
        'strCategoria',
        'category',
      ]),
    );
  }
}
