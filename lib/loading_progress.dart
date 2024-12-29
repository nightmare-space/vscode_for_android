import 'dart:math';

import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';

class CircleProgress extends CustomPainter {
  CircleProgress({
    required this.progress,
    required this.color,
    required this.angle,
    required this.strokeWidth,
  });
  late Paint _paintFore;
  Color color;
  double progress;
  double angle = 0.0;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - strokeWidth,
    );
    _paintFore = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    canvas.drawArc(rect, angle, progress * 2 * pi, false, _paintFore);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class LoadingProgress extends StatefulWidget {
  const LoadingProgress({
    super.key,
    this.minRadius = 12,
    this.strokeWidth = 2,
    this.increaseRadius = 5,
  });
  final double minRadius;
  final double strokeWidth;
  final double increaseRadius;

  @override
  State<LoadingProgress> createState() => _LoadingProgressState();
}

class _LoadingProgressState extends State<LoadingProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late Animation<double> first = Tween(begin: 0.0, end: pi * 2).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeInOut),
  ));
  late Animation<double> second = Tween(begin: 0.0, end: pi * 2).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.5, curve: Curves.easeInOut),
  ));
  late Animation<double> third = Tween(begin: 0.0, end: pi * 2).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 0.6, curve: Curves.easeInOut),
  ));
  late Animation<double> fourth = Tween(begin: 0.0, end: pi * 2).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
  ));
  late Animation<double> fifth = Tween(begin: 0.0, end: pi * 2).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
  ));

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  Center buildCircle({
    required Animation animation,
    required double radius,
    required double angle,
  }) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: animation.value,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size.fromRadius(radius),
              painter: CircleProgress(
                progress: 0.5,
                angle: angle,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double firstCircleRadius = widget.minRadius;
    return Stack(
      alignment: Alignment.center,
      children: [
        buildCircle(
          angle: -pi / 4,
          radius: firstCircleRadius,
          animation: first,
        ),
        buildCircle(
          angle: pi + pi / 8,
          radius: firstCircleRadius + widget.increaseRadius,
          animation: second,
        ),
        buildCircle(
          angle: pi + pi / 8,
          radius: firstCircleRadius + widget.increaseRadius * 2,
          animation: third,
        ),
        buildCircle(
          angle: pi / 2 - pi / 8,
          radius: firstCircleRadius + widget.increaseRadius * 3,
          animation: fourth,
        ),
        buildCircle(
          angle: pi / 2 - pi / 8,
          radius: firstCircleRadius + widget.increaseRadius * 4,
          animation: fifth,
        ),
      ],
    );
  }
}
