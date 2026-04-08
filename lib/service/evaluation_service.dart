import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user.dart'; // import GlobalVar if needed
import '../utils/colors.dart'; 
import '../global_var.dart';

class EvaluationService {
  static Future<bool> checkHasSubmitted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.get(
        Uri.parse('${GlobalVar.baseUrl}/evaluation/questionnaire/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hasSubmitted'] ?? false;
      }
      return false;
    } catch (e) {
      print("Check Has Submitted Error: $e");
      return false;
    }
  }

  static Future<bool> submitQuestionnaire(Map<String, int> answers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${GlobalVar.baseUrl}/evaluation/questionnaire'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(answers),
      );

      return response.statusCode == 201;
    } catch (e) {
      print("Submit Questionnaire Error: $e");
      return false;
    }
  }
}
