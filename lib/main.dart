import 'package:app/utils/colors.dart';
import 'package:app/view/login_screen.dart';
import 'package:app/view/main_screen.dart';
import 'package:app/view/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Color purple = AppColors.primaryColor;
Color backgroundNavHex = Color(0xFFF3EDF7);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = prefs.getBool('firstLaunch') ?? true;
  final bool isLoggedIn = await checkLoginStatus();

  await Supabase.initialize(
      url: "https://vvivfqnqxnpfpijrvkkb.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aXZmcW5xeG5wZnBpanJ2a2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2MTQxMjEsImV4cCI6MjA3NDE5MDEyMX0.VwNktSJnyCuvBHEEMw4hv4wsHm7wT1MxS6foqR2i4Nk"
  );
  runApp(MyApp(isLoggedIn: isLoggedIn, isFirstLaunch: isFirstLaunch));
}

Future<bool> checkLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  return token != null;
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isFirstLaunch;

  const MyApp({super.key, required this.isLoggedIn, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (isFirstLaunch) {
      home = OnboardingScreen();
    } else if (isLoggedIn) {
      home = Mainscreen();
    } else {
      home = LoginScreen();
    }

    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: home
    );
  }
}