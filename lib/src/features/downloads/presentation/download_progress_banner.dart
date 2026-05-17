import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:flutter/material.dart';

class DownloadProgressBanner extends StatelessWidget {
  const DownloadProgressBanner({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  static const Color _bannerColor = Color(0xFFFFF5E8);
  static const Color _bannerBorderColor = Color(0xFFE8DACA);

  final DownloadTaskController controller;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final downloads = controller.activeDownloads;
    final overallProgress = controller.overallProgress;
    final overallPercent =
        (overallProgress.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    final count = downloads.length;
    final label = count == 1
        ? 'Descargando 1 archivo'
        : 'Descargando $count archivos';

    return Material(
      color: _bannerColor,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _bannerBorderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '$label · $overallPercent%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: overallProgress.clamp(0.0, 1.0)),
                if (expanded) ...<Widget>[
                  const SizedBox(height: 10),
                  _DownloadsExpandedList(
                    downloads: downloads,
                    onCancel: controller.cancelDownload,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadsExpandedList extends StatelessWidget {
  const _DownloadsExpandedList({required this.downloads, required this.onCancel});

  final List<DownloadTaskSnapshot> downloads;
  final void Function(String resourceId) onCancel;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        thumbVisibility: downloads.length > 1,
        child: SingleChildScrollView(
          child: Column(
            children: downloads
                .map(
                  (download) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DownloadProgressRow(
                      download: download,
                      onCancel: onCancel,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressRow extends StatelessWidget {
  const _DownloadProgressRow({required this.download, required this.onCancel});

  final DownloadTaskSnapshot download;
  final void Function(String resourceId) onCancel;

  @override
  Widget build(BuildContext context) {
    final percent =
        (download.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${download.resourceName} · $percent%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            IconButton(
              onPressed: () => onCancel(download.resourceId),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cancelar descarga',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: download.progress.clamp(0.0, 1.0)),
      ],
    );
  }
}
