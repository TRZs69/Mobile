import 'package:flutter/cupertino.dart';

class CustomTabIndicator extends Decoration {
  final Color color;
  final double widthFraction;
  final double height;

  const CustomTabIndicator({
    required this.color,
    this.widthFraction = 1 / 3,
    this.height = 4.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CustomPainter(
        color: color, widthFraction: widthFraction, height: height);
  }
}

class _CustomPainter extends BoxPainter {
  final Color color;
  final double widthFraction;
  final double height;

  _CustomPainter(
      {required this.color, required this.widthFraction, required this.height});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final double width = configuration.size!.width * widthFraction;
    final double startX = offset.dx + (configuration.size!.width - width) / 2;
    final double endX = startX + width;
    final double bottom = configuration.size!.height - height;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(startX, bottom, endX, configuration.size!.height),
        Radius.circular(20),
      ),
      paint,
    );
  }
}
