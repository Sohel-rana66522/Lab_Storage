import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Small square icon button used for "back", matching the laboratory app's folder screen.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18),
          ),
        ),
      );
}

/// Goes back one page if there is one, otherwise to [fallback] (e.g. after a refresh).
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
