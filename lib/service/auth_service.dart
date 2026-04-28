import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('name');
    await prefs.remove('role');
    await prefs.remove('token');
    await prefs.remove('sessionId');
    await prefs.remove('lastestSelectedCourse');
    await prefs.remove('latestSelectedCourse');
    await prefs.remove('getCourseDetail');
  }
}
