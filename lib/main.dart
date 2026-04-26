import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/utils/colors.dart';
import 'package:app/view/login_screen.dart';
import 'package:app/view/main_screen.dart';
import 'package:app/view/onboarding_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Terjadi kesalahan tampilan. Silakan kembali ke halaman sebelumnya.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'DIN_Next_Rounded',
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    await Supabase.initialize(
      url: 'https://itarozdimxukkhwxruti.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aXZmcW5xeG5wZnBpanJ2a2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2MTQxMjEsImV4cCI6MjA3NDE5MDEyMX0.VwNktSJnyCuvBHEEMw4hv4wsHm7wT1MxS6foqR2i4Nk',
    );

    runApp(const LevelyApp());
  }, (error, stack) {
    debugPrint('runZonedGuarded error: $error');
  });
}

class LevelyApp extends StatelessWidget {
  const LevelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Levelearn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late final Future<_InitialDestination> _initialDestinationFuture;

  @override
  void initState() {
    super.initState();
    _initialDestinationFuture = _resolveInitialDestination();
  }

  Future<_InitialDestination> _resolveInitialDestination() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt('userId');
    final token = prefs.getString('token') ?? '';
    final hasSession = userId != null && token.isNotEmpty;

    if (hasSession) {
      await prefs.setBool('firstLaunch', false);
      return _InitialDestination.mainApp;
    }

    final isFirstLaunch = prefs.getBool('firstLaunch') ?? true;
    return isFirstLaunch
        ? _InitialDestination.onboarding
        : _InitialDestination.login;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InitialDestination>(
      future: _initialDestinationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Gagal memuat aplikasi',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        switch (snapshot.data) {
          case _InitialDestination.mainApp:
            return const Mainscreen();
          case _InitialDestination.login:
            return const LoginScreen();
          case _InitialDestination.onboarding:
          default:
            return const OnboardingScreen();
        }
      },
    );
  }
}

enum _InitialDestination { onboarding, login, mainApp }
