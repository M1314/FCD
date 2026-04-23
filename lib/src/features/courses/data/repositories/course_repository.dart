import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/utils/json_utils.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';

class CourseRepository {
  CourseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Backend endpoint requires a max amount and has no pagination support.
  /// We request a practical upper bound so Temario is not truncated.
  /// If a course ever exceeds this cap, backend pagination will be required.
  static const int allLessonsRequestLimit = 999;

  final ApiClient _apiClient;

  Future<List<Course>> getMyCourses(int userId) async {
    final payload = await _apiClient.get(
      '/course/MyCourses/$userId',
      authenticated: true,
    );
    return _parseCourseList(payload);
  }

  Future<List<Course>> getCourses() async {
    final payload = await _apiClient.get('/course/All/0', authenticated: true);
    return _parseCourseList(payload);
  }

  Future<Course> getCourse(int courseId) async {
    final payload = await _apiClient.get(
      '/course/0/$courseId',
      authenticated: true,
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ?? 'No se pudo obtener el curso.',
        statusCode: status,
      );
    }

    final result = asMap(payload['Result']);
    final courseRaw = asMap(result['curso']);
    if (courseRaw.isEmpty) {
      throw const AppException('No se encontro informacion del curso.');
    }

    return Course.fromJson(courseRaw);
  }

  Future<List<CourseLesson>> getLessonsByCourse({
    required int courseId,
    required int maxLessons,
  }) async {
    final payload = await _apiClient.get(
      '/lesson/course-lessons/$courseId/$maxLessons',
      authenticated: true,
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ??
            'No se pudieron obtener las lecciones.',
        statusCode: status,
      );
    }

    final result = asMap(payload['Result']);
    final lessonsRaw = asList(
      readFirst(result, const <String>['lecciones', 'lessons']),
    );

    return lessonsRaw
        .map((item) => CourseLesson.fromJson(asMap(item)))
        .where((lesson) => lesson.id != 0)
        .toList();
  }

  Future<List<CourseLesson>> getAllLessonsByCourse({required int courseId}) {
    return getLessonsByCourse(
      courseId: courseId,
      maxLessons: allLessonsRequestLimit,
    );
  }

  Future<void> markLessonAsCompleted({
    required int userId,
    required int courseId,
    required int lessonId,
  }) async {
    final payload = await _apiClient.post(
      '/lesson/setLessonUserStatus',
      authenticated: true,
      data: <String, dynamic>{
        'intIdUser': userId,
        'intIdCourse': courseId,
        'intIdLesson': lessonId,
        'status': 1,
      },
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ??
            'No se pudo actualizar el estado de la leccion.',
        statusCode: status,
      );
    }
  }

  Future<Set<int>> getCompletedLessonIds({
    required int userId,
    required int courseId,
  }) async {
    final payload = await _apiClient.get(
      '/lesson/getCompletedLessonsByUser/$userId/$courseId',
      authenticated: true,
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      return <int>{};
    }

    final result = asMap(payload['Result']);
    final lessons = asList(result['lecciones_completadas']);
    return lessons
        .map((item) => readInt(asMap(item), const <String>['idleccion']))
        .where((id) => id > 0)
        .toSet();
  }

  List<Course> _parseCourseList(Map<String, dynamic> payload) {
    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ??
            'No se pudieron obtener los cursos.',
        statusCode: status,
      );
    }

    final result = asMap(payload['Result']);
    final list = asList(readFirst(result, const <String>['cursos', 'courses']));

    return list
        .map((item) => Course.fromJson(asMap(item)))
        .where((course) => course.id != 0)
        .toList();
  }
}
