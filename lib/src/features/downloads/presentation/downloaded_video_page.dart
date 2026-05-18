import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:fcd_app/src/core/utils/orientation_policy.dart';
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
  bool _isTablet = false;
  bool _isPreparingController = false;
  bool _didApplySystemUiMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return;
    }
    _isTablet = OrientationPolicy.isTabletForSize(mediaQuery.size);
    _applySystemUiModeIfNeeded();
    if (_controller == null && !_isPreparingController) {
      _prepareController();
    }
  }

  @override
  void dispose() {
    OrientationPolicy.setVideoFullscreenActive(false);
    OrientationPolicy.applyDefault(
      isTablet: _isTablet,
      ignoreFullscreenFlag: true,
    );
    if (!_isTablet) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller?.dispose(forceDispose: true);
    super.dispose();
  }

  void _applySystemUiModeIfNeeded() {
    if (_didApplySystemUiMode) {
      return;
    }
    _didApplySystemUiMode = true;
    // iPad should stay edge-to-edge; immersive mode shifts safe-area insets
    // when the fullscreen route opens/closes and causes a visible jump.
    if (!_isTablet) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _prepareController() async {
    _isPreparingController = true;
    final localFile = File(widget.file.localPath);
    if (!await localFile.exists()) {
      if (mounted) {
        setState(() {
          _error = 'El archivo ya no existe en el almacenamiento local.';
        });
      }
      _isPreparingController = false;
      return;
    }

    final artworkUrl = widget.file.courseIconUrl.isNotEmpty
        ? widget.file.courseIconUrl
        : widget.file.courseBannerUrl;
    final localArtworkPath = widget.file.localArtworkPath;
    final notificationImageUrl = localArtworkPath.isNotEmpty
        ? 'file://$localArtworkPath'
        : (artworkUrl.isNotEmpty ? artworkUrl : null);

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      localFile.path,
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.file.name,
        imageUrl: notificationImageUrl,
      ),
    );

    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        allowedScreenSleep: false,
        handleLifecycle: false,
        autoDispose: false,
        // Keep downloaded videos opening fullscreen on phones, but not on iPad
        // where entering fullscreen should not toggle immersive system UI.
        fullScreenByDefault: !_isTablet,
        eventListener: _handleVideoEvents,
        routePageBuilder: _buildFullscreenRoute,
        deviceOrientationsOnFullScreen: _isTablet
            ? DeviceOrientation.values
            : <DeviceOrientation>[
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
        deviceOrientationsAfterFullScreen: _isTablet
            ? DeviceOrientation.values
            : <DeviceOrientation>[DeviceOrientation.portraitUp],
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
      _isPreparingController = false;
    } else {
      controller.dispose(forceDispose: true);
      _isPreparingController = false;
    }
  }

  void _handleVideoEvents(BetterPlayerEvent event) {
    // Ignore fullscreen orientation/system-UI transitions on iPad to keep
    // layout insets stable while BetterPlayer opens and closes fullscreen.
    if (_isTablet) {
      return;
    }
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.openFullscreen:
        OrientationPolicy.setVideoFullscreenActive(true);
        OrientationPolicy.applyVideoFullscreen(isTablet: _isTablet);
        break;
      case BetterPlayerEventType.hideFullscreen:
        OrientationPolicy.setVideoFullscreenActive(false);
        OrientationPolicy.applyDefault(isTablet: _isTablet);
        break;
      default:
        break;
    }
  }

  Widget _buildFullscreenRoute(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    BetterPlayerControllerProvider controllerProvider,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: controllerProvider,
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => _exitFullscreenAndPopPage(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    tooltip: 'Volver',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _exitFullscreenAndPopPage(BuildContext fullscreenContext) {
    Navigator.of(fullscreenContext, rootNavigator: true).maybePop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).maybePop();
    });
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
