import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrientationPolicy {
  static const double _tabletShortestSide = 600;
  static const MethodChannel _channel = MethodChannel('orientation_lock');
  static bool _isVideoFullscreenActive = false;

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return isTabletForSize(size);
  }

  static bool isTabletForSize(Size size) {
    return size.shortestSide >= _tabletShortestSide;
  }

  static bool get isVideoFullscreenActive => _isVideoFullscreenActive;

  static void setVideoFullscreenActive(bool isActive) {
    _isVideoFullscreenActive = isActive;
  }

  static Future<void> applyDefault({required bool isTablet}) {
    if (!isTablet && _isVideoFullscreenActive) {
      return Future<void>.value();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _setIosOrientationMask(
        isTablet ? 'all' : 'portrait',
        isTablet: isTablet,
      );
    }
    return SystemChrome.setPreferredOrientations(
      isTablet
          ? DeviceOrientation.values
          : <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
  }

  static Future<void> applyDefaultOrientations(BuildContext context) {
    return applyDefault(isTablet: isTablet(context));
  }

  static Future<void> applyVideoFullscreen({required bool isTablet}) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _setIosOrientationMask(
        isTablet ? 'all' : 'landscape',
        isTablet: isTablet,
      );
    }
    return SystemChrome.setPreferredOrientations(
      isTablet
          ? DeviceOrientation.values
          : <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  static Future<void> _setIosOrientationMask(
    String mask, {
    required bool isTablet,
  }) async {
    await _channel.invokeMethod<void>(
      'setOrientationMask',
      <String, String>{'mask': mask},
    );
    await SystemChrome.setPreferredOrientations(
      isTablet
          ? DeviceOrientation.values
          : mask == 'landscape'
              ? <DeviceOrientation>[
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]
              : <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
  }

  static Future<void> applyVideoFullscreenOrientations(
    BuildContext context,
  ) {
    return applyVideoFullscreen(isTablet: isTablet(context));
  }
}

class OrientationPolicyGate extends StatefulWidget {
  const OrientationPolicyGate({super.key, required this.child});

  final Widget child;

  @override
  State<OrientationPolicyGate> createState() => _OrientationPolicyGateState();
}

class _OrientationPolicyGateState extends State<OrientationPolicyGate> {
  bool? _isTablet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyPolicyIfNeeded();
  }

  @override
  void didUpdateWidget(OrientationPolicyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyPolicyIfNeeded();
  }

  void _applyPolicyIfNeeded() {
    final isTablet = OrientationPolicy.isTablet(context);
    if (_isTablet == isTablet) {
      return;
    }
    _isTablet = isTablet;
    if (!OrientationPolicy.isVideoFullscreenActive) {
      OrientationPolicy.applyDefault(isTablet: isTablet);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
