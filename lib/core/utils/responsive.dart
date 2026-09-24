import 'package:flutter/widgets.dart';

/// Layout breakpoints: compact (phone) / medium (tablet) / expanded (desktop).
class Responsive {
  Responsive._();

  static const double compactMax = 700;
  static const double expandedMin = 1100;

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compactMax;

  static int gridColumns(double width, {int compact = 2}) {
    if (width < compactMax) return compact;
    if (width < 1000) return 3;
    return 4;
  }
}
