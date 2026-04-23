import 'dart:convert';

import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesCacheStorage {
  static const String _prefix = 'favorites_cache_v1_user_';

  Future<List<CachedFavoriteCourse>> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$userId');
    if (raw == null || raw.isEmpty) {
      return const <CachedFavoriteCourse>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => CachedFavoriteCourse.fromJson(entry))
          .whereType<CachedFavoriteCourse>()
          .toList();
    } catch (_) {
      return const <CachedFavoriteCourse>[];
    }
  }

  Future<void> save(int userId, List<CachedFavoriteCourse> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$userId',
      jsonEncode(courses.map((entry) => entry.toJson()).toList()),
    );
  }
}

class CachedFavoriteCourse {
  const CachedFavoriteCourse({required this.course, required this.lessons});

  final Course course;
  final List<CourseLesson> lessons;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'course': <String, dynamic>{
        'id': course.id,
        'name': course.name,
        'subtitle': course.subtitle,
        'description': course.description,
        'iconUrl': course.iconUrl,
        'bannerUrl': course.bannerUrl,
        'price': course.price,
        'priceUsd': course.priceUsd,
        'lessonsCount': course.lessonsCount,
        'maxLessons': course.maxLessons,
        'categoryId': course.categoryId,
        'category': course.category,
        'webUrl': course.webUrl,
      },
      'lessons': lessons
          .map(
            (lesson) => <String, dynamic>{
              'id': lesson.id,
              'courseId': lesson.courseId,
              'name': lesson.name,
              'month': lesson.month,
              'hasEvaluation': lesson.hasEvaluation,
              'evaluationRaw': lesson.evaluationRaw,
              'resources': lesson.resources
                  .map(
                    (resource) => <String, dynamic>{
                      'type': resource.type.name,
                      'url': resource.url,
                      'name': resource.name,
                      'order': resource.order,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  static CachedFavoriteCourse? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }

    final courseRaw = json['course'];
    final lessonsRaw = json['lessons'];
    if (courseRaw is! Map<String, dynamic> || lessonsRaw is! List<dynamic>) {
      return null;
    }

    final course = Course(
      id: _toInt(courseRaw['id']),
      name: _toString(courseRaw['name']),
      subtitle: _toString(courseRaw['subtitle']),
      description: _toString(courseRaw['description']),
      iconUrl: _toString(courseRaw['iconUrl']),
      bannerUrl: _toString(courseRaw['bannerUrl']),
      price: _toDouble(courseRaw['price']),
      priceUsd: _toDouble(courseRaw['priceUsd']),
      lessonsCount: _toInt(courseRaw['lessonsCount']),
      maxLessons: _toInt(courseRaw['maxLessons']),
      categoryId: _toInt(courseRaw['categoryId']),
      category: _toString(courseRaw['category']),
      webUrl: _toString(courseRaw['webUrl']),
    );

    final lessons = lessonsRaw
        .map((entry) => _lessonFromJson(entry, course.id))
        .whereType<CourseLesson>()
        .toList();

    return CachedFavoriteCourse(course: course, lessons: lessons);
  }

  static CourseLesson? _lessonFromJson(dynamic json, int fallbackCourseId) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final resourcesRaw = json['resources'];
    if (resourcesRaw is! List<dynamic>) {
      return null;
    }

    final resources = resourcesRaw
        .map(_resourceFromJson)
        .whereType<LessonResource>()
        .toList();

    return CourseLesson(
      id: _toInt(json['id']),
      courseId: _toInt(json['courseId'], fallback: fallbackCourseId),
      name: _toString(json['name']),
      month: _toInt(json['month']),
      resources: resources,
      hasEvaluation: json['hasEvaluation'] == true,
      evaluationRaw: json['evaluationRaw'] is Map<String, dynamic>
          ? json['evaluationRaw'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  static LessonResource? _resourceFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }

    final typeName = _toString(json['type']);
    final type = LessonResourceType.values.where((t) => t.name == typeName);
    if (type.isEmpty) {
      return null;
    }

    return LessonResource(
      type: type.first,
      url: _toString(json['url']),
      name: _toString(json['name']),
      order: _toInt(json['order'], fallback: 999),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _toString(dynamic value) => value?.toString() ?? '';
}
