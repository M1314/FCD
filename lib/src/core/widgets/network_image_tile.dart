import 'package:flutter/material.dart';

class NetworkImageTile extends StatelessWidget {
  const NetworkImageTile({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.fallbackIcon = Icons.auto_stories_rounded,
  });

  final String url;
  final double width;
  final double height;
  final double borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0DFC8),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(fallbackIcon, size: 34),
    );
  }
}
