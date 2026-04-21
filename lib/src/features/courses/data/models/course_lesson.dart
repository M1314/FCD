import 'package:fcd_app/src/core/utils/json_utils.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.courseId,
    required this.name,
    required this.month,
    required this.resources,
    required this.hasEvaluation,
    required this.evaluationRaw,
  });

  final int id;
  final int courseId;
  final String name;
  final int month;
  final List<LessonResource> resources;
  final bool hasEvaluation;
  final Map<String, dynamic> evaluationRaw;

  List<LessonResource> get documents =>
      resources.where((resource) => resource.isDocument).toList();

  List<LessonResource> get videos =>
      resources.where((resource) => resource.isVideo).toList();

  List<LessonResource> get audios =>
      resources.where((resource) => resource.isAudio).toList();

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    final docs =
        decodeJsonArray(readFirst(json, <String>['documento', 'document']))
            .map(
              (resource) => LessonResource.fromJson(
                asMap(resource),
                LessonResourceType.document,
              ),
            )
            .toList();
    final audios = decodeJsonArray(json['audio'])
        .map(
          (resource) => LessonResource.fromJson(
            asMap(resource),
            LessonResourceType.audio,
          ),
        )
        .toList();
    final videos = decodeJsonArray(json['video'])
        .map(
          (resource) => LessonResource.fromJson(
            asMap(resource),
            LessonResourceType.video,
          ),
        )
        .toList();

    final resources = <LessonResource>[...docs, ...videos, ...audios]
      ..sort((a, b) => a.order.compareTo(b.order));

    return CourseLesson(
      id: readInt(json, const <String>['idleccion', 'id']),
      courseId: readInt(json, const <String>['idcurso', 'courseId']),
      name: readString(json, const <String>['nombre', 'strNombre', 'name']),
      month: readInt(json, const <String>['intMes', 'month']),
      resources: resources,
      hasEvaluation: readBool(json, const <String>['hasEvaluation']),
      evaluationRaw: asMap(json['evaluation']),
    );
  }
}
