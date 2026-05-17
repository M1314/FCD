import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({super.key, required this.player});

  final AudioPlayer player;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  double? _dragValueMs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processing = playerState?.processingState;
        final playing = playerState?.playing ?? false;

        final isBuffering =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton.filled(
                  onPressed: isBuffering ? null : _toggle,
                  icon: isBuffering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playing ? 'Reproduciendo...' : 'Pausado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<Duration>(
              stream: widget.player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final total = widget.player.duration ?? Duration.zero;
                final canSeek = total.inMilliseconds > 0;
                final max = total.inMilliseconds <= 0
                    ? 1.0
                    : total.inMilliseconds.toDouble();
                final liveValue = position.inMilliseconds
                    .clamp(0, max.toInt())
                    .toDouble();
                final sliderValue = (_dragValueMs ?? liveValue).clamp(0.0, max);
                final displayPosition = _dragValueMs == null
                    ? position
                    : Duration(milliseconds: sliderValue.round());

                return Column(
                  children: <Widget>[
                    Slider(
                      value: sliderValue,
                      max: max,
                      onChangeStart: canSeek
                          ? (newValue) {
                              setState(() => _dragValueMs = newValue);
                            }
                          : null,
                      onChanged: canSeek
                          ? (newValue) {
                              setState(() => _dragValueMs = newValue);
                            }
                          : null,
                      onChangeEnd: canSeek
                          ? (newValue) async {
                              setState(() => _dragValueMs = null);
                              await widget.player.seek(
                                Duration(milliseconds: newValue.round()),
                              );
                            }
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _formatDuration(displayPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatDuration(total),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (widget.player.playing) {
      await widget.player.pause();
      return;
    }
    await widget.player.play();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
