import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/service/auth_service.dart';
import 'package:app/view/login_screen.dart';

class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const SessionTimeoutWrapper({
    Key? key,
    required this.child,
    this.timeout = const Duration(minutes: 30),
  }) : super(key: key);

  @override
  _SessionTimeoutWrapperState createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper>
    with WidgetsBindingObserver {
  Timer? _timer;
  static const String _lastActivityKey = 'last_activity_timestamp';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSessionOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionOnStart();
    }
  }

  Future<void> _checkSessionOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivityStr = prefs.getString(_lastActivityKey);

    if (lastActivityStr != null) {
      final lastActivity = DateTime.parse(lastActivityStr);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      if (difference >= widget.timeout) {
        _handleTimeout();
        return;
      }
    }

    _startTimer();
  }

  DateTime? _lastRecordedTime;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeout);
    _recordActivity();
  }

  Future<void> _recordActivity() async {
    final now = DateTime.now();
    if (_lastRecordedTime != null &&
        now.difference(_lastRecordedTime!).inSeconds < 5) {
      return;
    }
    _lastRecordedTime = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActivityKey, now.toIso8601String());
  }

  void _handleTimeout() async {
    await AuthService.logout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesi berakhir karena tidak ada aktivitas."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleUserInteraction([_]) {
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      child: widget.child,
    );
  }
}
