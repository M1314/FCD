import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadedVideoPage extends StatefulWidget {
  const DownloadedVideoPage({super.key, required this.file});

  final DownloadedFile file;

  @override
  State<DownloadedVideoPage> createState() => _DownloadedVideoPageState();
}

class _DownloadedVideoPageState extends State<DownloadedVideoPage> {
  BetterPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _prepareController();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose(forceDispose: true);
    super.dispose();
  }

  Future<void> _prepareController() async {
    final localFile = File(widget.file.localPath);
    if (!await localFile.exists()) {
      if (mounted) {
        setState(() {
          _error = 'El archivo ya no existe en el almacenamiento local.';
        });
      }
      return;
    }

    final artworkUrl = widget.file.courseIconUrl.isNotEmpty
        ? widget.file.courseIconUrl
        : widget.file.courseBannerUrl;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      localFile.path,
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.file.name,
        imageUrl: artworkUrl.isNotEmpty ? artworkUrl : null,
      ),
    );

    final controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: false,
        fit: BoxFit.contain,
        allowedScreenSleep: false,
        handleLifecycle: false,
        autoDispose: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSkips: true,
          enablePlaybackSpeed: true,
          enablePip: true,
          loadingColor: AppTheme.gold,
          progressBarBackgroundColor: Color(0x44FFFFFF),
          progressBarPlayedColor: AppTheme.gold,
          playerTheme: BetterPlayerTheme.material,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    } else {
      controller.dispose(forceDispose: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
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

    final controller = _controller;
    if (controller == null) {
      return const CircularProgressIndicator();
    }

    return Stack(
      children: <Widget>[
        SizedBox.expand(
          child: BetterPlayer(controller: controller),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            tooltip: 'Volver',
          ),
        ),
      ],
    );
  }
}
