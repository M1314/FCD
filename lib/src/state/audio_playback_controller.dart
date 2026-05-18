import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlaybackController extends ChangeNotifier {
  AudioPlayer? _player;
  int? _courseId;
  int? _lessonIndex;
  int? _resourceIndex;
  String? _resourceTitle;
  String? _courseTitle;
  Course? _course;
  List<CourseLesson>? _lessons;
  DownloadedFile? _downloadedFile;

  AudioPlayer? get player => _player;
  int? get courseId => _courseId;
  int? get lessonIndex => _lessonIndex;
  int? get resourceIndex => _resourceIndex;
  String? get resourceTitle => _resourceTitle;
  String? get courseTitle => _courseTitle;
  Course? get course => _course;
  List<CourseLesson>? get lessons => _lessons;
  DownloadedFile? get downloadedFile => _downloadedFile;

  String? get activeMediaResourceKey {
    if (_courseId == null || _lessonIndex == null || _resourceIndex == null) {
      return null;
    }
    return '${_courseId!}:${_lessonIndex!}:${_resourceIndex!}';
  }

  Future<void> stopAndClear() async {
    final player = _player;
    if (player != null) {
      await player.stop();
    }
    clearSession();
  }

  void clearSession() {
    _player = null;
    _courseId = null;
    _lessonIndex = null;
    _resourceIndex = null;
    _resourceTitle = null;
    _courseTitle = null;
    _course = null;
    _lessons = null;
    _downloadedFile = null;
    notifyListeners();
  }

  void setSession({
    required AudioPlayer player,
    int? courseId,
    int? lessonIndex,
    int? resourceIndex,
    required String resourceTitle,
    String? courseTitle,
    Course? course,
    List<CourseLesson>? lessons,
  }) {
    _player = player;
    _courseId = courseId;
    _lessonIndex = lessonIndex;
    _resourceIndex = resourceIndex;
    _resourceTitle = resourceTitle;
    _courseTitle = courseTitle;
    _course = course;
    _lessons = lessons;
    _downloadedFile = null;
    notifyListeners();
  }

  void setDownloadedSession({
    required AudioPlayer player,
    required DownloadedFile file,
    required String resourceTitle,
  }) {
    _player = player;
    _courseId = null;
    _lessonIndex = null;
    _resourceIndex = null;
    _resourceTitle = resourceTitle;
    _courseTitle = null;
    _course = null;
    _lessons = null;
    _downloadedFile = file;
    notifyListeners();
  }
}
