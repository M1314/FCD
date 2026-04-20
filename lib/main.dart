import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:video_player/video_player.dart';

import 'models/class_lesson.dart';
import 'services/circulo_api.dart';
import 'services/media_download_service.dart';
import 'services/progress_service.dart';
import 'services/reminder_service.dart';

void main() {
  runApp(const FcdApp());
}

class FcdApp extends StatelessWidget {
  const FcdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Círculo Dorado',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4A2A7A), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = CirculoApi();
  final _downloads = MediaDownloadService();
  final _progress = ProgressService();
  final _audioPlayer = AudioPlayer();
  final _reminders = ReminderService(FlutterLocalNotificationsPlugin());

  List<ClassLesson> _lessons = const [];
  ClassMedia? _selectedMedia;
  VideoPlayerController? _videoController;
  Map<String, bool> _snippets = const {};
  int _reminderMinutes = 30;
  String _status = 'Listo para comenzar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lessons = await _api.fetchClasses();
    final snippets = await _progress.loadSnippets();
    await _reminders.init();

    setState(() {
      _lessons = lessons;
      _selectedMedia = lessons.isNotEmpty ? lessons.first.media.first : null;
      _snippets = snippets;
    });

    await _preparePlayer();
  }

  Future<void> _preparePlayer() async {
    final media = _selectedMedia;
    _videoController?.dispose();
    _videoController = null;

    if (media == null) {
      return;
    }

    if (media.type == 'video') {
      final controller = VideoPlayerController.networkUrl(Uri.parse(media.streamUrl));
      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(1);
      setState(() {
        _videoController = controller;
        _status = 'Video listo para reproducir.';
      });
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(media.streamUrl));
    setState(() {
      _status = 'Reproducción de audio iniciada.';
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    _api.dispose();
    _downloads.dispose();
    _reminders.dispose();
    super.dispose();
  }

  Future<void> _downloadSelected() async {
    final media = _selectedMedia;
    if (media == null) {
      return;
    }

    try {
      final path = await _downloads.download(media);
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Descargado en: $path';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'No se pudo completar la descarga: $error';
      });
    }
  }

  Future<void> _toggleSnippet(String storageKey, bool value) async {
    await _progress.saveSnippet(storageKey, value);
    if (!mounted) {
      return;
    }

    setState(() {
      _snippets = {..._snippets, storageKey: value};
    });
  }

  Future<void> _scheduleReminder() async {
    final message = await _reminders.scheduleInMinutes(_reminderMinutes);
    if (!mounted) {
      return;
    }

    setState(() {
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completion = _progress.completionPercent(_snippets);
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Círculo Dorado'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(label: Text('Progreso $completion%')),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_status),
                const SizedBox(height: 12),
                _buildLessonCard(),
                const SizedBox(height: 12),
                _buildPlayerCard(),
                const SizedBox(height: 12),
                _buildSnippetCard(),
                const SizedBox(height: 12),
                _buildReminderCard(),
              ],
            ),
          ),
          if (isDesktop)
            SizedBox(
              width: 300,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scaffolding escritorio',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Calendario semanal'),
                      const Text('• Estadísticas extendidas'),
                      const Text('• Comunidad y notas largas'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLessonCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clases', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final lesson in _lessons) ...[
              Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(lesson.description),
              Wrap(
                spacing: 8,
                children: [
                  for (final media in lesson.media)
                    ChoiceChip(
                      label: Text('${media.type.toUpperCase()} ${media.duration}'),
                      selected: _selectedMedia?.id == media.id,
                      onSelected: (_) async {
                        setState(() {
                          _selectedMedia = media;
                        });
                        await _preparePlayer();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard() {
    final selected = _selectedMedia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reproducción y descarga', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (selected == null)
              const Text('Selecciona una clase para comenzar')
            else if (selected.type == 'video' && _videoController?.value.isInitialized == true)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            else
              Text('Audio seleccionado: ${selected.title}'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _downloadSelected,
              child: Text(selected == null ? 'Sin contenido' : 'Descargar ${selected.type}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Snippets de progreso', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final entry in _snippets.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: entry.value,
                onChanged: (value) {
                  _toggleSnippet(entry.key, value ?? false);
                },
                title: Text(_progress.labelForKey(entry.key)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recordatorios', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Cada'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _reminderMinutes.toDouble(),
                    min: 5,
                    max: 180,
                    divisions: 35,
                    label: '$_reminderMinutes min',
                    onChanged: (value) {
                      setState(() {
                        _reminderMinutes = value.round();
                      });
                    },
                  ),
                ),
                Text('$_reminderMinutes min'),
              ],
            ),
            FilledButton(
              onPressed: _scheduleReminder,
              child: const Text('Programar recordatorio'),
            ),
          ],
        ),
      ),
    );
  }
}
