import 'dart:convert';
import 'package:app/model/chapter_status.dart';
import 'package:http/http.dart' as http;

import '../global_var.dart';

class UserChapterService {

  static Future<ChapterStatus> getChapterStatus(int idUser, int idChapter) async {
    try {
      late ChapterStatus status;
      final response = await http.get(Uri.parse('${GlobalVar.baseUrl}/userchapter/$idUser/$idChapter'));
      final body = response.body;
      final result = jsonDecode(body);
      if (result is List && result.isNotEmpty) {
        status = ChapterStatus.fromJson(result[0]);
      } else {
         Map<String, dynamic> request = {
           "userId": idUser,
           "chapterId": idChapter,
           "isCompleted": false,
           "isStarted": false,
           "materialDone": false,
           "assessmentDone": false,
           "assignmentDone": false,
           "assessmentAnswer": "[]",
           "submission": "",
           "assessmentGrade": 0,
           "timeStarted": DateTime.now().toUtc().toIso8601String(),
           "timeFinished": DateTime.now().toUtc().toIso8601String()
         };
         final responsePost = await http.post(Uri.parse('${GlobalVar.baseUrl}/userchapter'), headers: {
           'Content-type' : 'application/json; charset=utf-8',
           'Accept': 'application/json',
         }, body: jsonEncode(request));

         if (responsePost.statusCode == 201) {
           final body = responsePost.body;
           final resultPost = jsonDecode(body);
           status = ChapterStatus.fromJson(resultPost['userChapter']);
         }
      }
      return status;
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<ChapterStatus> updateChapterStatus(int id, ChapterStatus user) async {
    try {
      late ChapterStatus status;
      Map<String, dynamic> request = {
        "isStarted": user.isStarted,
        "isCompleted": user.isCompleted,
        "materialDone": user.materialDone,
        "assessmentDone": user.assessmentDone,
        "assignmentDone": user.assignmentDone,
        "assessmentAnswer": jsonEncode(user.assessmentAnswer),
        "submission": user.submission,
        "assessmentGrade": user.assessmentGrade,
        "assessmentPointsEarned": user.assessmentPointsEarned,
        "timeStarted": user.timeStarted.toUtc().toIso8601String(),
        "timeFinished": user.timeFinished.toUtc().toIso8601String(),
      };

      final responsePut = await http.put(Uri.parse('${GlobalVar.baseUrl}/userchapter/$id'), headers: {
        'Content-type' : 'application/json; charset=utf-8',
        'Accept': 'application/json',
      }, body: jsonEncode(request));

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