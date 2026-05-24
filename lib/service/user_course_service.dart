import "package:flutter/foundation.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_cache_service.dart';

import '../global_var.dart';
import '../model/user_course.dart';

class UserCourseService {
  static Future<UserCourse> getUserCourse(
    int idUser,
    int idCourse, {
    void Function(UserCourse freshData)? onRevalidated,
  }) async {
    try {
      late UserCourse status;
      final uri =
          Uri.parse('${GlobalVar.baseUrl}/usercourse/$idUser/$idCourse');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          if (freshResult is List && freshResult.isNotEmpty) {
            onRevalidated(UserCourse.fromJson(freshResult[0]));
          }
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      debugPrint(result);
      if (result is List && result.isNotEmpty) {
        status = UserCourse.fromJson(result[0]);
      }
      return status;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<void> updateUserCourse(int id, UserCourse uc) async {
    try {
      Map<String, dynamic> request = {
        "userId": uc.userId,
        "courseId": uc.courseId,
        "progress": uc.progress,
        "currentChapter": uc.currentChapter,
        "isCompleted": uc.isCompleted,
        "enrolledAt": uc.enrolledAt.toIso8601String()
      };
      final responsePut =
          await http.put(Uri.parse('${GlobalVar.baseUrl}/usercourse/$id'),
              headers: {
                'Content-type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
              },
              body: jsonEncode(request));

      if (responsePut.statusCode == 200) {
        await ApiCacheService.clearCacheContaining(
            '/user/${uc.userId}/courses');
        await ApiCacheService.clearCacheContaining(
            '/usercourse/${uc.userId}/${uc.courseId}');
        debugPrint("Update Successful");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
