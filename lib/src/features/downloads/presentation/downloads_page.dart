import 'dart:io';

import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloaded_audio_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloaded_video_page.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:fcd_app/src/state/audio_playback_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

@visibleForTesting
String downloadsCourseHeadingFor(DownloadedFile file) {
  final course = file.courseName.trim();
  return course.isNotEmpty ? course : 'Descargas';
}

@visibleForTesting
String downloadsLessonHeadingFor(DownloadedFile file) {
  return file.lessonName.trim();
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    this.onGoToCourses,
    this.downloadRepository,
  });

  final VoidCallback? onGoToCourses;
  @visibleForTesting
  final DownloadRepository? downloadRepository;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late final DownloadRepository _downloadRepository;
  late final DownloadTaskController _downloadTaskController;
  final List<DownloadedFile> _pendingDeletes = <DownloadedFile>[];
  int _deleteSequence = 0;
  ScaffoldMessengerState? _scaffoldMessenger;

  bool _loading = true;
  bool _wasDownloading = false;
  List<DownloadedFile> _files = <DownloadedFile>[];
  String? _info;

  @override
  void initState() {
    super.initState();
    _downloadRepository =
        widget.downloadRepository ??
        DownloadRepository(
          apiClient: context.read<SessionController>().apiClient,
        );
    _downloadTaskController = context.read<DownloadTaskController>();
    _wasDownloading = _downloadTaskController.hasActiveDownloads;
    _downloadTaskController.addListener(_handleDownloadTaskChange);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    _downloadTaskController.removeListener(_handleDownloadTaskChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMiniPlayer = context.select(
      (AudioPlaybackController controller) => controller.hasMiniPlayer,
    );
    final bottomPadding = showMiniPlayer ? 86.0 : 20.0;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _DownloadsEmpty(onGoToCourses: widget.onGoToCourses),
              ),
            );
          },
        ),
      );
    }

    // Group downloads by course and lesson, preserving insertion order.
    final grouped = <String, Map<String, List<DownloadedFile>>>{};
    for (final file in _files) {
      final courseHeading = downloadsCourseHeadingFor(file);
      final lessonHeading = downloadsLessonHeadingFor(file);
      final lessons = grouped.putIfAbsent(
        courseHeading,
        () => <String, List<DownloadedFile>>{},
      );
      (lessons[lessonHeading] ??= <DownloadedFile>[]).add(file);
    }

    final items = <_DownloadListItem>[];
    for (final courseEntry in grouped.entries) {
      items.add(_DownloadHeadingItem(courseEntry.key));
      for (final lessonEntry in courseEntry.value.entries) {
        if (lessonEntry.key.isNotEmpty) {
          items.add(_DownloadLessonHeadingItem(lessonEntry.key));
        }
        for (final file in lessonEntry.value) {
          items.add(_DownloadEntryItem(file));
        }
      }
    }

    return Column(
      children: <Widget>[
        if (_info != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8DACA)),
              ),
              child: Text(
                _info!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.deepBrown),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_files.length} archivo(s) descargado(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Limpiar historial'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPadding),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is _DownloadHeadingItem) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 16,
                      bottom: 8,
                    ),
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.deepBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                if (item is _DownloadLessonHeadingItem) {
                  final isAfterCourse =
                      index > 0 && items[index - 1] is _DownloadHeadingItem;
                  return Padding(
                    padding: EdgeInsets.only(
                      top: isAfterCourse ? 4 : 12,
                      bottom: 6,
                    ),
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.deepBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                final entryItem = item as _DownloadEntryItem;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DownloadCard(
                    file: entryItem.file,
                    onPlayAudio: () => _openAudio(entryItem.file),
                    onPlayVideo: () => _playVideo(entryItem.file),
                    onOpen: () => _open(entryItem.file),
                    onDelete: () => _deleteEntry(entryItem.file),
                  ),
                );
              },
              itemCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _info = null;
    });

    final cleanupResult = await _downloadRepository.removeMissingDownloads();
    if (!mounted) {
      return;
    }

    setState(() {
      // Filter out pending deletes to prevent reappearing during undo window
      _files = cleanupResult.files
          .where((file) => !_pendingDeletes.any(
              (pending) => pending.localPath == file.localPath))
          .toList();
      _loading = false;
      _info = cleanupResult.removed > 0
          ? 'Se limpiaron ${cleanupResult.removed} archivo(s) inexistente(s) del historial.'
          : null;
    });
  }

  void _handleDownloadTaskChange() {
    final hasDownloads = _downloadTaskController.hasActiveDownloads;
    if (_wasDownloading && !hasDownloads && mounted) {
      _load();
    }
    _wasDownloading = hasDownloads;
  }

  Future<void> _open(DownloadedFile file) async {
    final localFile = File(file.localPath);
    if (!await localFile.exists()) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no existe en el almacenamiento local.'),
        ),
      );
      return;
    }

    final result = await OpenFilex.open(file.localPath);
    if (!mounted) {
      return;
    }

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir: ${result.message}')),
      );
    }
  }

  Future<void> _openAudio(DownloadedFile file) async {
    final localFile = File(file.localPath);
    if (!await localFile.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no existe en el almacenamiento local.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DownloadedAudioPage(file: file)),
    );
  }

  Future<void> _playVideo(DownloadedFile file) async {
    final localFile = File(file.localPath);
    if (!await localFile.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no existe en el almacenamiento local.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DownloadedVideoPage(file: file)),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar descargas'),
          content: const Text(
            'Se eliminarán todos los archivos descargados. ¿Quieres continuar?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _downloadRepository.clearHistory();
    if (!mounted) {
      return;
    }
    await _load();
  }

  void _deleteEntry(DownloadedFile file) {
    setState(() {
      _files.removeWhere((entry) => entry.localPath == file.localPath);
      _pendingDeletes.add(file);
    });

    final sequence = ++_deleteSequence;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text(
              _pendingDeletes.length == 1
                  ? 'Descarga eliminada.'
                  : 'Se eliminaron ${_pendingDeletes.length} descargas.',
            ),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: _undoDelete,
            ),
            duration: const Duration(seconds: 4),
          ),
        )
        .closed
        .then((reason) {
          if (reason == SnackBarClosedReason.action ||
              sequence != _deleteSequence) {
            return;
          }
          _commitPendingDelete();
        });
  }

  void _undoDelete() {
    if (_pendingDeletes.isEmpty) {
      return;
    }
    setState(() {
      _files.addAll(_pendingDeletes);
      _files.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      _pendingDeletes.clear();
    });
  }

  Future<void> _commitPendingDelete() async {
    if (_pendingDeletes.isEmpty) {
      return;
    }
    final pending = List<DownloadedFile>.from(_pendingDeletes);
    _pendingDeletes.clear();
    for (final entry in pending) {
      await _downloadRepository.deleteDownload(entry);
    }
    if (!mounted) {
      return;
    }
    await _load();
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.file,
    required this.onOpen,
    required this.onPlayAudio,
    required this.onPlayVideo,
    required this.onDelete,
  });

  final DownloadedFile file;
  final VoidCallback onOpen;
  final VoidCallback onPlayAudio;
  final VoidCallback onPlayVideo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Material(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _tapHandler(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E3CF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(file.type), color: AppTheme.deepBrown),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      file.name.isEmpty ? 'Archivo' : file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatter.format(file.downloadedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Eliminar descarga',
                    color: AppTheme.mutedText,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  if (file.type == 'audio')
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.deepBrown,
                    )
                  else if (file.type == 'video')
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppTheme.deepBrown,
                    )
                  else
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppTheme.deepBrown,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback _tapHandler() {
    if (file.type == 'audio') {
      return onPlayAudio;
    }
    if (file.type == 'video') {
      return onPlayVideo;
    }
    return onOpen;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'audio':
        return Icons.headphones_rounded;
      case 'video':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}

abstract class _DownloadListItem {
  const _DownloadListItem();
}

class _DownloadHeadingItem extends _DownloadListItem {
  const _DownloadHeadingItem(this.title);

  final String title;
}

class _DownloadLessonHeadingItem extends _DownloadListItem {
  const _DownloadLessonHeadingItem(this.title);

  final String title;
}

class _DownloadEntryItem extends _DownloadListItem {
  const _DownloadEntryItem(this.file);

  final DownloadedFile file;
}

class _DownloadsEmpty extends StatelessWidget {
  const _DownloadsEmpty({this.onGoToCourses});

  final VoidCallback? onGoToCourses;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.download_done_rounded,
              size: 54,
              color: AppTheme.deepBrown,
            ),
            const SizedBox(height: 10),
            Text(
              'Aún no tienes descargas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando descargues archivos desde una lección aparecerán aquí.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onGoToCourses != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onGoToCourses,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Ir a Mis Cursos'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
