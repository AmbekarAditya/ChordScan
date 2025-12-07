// lib/widgets/audio_visualizer.dart
import 'package:flutter/material.dart';

class AudioVisualizer extends StatelessWidget {
  final List<double> amplitudes;

  const AudioVisualizer({super.key, required this.amplitudes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: VisualizerPainter(
          amplitudes: amplitudes,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  VisualizerPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final double width = size.width;
    final double center = size.height / 2;
    final int count = amplitudes.length;
    // Calculate spacing to fit all bars
    final double spacing = width / (count > 0 ? count : 1);

    for (int i = 0; i < count; i++) {
        // Amplitude is usually -160 to 0 dB. We normalize it roughly for visual logic.
        // Assuming input is already normalized 0.0 to 1.0 or similar by the parent.
        final double barHeight = amplitudes[i] * size.height;
        
        final double x = i * spacing + (spacing / 2);
        
        // Draw centered bar
        final p1 = Offset(x, center - barHeight / 2);
        final p2 = Offset(x, center + barHeight / 2);
        
        canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes;
  }
}
