import 'dart:io';

import 'package:flutter/foundation.dart';
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
    final extension = _resolveExtension(media, response);
    final sanitizedName = media.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final sanitizedId = media.id
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safeName = sanitizedName.isEmpty
        ? (sanitizedId.isEmpty ? 'media-file' : sanitizedId)
        : sanitizedName;
    if (safeName == 'media-file') {
      debugPrint('MediaDownloadService fallback filename used for media: ${media.id}');
    }
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/$safeName-$suffix.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  void dispose() {
    _client.close();
  }

  String _resolveExtension(ClassMedia media, http.Response response) {
    final urlPath = Uri.parse(media.downloadUrl).path;
    final dotIndex = urlPath.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < urlPath.length - 1) {
      final raw = urlPath.substring(dotIndex + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(raw)) {
        return raw;
      }
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('mpeg')) {
      return 'mp3';
    }
    if (contentType.contains('ogg')) {
      return 'ogg';
    }
    if (contentType.contains('webm')) {
      return 'webm';
    }

    return media.type == 'video' ? 'mp4' : 'mp3';
  }
}
