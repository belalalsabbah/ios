import 'package:flutter/material.dart';

Color statusColorByDays(int days) {
  const int maxDays = 30;

  // نسبة الاستهلاك
  final double usedRatio =
      ((maxDays - days) / maxDays).clamp(0.0, 1.0);

  if (usedRatio < 0.33) {
    // أخضر → أصفر
    return Color.lerp(
      Colors.green.shade700,
      Colors.yellow.shade700,
      usedRatio / 0.33,
    )!;
  } else if (usedRatio < 0.66) {
    // أصفر → برتقالي
    return Color.lerp(
      Colors.yellow.shade700,
      Colors.orange.shade700,
      (usedRatio - 0.33) / 0.33,
    )!;
  } else {
    // برتقالي → أحمر
    return Color.lerp(
      Colors.orange.shade700,
      Colors.red.shade700,
      (usedRatio - 0.66) / 0.34,
    )!;
  }
}
LinearGradient statusGradientByDays(int days) {
  const int maxDays = 30;
  final double usedRatio =
      ((maxDays - days) / maxDays).clamp(0.0, 1.0);

  if (usedRatio < 0.33) {
    return LinearGradient(
      colors: [
        Colors.green.shade700,
        Colors.yellow.shade600,
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );
  } else if (usedRatio < 0.66) {
    return LinearGradient(
      colors: [
        Colors.yellow.shade700,
        Colors.orange.shade600,
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );
  } else {
    return LinearGradient(
      colors: [
        Colors.orange.shade700,
        Colors.red.shade700,
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );
  }
}


IconData statusIconByDays(int days) {
  if (days <= 0) return Icons.cancel;
  if (days <= 3) return Icons.warning;
  return Icons.check_circle;
}

String statusTextByDays(int days) {
  if (days <= 0) return "منتهي";
  if (days <= 3) return "قارب على الانتهاء";
  return "فعال";
}

double progressValueByDays(int days) {
  const totalDays = 30;
  return (days / totalDays).clamp(0.0, 1.0);
}
