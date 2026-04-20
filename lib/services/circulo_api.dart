import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/class_lesson.dart';

class CirculoApi {
  CirculoApi({http.Client? client}) : _client = client ?? http.Client();

  static const String defaultBaseUrl = 'https://www.circulo-dorado.org';
  final http.Client _client;

  Future<List<ClassLesson>> fetchClasses({String? baseUrl}) async {
    final uri = Uri.parse('${baseUrl ?? defaultBaseUrl}/api/classes');

    try {
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = jsonDecode(response.body) as List<dynamic>;
        return parsed
            .map((entry) => ClassLesson.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
    } catch (error) {
      debugPrint('CirculoApi.fetchClasses fallback: $error');
    }

    return _fallbackLessons;
  }

  void dispose() {
    _client.close();
  }
}

const List<ClassLesson> _fallbackLessons = [
  ClassLesson(
    id: 'portal-1',
    title: 'Portal - Clase 1',
    description: 'Introducción y respiración consciente.',
    media: [
      ClassMedia(
        id: 'portal-1-video',
        title: 'Video principal',
        type: 'video',
        streamUrl:
            'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        downloadUrl:
            'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        duration: '10:34',
      ),
      ClassMedia(
        id: 'portal-1-audio',
        title: 'Audio guiado',
        type: 'audio',
        streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        duration: '06:40',
      ),
    ],
  ),
  ClassLesson(
    id: 'portal-2',
    title: 'Portal - Clase 2',
    description: 'Visualización y revisión diaria.',
    media: [
      ClassMedia(
        id: 'portal-2-video',
        title: 'Video de práctica',
        type: 'video',
        streamUrl:
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        downloadUrl:
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        duration: '10:53',
      ),
      ClassMedia(
        id: 'portal-2-audio',
        title: 'Audio de repaso',
        type: 'audio',
        streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        duration: '05:18',
      ),
    ],
  ),
];
