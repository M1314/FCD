import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/features/courses/data/repositories/course_repository.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../test_helpers/fake_api_client.dart';

class TestSessionController extends SessionController {
  TestSessionController(this._courseRepository) : super();

  final CourseRepository _courseRepository;

  @override
  CourseRepository get courseRepository => _courseRepository;
}

Widget _buildSubject(CourseRepository repository) {
  return ChangeNotifierProvider<SessionController>.value(
    value: TestSessionController(repository),
    child: const MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: CatalogPage())),
    ),
  );
}

void main() {
  testWidgets(
    'CatalogPage shows lesson counts from API and falls back on errors',
    (tester) async {
      final recordedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        recordedErrors.add(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      final apiClient = FakeApiClient(
        onGet: (path, {queryParameters, authenticated = false}) async {
          if (path == '/course/All/0') {
            return <String, dynamic>{
              'intResponse': 200,
              'Result': <String, dynamic>{
                'cursos': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'intId': 1,
                    'strNombre': 'Curso Uno',
                    'strSubtitulo': 'Subtitulo',
                    'strDescripcion': 'Descripcion',
                    'fileIcon': '',
                    'fileBanner': '',
                    'precio': 0,
                    'doublePrecioDolar': 0,
                    'totalLessons': 1,
                    'availableLessons': 0,
                    'strCategoria': 'Categoria',
                  },
                  <String, dynamic>{
                    'intId': 2,
                    'strNombre': 'Curso Dos',
                    'strSubtitulo': '',
                    'strDescripcion': '',
                    'fileIcon': '',
                    'fileBanner': '',
                    'precio': 0,
                    'doublePrecioDolar': 0,
                    'totalLessons': 5,
                    'availableLessons': 0,
                    'strCategoria': 'Categoria',
                  },
                ],
              },
            };
          }
          if (path ==
              '/lesson/course-lessons/1/${CourseRepository.allLessonsRequestLimit}') {
            return <String, dynamic>{
              'intResponse': 200,
              'Result': <String, dynamic>{
                'lecciones': <Map<String, dynamic>>[
                  <String, dynamic>{'idleccion': 1, 'nombre': 'L1'},
                  <String, dynamic>{'idleccion': 2, 'nombre': 'L2'},
                  <String, dynamic>{'idleccion': 3, 'nombre': 'L3'},
                ],
              },
            };
          }
          if (path ==
              '/lesson/course-lessons/2/${CourseRepository.allLessonsRequestLimit}') {
            return <String, dynamic>{'intResponse': 500, 'strAnswer': 'error'};
          }
          throw UnimplementedError('Unexpected path: $path');
        },
      );
      final repository = CourseRepository(apiClient: apiClient);

      await tester.pumpWidget(_buildSubject(repository));
      await tester.pumpAndSettle();

      expect(find.text('3 lecciones'), findsOneWidget);
      expect(find.text('5 lecciones'), findsOneWidget);
      expect(recordedErrors, isNotEmpty);
    },
  );
}
