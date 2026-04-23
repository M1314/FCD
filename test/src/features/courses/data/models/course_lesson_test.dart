import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CourseLesson.fromJson decodes and sorts lesson resources', () {
    final lesson = CourseLesson.fromJson(<String, dynamic>{
      'idleccion': 11,
      'idcurso': 4,
      'nombre': 'Leccion 1',
      'documento':
          '[{"url":"https://docs/doc.pdf","fileName":"Doc","order":"3"}]',
      'video': <Map<String, dynamic>>[
        <String, dynamic>{
          'url': 'https://video/lesson.mp4',
          'fileName': 'Video',
          'order': 2,
        },
      ],
      'audio': <Map<String, dynamic>>[
        <String, dynamic>{
          'url': 'https://audio/lesson.mp3',
          'fileName': 'Audio',
          'order': 1,
        },
      ],
    });

    expect(lesson.resources, hasLength(3));
    expect(lesson.resources.map((resource) => resource.name), <String>[
      'Audio',
      'Video',
      'Doc',
    ]);
    expect(lesson.documents, hasLength(1));
    expect(lesson.videos, hasLength(1));
    expect(lesson.audios, hasLength(1));
  });
}
