import 'dart:async';

import 'package:material_ui/material_ui.dart';
import '../../core/services/auth_service.dart';
import '../../main.dart' show navigatorKey;
import '../screens/lock_screen.dart';
import '../screens/login_screen.dart';

/// Wrapper widget that listens to auth state changes
/// and navigates to login screen when user is forcefully logged out.
/// Also re-checks the local session while the app stays open and on resume, so
/// an expired offline lease or account locks the app without a restart.
class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  static const Duration _checkInterval = Duration(minutes: 1);

  Timer? _timer;
  AuthState _previousState = authService.state.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    authService.state.addListener(_onAuthStateChanged);
    _timer = Timer.periodic(_checkInterval, (_) => _enforceSession());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    authService.state.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    _resumeSession();
  }

  Future<void> _enforceSession() async {
    if (!authService.isLoggedIn) return;
    await authService.checkSession();
  }

  Future<void> _resumeSession() async {
    if (!authService.isLoggedIn) return;
    final result = await authService.checkSession();
    // Online: memperbarui akses offline dan mendeteksi perangkat dicabut.
    if (result == ExpiryCheckResult.valid) {
      await authService.verifyActiveStatus();
    }
  }

  void _onAuthStateChanged() {
    final previous = _previousState;
    final current = authService.state.value;
    _previousState = current;

    // Only handle forced logout (when there's a deactivation reason)
    if (current == AuthState.unauthenticated &&
        authService.deactivationReason.value != DeactivationReason.none) {
      _navigateToLoginWithMessage();
    } else if (previous == AuthState.authenticated &&
        current == AuthState.expired) {
      _navigateToLock();
    }
  }

  void _navigateToLock() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final leaseExpired = authService.isOfflineLeaseExpired;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LockScreen(offlineLeaseExpired: leaseExpired),
      ),
      (route) => false,
    );
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
