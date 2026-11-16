import 'package:flutter/material.dart';

class GlowingMouseIcon extends StatelessWidget {
  const GlowingMouseIcon({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlowingMousePainter(
          primary: colors.primary,
          secondary: colors.secondary,
        ),
      ),
    );
  }
}

class _GlowingMousePainter extends CustomPainter {
  const _GlowingMousePainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale, scale);

    final shell = Path()
      ..moveTo(24, 5)
      ..cubicTo(14.2, 5, 8.5, 11.2, 8.5, 20.5)
      ..lineTo(8.5, 29)
      ..cubicTo(8.5, 37.1, 14.6, 43, 24, 43)
      ..cubicTo(33.4, 43, 39.5, 37.1, 39.5, 29)
      ..lineTo(39.5, 20.5)
      ..cubicTo(39.5, 11.2, 33.8, 5, 24, 5)
      ..close();
    final glowPaint = Paint()
      ..color = primary.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(shell, glowPaint);

    final shellPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary, primary.withValues(alpha: .78)],
      ).createShader(const Rect.fromLTWH(7, 4, 34, 40))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shell, shellPaint);

    final divider = Path()
      ..moveTo(24, 6.5)
      ..lineTo(24, 20.5);
    final dividerGlow = Paint()
      ..color = secondary.withValues(alpha: .44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(divider, dividerGlow);
    canvas.drawPath(
      divider,
      Paint()
        ..color = secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowingMousePainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
