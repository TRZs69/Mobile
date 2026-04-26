import 'dart:ui';

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

  // Use dart-define override when provided, otherwise fall back to sensible defaults.
  static String _resolveBaseUrl() {
    const envBaseUrl = String.fromEnvironment('LEVELEARN_API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    return 'https://backend-render-proxy.onrender.com/api';
  }
}

final globalVars = GlobalVar();
