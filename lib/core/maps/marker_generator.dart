import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper to generate custom markers from text/emojis.
abstract final class MarkerGenerator {
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
    String icon, {
    bool selected = false,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = selected ? 160.0 : 120.0;
    final double radius = size / 2.2;

    // Draw background circle (Thekedar branding style)
    final Paint paint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(size / 2, size / 2), radius, paint);

    final Paint borderPaint = Paint()
      ..color = selected ? const Color(0xFFFFD600) : const Color(0xFFFFD600).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 10.0 : 6.0;
    canvas.drawCircle(Offset(size / 2, size / 2), radius, borderPaint);

    // Glow effect for selected
    if (selected) {
      final Paint glowPaint = Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: 0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
      canvas.drawCircle(Offset(size / 2, size / 2), radius + 8, glowPaint);
    }

    // Draw the emoji/icon from API
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: icon,
      style: TextStyle(fontSize: selected ? 65 : 50, color: Colors.white),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size / 2) - (textPainter.width / 2), (size / 2) - (textPainter.height / 2)),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
