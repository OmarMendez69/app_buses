import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Mapa simulado dibujado con CustomPaint (sin paquetes externos).
class MapaSimulado extends StatelessWidget {
  const MapaSimulado({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MapaPainter());
  }
}

class _MapaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    final calle = Paint()
      ..color = const Color(0xFF242424)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), calle);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), calle);
    }

    final ruta1 = Path()
      ..moveTo(size.width * 0.08, size.height * 0.80)
      ..lineTo(size.width * 0.35, size.height * 0.62)
      ..lineTo(size.width * 0.55, size.height * 0.48)
      ..lineTo(size.width * 0.90, size.height * 0.30);
    final ruta2 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.30)
      ..lineTo(size.width * 0.40, size.height * 0.45)
      ..lineTo(size.width * 0.55, size.height * 0.48)
      ..lineTo(size.width * 0.80, size.height * 0.85);

    canvas.drawPath(
      ruta1,
      Paint()
        ..color = kAcento
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      ruta2,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final parada = Paint()..color = Colors.white;
    final bordeParada = Paint()
      ..color = kAcento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final p in [
      Offset(size.width * 0.35, size.height * 0.62),
      Offset(size.width * 0.90, size.height * 0.30),
      Offset(size.width * 0.40, size.height * 0.45),
      Offset(size.width * 0.80, size.height * 0.85),
    ]) {
      canvas.drawCircle(p, 7, parada);
      canvas.drawCircle(p, 7, bordeParada);
    }

    final usuario = Offset(size.width * 0.55, size.height * 0.48);
    canvas.drawCircle(
        usuario, 18, Paint()..color = Colors.blueAccent.withOpacity(0.25));
    canvas.drawCircle(usuario, 8, Paint()..color = Colors.blueAccent);
    canvas.drawCircle(
      usuario,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
