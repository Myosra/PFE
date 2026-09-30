import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  final List<int> values;
  final Color color;
  const Sparkline({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _P(values, color), size: Size.infinite);
}

class _P extends CustomPainter {
  final List<int> v;
  final Color c;
  _P(this.v, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = v.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1);
      final y = size.height - (v[i] / maxV) * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_P old) => true;
}
