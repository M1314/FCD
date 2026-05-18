import 'dart:async';

import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

typedef PersistCourseProgressCallback =
    Future<void> Function({
      required int courseId,
      required int lessonIndex,
      required int resourceIndex,
      required int mediaPositionMs,
    });

class AudioPlaybackController extends ChangeNotifier
    with WidgetsBindingObserver {
  AudioPlaybackController() {
    WidgetsBinding.instance.addObserver(this);
  }

  AudioPlayer? _player;
  int? _courseId;
  int? _lessonIndex;
  int? _resourceIndex;
  String? _resourceTitle;
  String? _courseTitle;
  Course? _course;
  List<CourseLesson>? _lessons;
  DownloadedFile? _downloadedFile;
  PersistCourseProgressCallback? _persistCourseProgress;

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
    await _persistCurrentCourseProgress();
    if (player != null) {
      await player.stop();
      await player.dispose();
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
    _persistCourseProgress = null;
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
    PersistCourseProgressCallback? onPersistCourseProgress,
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
    _persistCourseProgress = onPersistCourseProgress;
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
    _persistCourseProgress = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_persistCurrentCourseProgress());
    }
  }

  Future<void> _persistCurrentCourseProgress() async {
    final player = _player;
    final callback = _persistCourseProgress;
    final courseId = _courseId;
    final lessonIndex = _lessonIndex;
    final resourceIndex = _resourceIndex;
    if (player == null ||
        callback == null ||
        courseId == null ||
        lessonIndex == null ||
        resourceIndex == null) {
      return;
    }

    await callback(
      courseId: courseId,
      lessonIndex: lessonIndex,
      resourceIndex: resourceIndex,
      mediaPositionMs: player.position.inMilliseconds,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
