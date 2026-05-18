import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/scrolling_text.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// A floating mini-player widget for audio playback.
///
/// Displays playback controls, title, status, and progress bar.
/// Can be configured to show/hide the close button and customize tap behavior.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({
    super.key,
    required this.player,
    required this.title,
    required this.onTap,
    this.onClose,
    this.showCloseButton = true,
  });

  final AudioPlayer player;
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processing = playerState?.processingState;
        final playing = playerState?.playing ?? false;
        final isBuffering = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Container(
          decoration: const BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFFFF5E8),
                border: Border.all(color: const Color(0xFFE8DACA)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (isBuffering)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          else
                            IconButton.filled(
                              onPressed: () => _togglePlayback(player),
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.deepBrown,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                ScrollingText(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  velocity: 26,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  playing ? 'Reproduciendo' : 'En pausa',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.mutedText),
                                ),
                              ],
                            ),
                          ),
                          if (showCloseButton && onClose != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Cerrar reproductor',
                              visualDensity: VisualDensity.compact,
                              color: AppTheme.deepBrown,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final total = player.duration ?? Duration.zero;
                          final totalMs = total.inMilliseconds;
                          final progress = totalMs <= 0
                              ? 0.0
                              : (position.inMilliseconds / totalMs)
                                  .clamp(0.0, 1.0);

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: progress,
                              backgroundColor: const Color(0xFFE8DACA),
                              color: AppTheme.deepBrown,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _togglePlayback(AudioPlayer player) async {
    if (player.playing) {
      await player.pause();
      return;
    }
    await player.play();
  }
}
