import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/favorites/data/favorites_cache_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FavoritesCacheStorage', () {
    test('save and read roundtrip keeps course and lessons data', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = FavoritesCacheStorage();

      const snapshot = CachedFavoriteCourse(
        course: Course(
          id: 7,
          name: 'Curso',
          subtitle: 'Sub',
          description: 'Desc',
          iconUrl: 'https://example.com/icon.png',
          bannerUrl: 'https://example.com/banner.png',
          price: 10,
          priceUsd: 12,
          lessonsCount: 1,
          maxLessons: 4,
          categoryId: 2,
          category: 'Cursos',
          webUrl: 'https://example.com/course',
        ),
        lessons: <CourseLesson>[
          CourseLesson(
            id: 99,
            courseId: 7,
            name: 'Leccion 1',
            month: 1,
            resources: <LessonResource>[
              LessonResource(
                type: LessonResourceType.video,
                url: 'https://example.com/video.mp4',
                name: 'Video',
                order: 1,
              ),
            ],
            hasEvaluation: true,
            evaluationRaw: <String, dynamic>{'id': 123},
          ),
        ],
      );

      await storage.save(5, const <CachedFavoriteCourse>[snapshot]);

      final loaded = await storage.read(5);

      expect(loaded, hasLength(1));
      expect(loaded.first.course.id, 7);
      expect(loaded.first.course.name, 'Curso');
      expect(loaded.first.lessons, hasLength(1));
      expect(loaded.first.lessons.first.id, 99);
      expect(loaded.first.lessons.first.resources, hasLength(1));
      expect(loaded.first.lessons.first.resources.first.url, contains('video'));
    });

    test('read returns empty list for malformed cache', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'favorites_cache_v1_user_5': 'not-json',
      });
      final storage = FavoritesCacheStorage();

      final loaded = await storage.read(5);

      expect(loaded, isEmpty);
    });
  });
}
