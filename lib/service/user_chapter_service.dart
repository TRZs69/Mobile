import 'dart:convert';
import 'package:app/model/chapter_status.dart';
import 'api_cache_service.dart';

import '../global_var.dart';

class UserChapterService {

  static Future<ChapterStatus> getChapterStatus(int idUser, int idChapter) async {
    try {
      final response = await ApiCacheService.get(Uri.parse('${GlobalVar.baseUrl}/userchapter/$idUser/$idChapter'));
      
      if(response.statusCode == 200) {
        final body = response.body;
        final result = jsonDecode(body);
        return ChapterStatus.fromJson(result['data']);
      } else {
        // Return a default status if none exists for this user/chapter yet
        return ChapterStatus(
          id: 0,
          userId: idUser,
          chapterId: idChapter,
          isCompleted: false,
          isStarted: false,
          materialDone: false,
          assessmentDone: false,
          assignmentDone: false,
          assessmentAnswer: [],
          assessmentGrade: 0,
          assessmentEloDelta: 0,
          submission: '',
          timeStarted: DateTime.now(),
          timeFinished: DateTime.now(),
          assignmentScore: 0,
          assignmentFeedback: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<void> createUserChapter(int userId, int chapterId) async{
    try {
      await ApiCacheService.post(Uri.parse('${GlobalVar.baseUrl}/userchapter'), body: {
        'userId': userId,
        'chapterId': chapterId
      });
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<ChapterStatus> updateChapterStatus(int id, ChapterStatus status) async {
    try {
      final responsePut = await ApiCacheService.put(
        Uri.parse('${GlobalVar.baseUrl}/userchapter/$id'),
        body: status.toJson(),
      );

      if (responsePut.statusCode == 200) {
        final body = responsePut.body;
        final result = jsonDecode(body);
        status = ChapterStatus.fromJson(result['data']);
      }

      return status;
    } catch(e){
      throw Exception(e.toString());
    }
  }
}
