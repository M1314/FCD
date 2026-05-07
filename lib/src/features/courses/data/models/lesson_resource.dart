import 'package:fcd_app/src/core/utils/json_utils.dart';

enum LessonResourceType { document, audio, video }

class LessonResource {
  const LessonResource({
    required this.type,
    required this.url,
    required this.name,
    required this.order,
    this.courseBannerUrl = '',
    this.courseIconUrl = '',
  });

  final LessonResourceType type;
  final String url;
  final String name;
  final int order;
  final String courseBannerUrl;
  final String courseIconUrl;

  bool get isDocument => type == LessonResourceType.document;
  bool get isAudio => type == LessonResourceType.audio;
  bool get isVideo => type == LessonResourceType.video;

  factory LessonResource.fromJson(
    Map<String, dynamic> json,
    LessonResourceType type,
  ) {
    return LessonResource(
      type: type,
      url: readString(json, const <String>['url', 'src']),
      name: readString(json, const <String>['fileName', 'name', 'title']),
      order: readInt(json, const <String>['order'], fallback: 999),
    );
  }

  LessonResource copyWithCourseMedia({
    required String courseBannerUrl,
    required String courseIconUrl,
  }) {
    return LessonResource(
      type: type,
      url: url,
      name: name,
      order: order,
      courseBannerUrl: courseBannerUrl,
      courseIconUrl: courseIconUrl,
    );
  }
}
