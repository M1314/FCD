import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last lesson index and resource index for each course so the
/// user can resume exactly where they left off.
class ProgressStorage {
  static const String _prefix = 'course_progress_v1_';

  Future<void> saveProgress({
    required int courseId,
    required int lessonIndex,
    required int resourceIndex,
    int mediaPositionMs = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(<String, int>{
      'lessonIndex': lessonIndex,
      'resourceIndex': resourceIndex,
      'mediaPositionMs': mediaPositionMs,
    });
    await prefs.setString('$_prefix$courseId', data);
  }

  Future<CourseProgress?> getProgress(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$courseId');
    if (raw == null) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CourseProgress(
        lessonIndex: _readInt(map['lessonIndex']),
        resourceIndex: _readInt(map['resourceIndex']),
        mediaPositionMs: _readInt(map['mediaPositionMs']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearProgress(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$courseId');
  }
}

class CourseProgress {
  const CourseProgress({
    required this.lessonIndex,
    required this.resourceIndex,
    required this.mediaPositionMs,
  });

  final int lessonIndex;
  final int resourceIndex;
  final int mediaPositionMs;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}
