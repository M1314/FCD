import 'package:fcd_app/src/core/storage/progress_storage.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/network_image_tile.dart';
import 'package:fcd_app/src/features/courses/data/models/course.dart';
import 'package:fcd_app/src/features/courses/data/models/course_lesson.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
import 'package:flutter/material.dart';

class CourseSummaryPage extends StatefulWidget {
  const CourseSummaryPage({
    super.key,
    required this.course,
    required this.lessons,
  });

  final Course course;
  final List<CourseLesson> lessons;

  @override
  State<CourseSummaryPage> createState() => _CourseSummaryPageState();
}

class _CourseSummaryPageState extends State<CourseSummaryPage> {
  final ProgressStorage _progressStorage = ProgressStorage();
  CourseProgress? _savedProgress;

  @override
  void initState() {
    super.initState();
    _loadSavedProgress();
  }

  Future<void> _loadSavedProgress() async {
    final progress = await _progressStorage.getProgress(widget.course.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedProgress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.course.bannerUrl.isNotEmpty
        ? widget.course.bannerUrl
        : widget.course.iconUrl;

    final hasSavedProgress =
        _savedProgress != null && _savedProgress!.lessonIndex > 0;
    final resumeLessonName = hasSavedProgress &&
            _savedProgress!.lessonIndex < widget.lessons.length
        ? widget.lessons[_savedProgress!.lessonIndex].name
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del curso')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: <Widget>[
                  NetworkImageTile(
                    url: artwork,
                    width: double.infinity,
                    height: 180,
                    borderRadius: 18,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.course.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.course.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      widget.course.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    widget.course.description.isEmpty
                        ? 'Este curso esta disponible en tu membresia.'
                        : widget.course.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _InfoPill(
                        icon: Icons.menu_book_rounded,
                        text: '${widget.lessons.length} lecciones',
                      ),
                      _InfoPill(
                        icon: Icons.picture_as_pdf_rounded,
                        text: '${_countDocs(widget.lessons)} documentos',
                      ),
                      _InfoPill(
                        icon: Icons.play_circle_fill_rounded,
                        text: '${_countVideos(widget.lessons)} videos',
                      ),
                      _InfoPill(
                        icon: Icons.headphones_rounded,
                        text: '${_countAudios(widget.lessons)} audios',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Temario',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...widget.lessons.asMap().entries.map(
                    (entry) =>
                        _LessonItem(index: entry.key + 1, lesson: entry.value),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (hasSavedProgress && resumeLessonName != null) ...<Widget>[
                      ElevatedButton.icon(
                        onPressed: _startCourse,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          'Continuar: ${resumeLessonName.length > 30 ? '${resumeLessonName.substring(0, 30)}...' : resumeLessonName}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await _startFromBeginning();
                        },
                        child: const Text('Empezar desde el principio'),
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: _startCourse,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Comenzar curso'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startCourse() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerPage(
          course: widget.course,
          lessons: widget.lessons,
        ),
      ),
    );
  }

  void _startFromBeginning() async {
    await _progressStorage.clearProgress(widget.course.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerPage(
          course: widget.course,
          lessons: widget.lessons,
          forceStart: true,
        ),
      ),
    );
  }

  int _countDocs(List<CourseLesson> lessons) =>
      lessons.fold(0, (sum, item) => sum + item.documents.length);

  int _countVideos(List<CourseLesson> lessons) =>
      lessons.fold(0, (sum, item) => sum + item.videos.length);

  int _countAudios(List<CourseLesson> lessons) =>
      lessons.fold(0, (sum, item) => sum + item.audios.length);
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E4D1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppTheme.deepBrown),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.deepBrown,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonItem extends StatelessWidget {
  const _LessonItem({required this.index, required this.lesson});

  final int index;
  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9DDCF)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFF2E4D1),
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.deepBrown,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lesson.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Icon(
            lesson.hasEvaluation ? Icons.quiz_rounded : Icons.checklist_rounded,
            color: AppTheme.deepBrown,
          ),
        ],
      ),
    );
  }
}
