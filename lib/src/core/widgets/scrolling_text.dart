import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  const ScrollingText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.velocity = 32,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final double velocity;

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  AnimationController? _animationController;
  double _lastMaxScrollExtent = 0;

  @override
  void dispose() {
    _animationController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _animationController?.stop();
    _animationController?.dispose();
    _animationController = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Duration _durationFor(double maxScrollExtent) {
    final rawMilliseconds =
        (maxScrollExtent / widget.velocity * 1000).round();
    final clampedMilliseconds = rawMilliseconds.clamp(2000, 20000);
    return Duration(milliseconds: clampedMilliseconds.toInt());
  }

  void _startScrolling(double maxScrollExtent) {
    if (maxScrollExtent <= 0) {
      _stopScrolling();
      return;
    }
    if (_animationController != null &&
        _lastMaxScrollExtent == maxScrollExtent) {
      if (!_animationController!.isAnimating) {
        _animationController!.repeat(reverse: true);
      }
      return;
    }
    _lastMaxScrollExtent = maxScrollExtent;
    _animationController?.dispose();
    _animationController = AnimationController(
      vsync: this,
      duration: _durationFor(maxScrollExtent),
    );
    final animation = Tween<double>(
      begin: 0,
      end: maxScrollExtent,
    ).animate(_animationController!);
    _animationController!.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(animation.value);
      }
    });
    _animationController!.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final fullWidthPainter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textScaler: textScaler,
          textDirection: Directionality.of(context),
        )..layout();
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fullWidthPainter.size.width;
        var shouldScroll = fullWidthPainter.size.width > maxWidth;
        if (widget.maxLines > 1) {
          final constrainedPainter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: widget.maxLines,
            textScaler: textScaler,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: maxWidth);
          shouldScroll = constrainedPainter.didExceedMaxLines;
        }
        if (!shouldScroll) {
          _stopScrolling();
          return Text(
            widget.text,
            style: style,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            softWrap: widget.maxLines > 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) {
            return;
          }
          _startScrolling(_scrollController.position.maxScrollExtent);
        });

        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                style: style,
                textAlign: widget.textAlign,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        );
      },
    );
  }
}
