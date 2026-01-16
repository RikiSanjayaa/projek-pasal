import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../core/config/app_colors.dart';

class AppShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final ShapeBorder? shapeBorder;

  const AppShowcase({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.shapeBorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? AppColors.bottomNav(isDark)
        : AppColors.scaffold(isDark);
    final Color titleColor = isDark ? Colors.white : Colors.black;
    final Color descColor = isDark ? Colors.white70 : Colors.black87;

    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,

      targetShapeBorder:
          shapeBorder ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),

      tooltipBackgroundColor: bgColor,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: titleColor,
        height: 1.3,
      ),

      descTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: descColor,
        height: 1.4,
      ),

      overlayColor: Colors.black.withValues(alpha: 0.7),

      blurValue: 1,
      targetPadding: const EdgeInsets.all(4),

      // Action buttons for navigation
      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: 'Next',
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          backgroundColor: AppColors.primary,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: 'Lewati',
          textStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          backgroundColor: Colors.transparent,
        ),
      ],
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.spaceBetween,
        position: TooltipActionPosition.inside,
        actionGap: 12,
      ),

      child: child,
    );
  }
}
