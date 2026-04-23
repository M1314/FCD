import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/features/courses/data/repositories/course_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test_helpers/fake_api_client.dart';

void main() {
  group('CourseRepository', () {
    test(
      'markLessonAsCompleted sends expected payload and succeeds on 200',
      () async {
        final apiClient = FakeApiClient(
          onPost: (_, {data, queryParameters, authenticated = false}) async =>
              <String, dynamic>{'intResponse': 200},
        );
        final repository = CourseRepository(apiClient: apiClient);

        await repository.markLessonAsCompleted(
          userId: 4,
          courseId: 8,
          lessonId: 12,
        );

        expect(apiClient.postCalls, hasLength(1));
        final call = apiClient.postCalls.single;
        expect(call.path, '/lesson/setLessonUserStatus');
        expect(call.authenticated, isTrue);
        expect(call.data, <String, dynamic>{
          'intIdUser': 4,
          'intIdCourse': 8,
          'intIdLesson': 12,
          'status': 1,
        });
      },
    );

    test(
      'markLessonAsCompleted throws AppException when status is not 200',
      () async {
        final apiClient = FakeApiClient(
          onPost: (_, {data, queryParameters, authenticated = false}) async =>
              <String, dynamic>{
                'intResponse': 500,
                'strAnswer': 'Fallo al guardar',
              },
        );
        final repository = CourseRepository(apiClient: apiClient);

        expect(
          () => repository.markLessonAsCompleted(
            userId: 4,
            courseId: 8,
            lessonId: 12,
          ),
          throwsA(
            isA<AppException>()
                .having((error) => error.message, 'message', 'Fallo al guardar')
                .having((error) => error.statusCode, 'statusCode', 500),
          ),
        );
      },
    );

    test(
      'getAllLessonsByCourse uses allLessonsRequestLimit in endpoint path',
      () async {
        final apiClient = FakeApiClient(
          onGet: (_, {queryParameters, authenticated = false}) async =>
              <String, dynamic>{
                'intResponse': 200,
                'Result': <String, dynamic>{'lecciones': <dynamic>[]},
              },
        );
        final repository = CourseRepository(apiClient: apiClient);

        await repository.getAllLessonsByCourse(courseId: 21);

        expect(apiClient.getCalls, hasLength(1));
        expect(
          apiClient.getCalls.single.path,
          '/lesson/course-lessons/21/${CourseRepository.allLessonsRequestLimit}',
        );
        expect(apiClient.getCalls.single.authenticated, isTrue);
      },
    );

    test('getLessonsByCourse filters out lessons with invalid id', () async {
      final apiClient = FakeApiClient(
        onGet: (_, {queryParameters, authenticated = false}) async =>
            <String, dynamic>{
              'intResponse': 200,
              'Result': <String, dynamic>{
                'lecciones': <Map<String, dynamic>>[
                  <String, dynamic>{'idleccion': 0, 'nombre': 'Invalida'},
                  <String, dynamic>{'idleccion': 9, 'nombre': 'Valida'},
                ],
              },
            },
      );
      final repository = CourseRepository(apiClient: apiClient);

      final lessons = await repository.getLessonsByCourse(
        courseId: 21,
        maxLessons: 3,
      );

      expect(lessons, hasLength(1));
      expect(lessons.single.id, 9);
      expect(lessons.single.name, 'Valida');
    });
  });
}
