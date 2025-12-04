import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Animasyon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const GpsAnimationDemo(),
    );
  }
}

class GpsAnimationDemo extends StatelessWidget {
  const GpsAnimationDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Konum Yükleniyor'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GpsLoadingAnimation(
              size: 150,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            const Text(
              'Konum Aranıyor...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 50),
            
            const Text(
              'Küçük Yeşil Versiyon:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const GpsLoadingAnimation(
              size: 80,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class GpsLoadingAnimation extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const GpsLoadingAnimation({
    Key? key,
    this.size = 100,
    this.color = Colors.blue,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<GpsLoadingAnimation> createState() => _GpsLoadingAnimationState();
}

class _GpsLoadingAnimationState extends State<GpsLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: GpsPainter(
              animation: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class GpsPainter extends CustomPainter {
  final double animation;
  final Color color;

  GpsPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pinPath = Path();
    final pinRadius = radius * 0.25;
    
    pinPath.addOval(Rect.fromCircle(center: center, radius: pinRadius));
    
    pinPath.moveTo(center.dx, center.dy + pinRadius);
    pinPath.lineTo(center.dx - pinRadius * 0.5, center.dy + pinRadius * 2);
    pinPath.lineTo(center.dx + pinRadius * 0.5, center.dy + pinRadius * 2);
    pinPath.close();

    canvas.drawPath(pinPath, pinPaint);

    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pinRadius * 0.4, innerDotPaint);

    for (int i = 0; i < 3; i++) {
      final delay = i * 0.33;
      final circleAnimation = (animation + delay) % 1.0;
      
      final circleRadius = radius * 0.3 + (radius * 0.7 * circleAnimation);
      final opacity = (1.0 - circleAnimation) * 0.6;

      final circlePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(center, circleRadius, circlePaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle = (animation * 2 * math.pi) + (i * math.pi / 2);
      final lineLength = radius * 0.15;
      final startRadius = radius * 0.55;
      
      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + (startRadius + lineLength) * math.cos(angle);
      final endY = center.dy + (startRadius + lineLength) * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(GpsPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}