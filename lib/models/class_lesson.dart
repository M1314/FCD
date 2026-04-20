class ClassMedia {
  const ClassMedia({
    required this.id,
    required this.title,
    required this.type,
    required this.streamUrl,
    required this.downloadUrl,
    required this.duration,
  });

  final String id;
  final String title;
  final String type;
  final String streamUrl;
  final String downloadUrl;
  final String duration;

  factory ClassMedia.fromJson(Map<String, dynamic> json) {
    return ClassMedia(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      streamUrl: json['streamUrl'] as String,
      downloadUrl: json['downloadUrl'] as String,
      duration: json['duration'] as String,
    );
  }
}

class ClassLesson {
  const ClassLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.media,
  });

  final String id;
  final String title;
  final String description;
  final List<ClassMedia> media;

  factory ClassLesson.fromJson(Map<String, dynamic> json) {
    final mediaList = (json['media'] as List<dynamic>)
        .map((entry) => ClassMedia.fromJson(entry as Map<String, dynamic>))
        .toList();

    return ClassLesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      media: mediaList,
    );
  }
}
