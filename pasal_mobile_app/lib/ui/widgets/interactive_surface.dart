import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../core/config/app_theme.dart';

/// Paints interaction states on the surface itself, never behind an opaque child.
/// The outline does not contribute padding, so focus cannot resize the control.
class InteractiveSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool selected;
  final Color? color;
  final Color? borderColor;
  final bool showBorder;

  const InteractiveSurface({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.selected = false,
    this.color,
    this.borderColor,
    this.showBorder = true,
  });

  @override
  State<InteractiveSurface> createState() => _InteractiveSurfaceState();
}

class _InteractiveSurfaceState extends State<InteractiveSurface> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        widget.color ??
        (widget.selected ? AppColors.selected(isDark) : AppColors.card(isDark));
    final background = !_hovered
        ? base
        : widget.selected
        ? Color.alphaBlend(
            (widget.color == AppColors.primary
                    ? Colors.white
                    : AppColors.accent(isDark))
                .withValues(alpha: .08),
            base,
          )
        : AppColors.hover(isDark);
    return Material(
      color: background,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _focused
                  ? (widget.color == AppColors.primary
                        ? Colors.white
                        : AppColors.accent(isDark))
                  : widget.borderColor ??
                        (widget.showBorder
                            ? AppColors.border(isDark)
                            : Colors.transparent),
              width: _focused
                  ? AppTheme.focusBorderWidth
                  : AppTheme.borderWidth,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
