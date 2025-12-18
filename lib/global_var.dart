import 'dart:ui';
import 'package:flutter/foundation.dart';

class GlobalVar {
  static final GlobalVar _instance = GlobalVar._internal();

  factory GlobalVar() {
    return _instance;
  }

  GlobalVar._internal();
  static String url = 'https://www.globalcareercounsellor.com/blog/wp-content/uploads/2018/05/Online-Career-Counselling-course.jpg';
  static String baseUrl = _resolveBaseUrl();
  static String similiarityEssayUrl = 'http://31.97.67.152:8081/evaluate/';
  static const Color primaryColor = Color.fromARGB(255, 68, 31, 127);
  static const Color secondaryColor = Color.fromARGB(255, 26, 173, 33);
  static const Color accentColor = Color.fromARGB(255, 221, 200, 255);

  // Use Android emulator loopback when needed, otherwise fall back to localhost.
  static String _resolveBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:7000/api';
    }
    return 'http://127.0.0.1:7000/api';
  }
}

// Create an instance
final globalVars = GlobalVar();
