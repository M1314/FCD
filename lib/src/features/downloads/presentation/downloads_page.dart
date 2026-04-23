import 'dart:io';

import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

String downloadsGroupHeadingFor(DownloadedFile file) {
  final course = file.courseName.trim();
  final lesson = file.lessonName.trim();
  if (course.isNotEmpty && lesson.isNotEmpty) {
    return '$course · $lesson';
  }
  if (course.isNotEmpty) {
    return course;
  }
  if (lesson.isNotEmpty) {
    return lesson;
  }
  return 'Descargas';
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late final DownloadRepository _downloadRepository;

  bool _loading = true;
  List<DownloadedFile> _files = <DownloadedFile>[];
  String? _info;

  @override
  void initState() {
    super.initState();
    _downloadRepository = DownloadRepository(
      apiClient: context.read<SessionController>().apiClient,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return _DownloadsEmpty(onRefresh: _load);
    }

    // Group downloads by course/lesson heading, preserving insertion order.
    final grouped = <String, List<DownloadedFile>>{};
    for (final file in _files) {
      final heading = downloadsGroupHeadingFor(file);
      (grouped[heading] ??= <DownloadedFile>[]).add(file);
    }

    final items = <_DownloadListItem>[];
    for (final heading in grouped.keys) {
      items.add(_DownloadHeadingItem(heading));
      for (final file in grouped[heading]!) {
        items.add(_DownloadEntryItem(file));
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
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
                final entryItem = item as _DownloadEntryItem;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DownloadCard(
                    file: entryItem.file,
                    onOpen: () => _open(entryItem.file),
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
      _files = cleanupResult.files;
      _loading = false;
      _info = cleanupResult.removed > 0
          ? 'Se limpiaron ${cleanupResult.removed} archivo(s) inexistente(s) del historial.'
          : null;
    });
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

  Future<void> _clear() async {
    await _downloadRepository.clearHistory();
    if (!mounted) {
      return;
    }
    await _load();
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.file, required this.onOpen});

  final DownloadedFile file;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Material(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
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
              const Icon(Icons.open_in_new_rounded, color: AppTheme.deepBrown),
            ],
          ),
        ),
      ),
    );
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

class _DownloadListItem {}

class _DownloadHeadingItem extends _DownloadListItem {
  _DownloadHeadingItem(this.title);

  final String title;
}

class _DownloadEntryItem extends _DownloadListItem {
  _DownloadEntryItem(this.file);

  final DownloadedFile file;
}

class _DownloadsEmpty extends StatelessWidget {
  const _DownloadsEmpty({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.download_done_rounded,
              size: 54,
              color: AppTheme.deepBrown,
            ),
            const SizedBox(height: 10),
            Text(
              'Aun no tienes descargas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando descargues archivos desde una leccion apareceran aqui.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
