import 'dart:convert';

class DownloadedFile {
  const DownloadedFile({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
    required this.localPath,
    required this.downloadedAt,
    this.courseName = '',
    this.lessonName = '',
  });

  final String id;
  final String url;
  final String name;
  final String type;
  final String localPath;
  final DateTime downloadedAt;
  final String courseName;
  final String lessonName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'url': url,
      'name': name,
      'type': type,
      'localPath': localPath,
      'downloadedAt': downloadedAt.toIso8601String(),
      'courseName': courseName,
      'lessonName': lessonName,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory DownloadedFile.fromJson(Map<String, dynamic> json) {
    return DownloadedFile(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      localPath: json['localPath']?.toString() ?? '',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt']?.toString() ?? '') ??
          DateTime.now(),
      courseName: json['courseName']?.toString() ?? '',
      lessonName: json['lessonName']?.toString() ?? '',
    );
  }

  factory DownloadedFile.fromRawJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return DownloadedFile.fromJson(map);
  }
}
