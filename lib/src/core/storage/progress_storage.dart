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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(<String, int>{
      'lessonIndex': lessonIndex,
      'resourceIndex': resourceIndex,
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
        lessonIndex: (map['lessonIndex'] as int?) ?? 0,
        resourceIndex: (map['resourceIndex'] as int?) ?? 0,
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
  const CourseProgress({required this.lessonIndex, required this.resourceIndex});

  final int lessonIndex;
  final int resourceIndex;
}
