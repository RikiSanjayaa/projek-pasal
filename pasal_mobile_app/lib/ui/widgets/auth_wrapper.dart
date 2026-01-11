import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../main.dart' show navigatorKey;
import '../screens/login_screen.dart';

/// Wrapper widget that listens to auth state changes
/// and navigates to login screen when user is forcefully logged out
class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    authService.state.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    authService.state.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Only handle forced logout (when there's a deactivation reason)
    if (authService.state.value == AuthState.unauthenticated &&
        authService.deactivationReason.value != DeactivationReason.none) {
      _navigateToLoginWithMessage();
    }
  }

  void _navigateToLoginWithMessage() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final message = authService.deactivationMessage;

    // Navigate to login and clear the navigation stack
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(deactivationMessage: message),
      ),
      (route) => false,
    );

    // Clear the reason after navigating
    authService.clearDeactivationReason();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
