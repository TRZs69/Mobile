import 'dart:convert';
import 'package:app/model/login.dart';
import 'api_cache_service.dart';

import '../global_var.dart';
import '../model/user.dart';

class UserService {
  static Future<List<Student>> getAllUser({
    void Function(List<Student> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          final freshUsers = List<Student>.from(
            freshResult.map((user) => Student.fromJson(user)),
          );
          onRevalidated(freshUsers);
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      List<Student> users = List<Student>.from(
        result.map(
            (user) => Student.fromJson(user),
        ),
      );
      return users;
    } catch(e){
      throw Exception(e.toString());
    }
  }
  static Future<List<Student>> getLeaderboard({
    int limit = 50,
    void Function(List<Student> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user/leaderboard?limit=$limit');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) return;
          final freshResult = jsonDecode(freshResponse.body);
          final freshStudents = List<Student>.from(
            freshResult.map((u) => Student.fromJson(u)),
          );
          onRevalidated(freshStudents);
        },
      );
      final result = jsonDecode(response.body);
      return List<Student>.from(
        result.map((u) => Student.fromJson(u)),
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<Student> getUserById(
    int id, {
    void Function(Student freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user/$id');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          onRevalidated(Student.fromJson(freshResult));
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      Student users = Student.fromJson(result);
      return users;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      Map<String, dynamic> request = {
        'username':username,
        'password':password
      };
      // Login uses direct post because we handle timeout/errors locally in login_screen.dart
      // and it doesn't have a token yet.
      final response = await ApiCacheService.post(Uri.parse('${GlobalVar.baseUrl}/login'), body: request);


      if (response.statusCode == 200) {
        final body = response.body;
        final result = jsonDecode(body);
        Login login = Login(
            id: result['data']['id'],
            name: result['data']['name'],
            role: result['data']['role'],
            token: result['token'],
            sessionId: result['data']['sessionId'],
        );
        return {
          'value': login,
          'code': response.statusCode
        };
      } else {
        return {
          'code': response.statusCode,
          'message': jsonDecode(response.body)['message']
        };
      }
    } catch(e) {
      throw Exception(e.toString());
    }
  }

  static Future<Student> patchUser(Student user, Map<String, dynamic> patchData) async {
    try {
      final response = await ApiCacheService.patch(
        Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'),
        body: patchData,
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to patch user');
      }

      final result = jsonDecode(response.body);
      return Student.fromJson(result['user']);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<Student> updateUser(Student user) async {
    try {
      Map<String, dynamic> request = {
        "name": user.name,
        "username": user.username,
        "role": user.role,
        "studentId": user.studentId,
        "points": user.points,
        "totalCourses": user.totalCourses,
        "badges": user.badges,
        "image": user.image,
        "instructorId": user.instructorId,
        "instructorCourses": user.instructorCourses
      };
      final response = await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'), body: request);

      final body = response.body;
      final result = jsonDecode(body);
      Student users = Student.fromJson(result['user']);
      return users;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<void> updatePassword(Student user) async {
    try {
      Map<String, dynamic> request = {
        "password": user.password,
      };
      await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'), body: request);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<Student> updateUserPoints (Student user) async {
    try {
      Map<String, dynamic> request = {
        "points": user.points,
      };
      final response = await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'), body: request);

      final body = response.body;
      final result = jsonDecode(body);
      Student users = Student.fromJson(result['user']);
      return users;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<Student> updateUserPointsAndBadge (Student user) async {
    try {
      Map<String, dynamic> request = {
        "points": user.points,
      };
      final response = await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'), body: request);

      final body = response.body;
      final result = jsonDecode(body);
      Student users = Student.fromJson(result['user']);
      return users;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<void> updateUserPhoto(Student user) async {
    try {
      Map<String, dynamic> request = {
        "image": user.image,
      };
      await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/user/${user.id}'), body: request);
    } catch(e){
      throw Exception(e.toString());
    }
  }
}
