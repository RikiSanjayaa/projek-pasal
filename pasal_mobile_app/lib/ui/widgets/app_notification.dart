import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';

/// Shows a generalized app notification at the top of the screen.
///
/// This handles logic to remove existing notifications if present.
/// The [overlayEntry] parameter allows the caller to keep track of the current entry
/// to dismiss it if needed, though this function manages replacement automatically
/// if you use a simplified state management approach or pass the same variable.
///
/// However, to strictly mimic the behavior we had:
/// We need a way to track the *current* overlay at a global or scoped level to replace it.
///
/// For a simple reusable function, we can just return the created OverlayEntry
/// and let the caller manage the "replace if exists" logic,
/// OR we can use a global key/singleton helper.
///
/// Given the current codebase structure, a static class with a static variable
/// might be the easiest way to ensure only one notification shows at a time globally,
/// or we can keep it simple and just export the Widget and a helper method
/// that returns the entry.

class AppNotification {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    Color? color,
    IconData? icon,
  }) {
    // Remove existing overlay immediately if pending
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }

    final bgColor = color ?? AppColors.primary;
    final iconData = icon ?? Icons.check_circle_outline_rounded;

    _currentEntry = OverlayEntry(
      builder: (context) => _AnimatedNotification(
        message: message,
        bgColor: bgColor,
        iconData: iconData,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    Overlay.of(context).insert(_currentEntry!);
  }
}

class _AnimatedNotification extends StatefulWidget {
  final String message;
  final Color bgColor;
  final IconData iconData;
  final VoidCallback onDismiss;

  const _AnimatedNotification({
    required this.message,
    required this.bgColor,
    required this.iconData,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    _dismissTimer = Timer(const Duration(milliseconds: 2500), _handleDismiss);
  }

  void _handleDismiss() {
    _dismissTimer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) => widget.onDismiss());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: widget.bgColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.iconData, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleDismiss,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
