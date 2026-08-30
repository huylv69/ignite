import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The Ignite flame, drawn from the same path as the launcher icon.
///
/// The app used Material's `local_fire_department_rounded`, a different flame
/// from the one on the icon, so the mark on the home screen and the mark inside
/// the app did not match. Both now come from one path.
class IgniteMark extends StatelessWidget {
  final double size;
  final Color? color;

  /// The bright inner core. Suppressed under 20px, where it turns to mud.
  final bool core;

  const IgniteMark({super.key, this.size = 24, this.color, this.core = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: FlamePainter(
          color: color ?? AppTheme.primary,
          core: core && size >= 20,
        ),
      ),
    );
  }
}

/// The launcher icon in miniature: the brand gradient with the flame knocked
/// out of it. Use where the app is identifying itself — app bar, login, about.
class IgniteTile extends StatelessWidget {
  final double size;
  final double radius;
  final bool glow;

  const IgniteTile({
    super.key,
    this.size = 32,
    double? radius,
    this.glow = true,
  }) : radius = radius ?? size * 0.28;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryLight,
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            glow
                ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: size * 0.32,
                    spreadRadius: size * 0.02,
                  ),
                ]
                : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: CustomPaint(
          painter: FlamePainter(
            color: const Color(0xFF12080A),
            core: false,
            knockoutCore: size >= 30,
          ),
        ),
      ),
    );
  }
}

/// Draws the flame from `assets/icon/app_icon.svg`.
///
/// The coordinates are that file's 1024-unit viewBox, scaled at paint time, so
/// the widget and the icon cannot drift apart.
class FlamePainter extends CustomPainter {
  final Color color;
  final bool core;

  /// Punch the inner core back out of the flame, as the icon does.
  final bool knockoutCore;

  const FlamePainter({
    required this.color,
    this.core = true,
    this.knockoutCore = false,
  });

  // The mark occupies x:316..712, y:92..706 of the viewBox. Normalising to that
  // box makes it fill the widget rather than float in the icon's padding.
  static const _minX = 316.0, _maxX = 712.0, _minY = 92.0, _maxY = 706.0;

  static Path _flame() =>
      Path()
        ..moveTo(556, 92)
        ..cubicTo(556, 214, 470, 262, 470, 330)
        ..cubicTo(470, 372, 498, 396, 498, 396)
        ..cubicTo(470, 400, 402, 356, 396, 274)
        ..cubicTo(342, 344, 316, 414, 316, 486)
        ..cubicTo(316, 620, 404, 706, 512, 706)
        ..cubicTo(626, 706, 712, 618, 712, 490)
        ..cubicTo(712, 366, 600, 268, 556, 92)
        ..close();

  static Path _core() =>
      Path()
        ..moveTo(528, 402)
        ..cubicTo(528, 470, 452, 498, 452, 566)
        ..cubicTo(452, 626, 480, 660, 524, 660)
        ..cubicTo(574, 660, 604, 622, 604, 570)
        ..cubicTo(604, 508, 528, 486, 528, 402)
        ..close();

  @override
  void paint(Canvas canvas, Size size) {
    const w = _maxX - _minX, h = _maxY - _minY;
    final scale =
        size.width / w < size.height / h ? size.width / w : size.height / h;

    canvas.save();
    canvas.translate(
      (size.width - w * scale) / 2 - _minX * scale,
      (size.height - h * scale) / 2 - _minY * scale,
    );
    canvas.scale(scale);

    final paint = Paint()..color = color;
    if (knockoutCore) {
      canvas.drawPath(
        Path.combine(PathOperation.difference, _flame(), _core()),
        paint,
      );
    } else {
      canvas.drawPath(_flame(), paint);
      if (core) {
        canvas.drawPath(_core(), Paint()..color = const Color(0xFFFFF1DC));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FlamePainter old) =>
      old.color != color ||
      old.core != core ||
      old.knockoutCore != knockoutCore;
}
