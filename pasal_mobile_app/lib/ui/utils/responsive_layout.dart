import 'package:material_ui/material_ui.dart';

abstract final class ResponsiveLayout {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double readingWidth = 760;
  static const double contentWidth = 1200;
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.contentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
    heightFactor: 1,
  );
}
