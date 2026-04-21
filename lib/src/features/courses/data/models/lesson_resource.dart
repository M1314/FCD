import 'package:fcd_app/src/core/utils/json_utils.dart';

enum LessonResourceType { document, audio, video }

class LessonResource {
  const LessonResource({
    required this.type,
    required this.url,
    required this.name,
    required this.order,
  });

  final LessonResourceType type;
  final String url;
  final String name;
  final int order;

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
}
