import 'dart:convert';
import 'package:app/model/chapter.dart';
import 'api_cache_service.dart';

import '../global_var.dart';
import '../model/course.dart';

class CourseService {
  static Future<List<Course>> getEnrolledCourse(
    int id, {
    void Function(List<Course> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user/$id/courses');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          final freshCourses = List<Course>.from(
            freshResult.map((item) => Course.fromJson(item)),
          );
          onRevalidated(freshCourses);
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      List<Course> courses = List<Course>.from(
        result.map(
              (result) => Course.fromJson(result)
        ),
      );
      return courses;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<Course> getCourse(
    int id, {
    void Function(Course freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/course/$id');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          onRevalidated(
            Course(
              id: freshResult['id'],
              courseName: freshResult['name'],
              codeCourse: freshResult['code'],
              description: freshResult['description'],
              image: freshResult['image'],
              createdAt: DateTime.parse(freshResult['createdAt']),
              updatedAt: DateTime.parse(freshResult['updatedAt']),
              progress: 0,
            ),
          );
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      Course courses = Course(
        id: result['id'],
        courseName: result['name'],
        codeCourse: result['code'],
        description: result['description'],
        image: result['image'],
        createdAt: DateTime.parse(result['createdAt']),
        updatedAt: DateTime.parse(result['updatedAt']),
        progress: 0
      );
      return courses;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<List<Chapter>> getChapterByCourse(
    int id, {
    void Function(List<Chapter> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/course/$id/chapters');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          final freshChapters = List<Chapter>.from(
            freshResult.map((item) => Chapter.fromJson(item)),
          );
          onRevalidated(freshChapters);
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      List<Chapter> chapter = List.from(
        result.map((result) => Chapter.fromJson(result))
      );
      return chapter;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<List<Chapter>> getChapterByCourseForUser(
    int courseId,
    int userId, {
    void Function(List<Chapter> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/course/$courseId/chapters/user/$userId');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          final freshChapters = List<Chapter>.from(
            freshResult.map((item) => Chapter.fromJson(item)),
          );
          onRevalidated(freshChapters);
        },
      );
      final result = jsonDecode(response.body);

      return List<Chapter>.from(
        result.map((item) => Chapter.fromJson(item)),
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}