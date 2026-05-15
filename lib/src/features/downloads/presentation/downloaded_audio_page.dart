import 'dart:io';

import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/core/widgets/network_image_tile.dart';
import 'package:fcd_app/src/core/widgets/scrolling_text.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class DownloadedAudioPage extends StatefulWidget {
  const DownloadedAudioPage({super.key, required this.file});

  final DownloadedFile file;

  @override
  State<DownloadedAudioPage> createState() => _DownloadedAudioPageState();
}

class _DownloadedAudioPageState extends State<DownloadedAudioPage> {
  AudioPlayer? _player;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preparePlayer();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _preparePlayer() async {
    final localFile = File(widget.file.localPath);
    if (!await localFile.exists()) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'El archivo ya no existe en el almacenamiento local.';
      });
      return;
    }

    final player = AudioPlayer();
    final artworkUrl = widget.file.courseIconUrl.isNotEmpty
        ? widget.file.courseIconUrl
        : widget.file.courseBannerUrl;
    final localArtworkPath = widget.file.localArtworkPath;

    Uri? artUri;
    if (localArtworkPath.isNotEmpty) {
      artUri = Uri.file(localArtworkPath);
    } else if (artworkUrl.isNotEmpty) {
      artUri = Uri.parse(artworkUrl);
    }

    try {
      await player.setAudioSource(
        AudioSource.file(
          localFile.path,
          tag: MediaItem(
            id: widget.file.id,
            title: widget.file.name.isEmpty ? 'Audio descargado' : widget.file.name,
            artist: widget.file.courseName,
            album: widget.file.lessonName,
            artUri: artUri,
          ),
        ),
      );
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _loading = false;
      });
    } catch (_) {
      await player.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'No se pudo reproducir el audio.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final player = _player;
    if (player == null) {
      return const SizedBox.shrink();
    }

    final iconUrl = widget.file.courseIconUrl.trim();
    final coverUrl = iconUrl.isNotEmpty
        ? iconUrl
        : widget.file.courseBannerUrl.trim();
    final localArtworkPath = widget.file.localArtworkPath.trim();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFF6E7D2), Color(0xFFEBD3B2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controlsHeight =
              (constraints.maxHeight * 0.33).clamp(220.0, 320.0);
          final topInset = MediaQuery.of(context).padding.top;
          return Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 12),
                  child: Column(
                    children: <Widget>[
                      _buildTopBar(context),
                      const SizedBox(height: 12),
                      _buildCover(coverUrl, localArtworkPath),
                      const SizedBox(height: 18),
                      ScrollingText(
                        widget.file.name.isEmpty
                            ? 'Audio descargado'
                            : widget.file.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.deepBrown,
                            ),
                      ),
                      if (widget.file.courseName.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.file.courseName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: controlsHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _SpotifyControls(player: player),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCover(String url, String localArtworkPath) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth > 360 ? 360.0 : constraints.maxWidth;
        return Align(
          child: SizedBox(
            width: size,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: localArtworkPath.isNotEmpty
                    ? Image.file(
                        File(localArtworkPath),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => NetworkImageTile(
                          url: url,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                          fallbackIcon: Icons.headphones_rounded,
                          fit: BoxFit.cover,
                        ),
                      )
                    : NetworkImageTile(
                        url: url,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                        fallbackIcon: Icons.headphones_rounded,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.expand_more_rounded),
          tooltip: 'Cerrar',
        ),
        Expanded(
          child: Text(
            'Reproduciendo ahora',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _SpotifyControls extends StatefulWidget {
  const _SpotifyControls({required this.player});

  final AudioPlayer player;

  @override
  State<_SpotifyControls> createState() => _SpotifyControlsState();
}

class _SpotifyControlsState extends State<_SpotifyControls> {
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildPositionSlider(context),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _SeekButton(
                    icon: Icons.replay_10_rounded,
                    onPressed: () => _seekRelative(-10),
                  ),
                  const SizedBox(width: 22),
                  _PlayButton(
                    isBuffering: isBuffering,
                    isPlaying: playing,
                    onPressed: _toggle,
                  ),
                  const SizedBox(width: 22),
                  _SeekButton(
                    icon: Icons.forward_10_rounded,
                    onPressed: () => _seekRelative(10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _SeekLabel(text: '-10'),
                  const SizedBox(width: 22),
                  const SizedBox(width: 72),
                  const SizedBox(width: 22),
                  _SeekLabel(text: '+10'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionSlider(BuildContext context) {
    return StreamBuilder<Duration>(
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
                  ? (newValue) => setState(() => _dragValueMs = newValue)
                  : null,
              onChanged: canSeek
                  ? (newValue) => setState(() => _dragValueMs = newValue)
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                ),
                Text(
                  _formatDuration(total),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                ),
              ],
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

  Future<void> _seekRelative(int deltaSeconds) async {
    final total = widget.player.duration ?? Duration.zero;
    final current = widget.player.position;
    final target = current + Duration(seconds: deltaSeconds);
    final clamped = target.inMilliseconds.clamp(0, total.inMilliseconds);
    await widget.player.seek(Duration(milliseconds: clamped));
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

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isBuffering,
    required this.isPlaying,
    required this.onPressed,
  });

  final bool isBuffering;
  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.deepBrown,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x4D2B1E16),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: isBuffering ? null : onPressed,
        iconSize: 34,
        color: Colors.white,
        icon: isBuffering
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x332B1E16), width: 1.2),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.deepBrown),
      ),
    );
  }
}

class _SeekLabel extends StatelessWidget {
  const _SeekLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
