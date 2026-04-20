import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/class_lesson.dart';

class MediaDownloadService {
  MediaDownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> download(ClassMedia media) async {
    final response = await _client.get(Uri.parse(media.downloadUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo descargar ${media.title}');
    }

    final directory = await getApplicationDocumentsDirectory();
    final extension = media.type == 'video' ? 'mp4' : 'mp3';
    final safeName = media.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final file = File('${directory.path}/$safeName.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  void dispose() {
    _client.close();
  }
}
