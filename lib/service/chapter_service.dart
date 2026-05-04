import 'dart:convert';
import 'package:app/global_var.dart';
import 'package:app/model/assignment.dart';
import 'package:app/model/assessment_attempt.dart';
import 'api_cache_service.dart';
import '../model/assessment.dart';
import '../model/chapter.dart';
import '../model/learning_material.dart';

class ChapterService {
  static final Map<String, Future<AssessmentAttempt?>>
      _assessmentWarmupInFlight = {};

  static String _attemptWarmupKey(int chapterId, int userId) =>
      '$userId:$chapterId';

  static Future<AssessmentAttempt?> warmupAssessmentAttempt(
      int chapterId, int userId) async {
    final key = _attemptWarmupKey(chapterId, userId);
    final inFlight = _assessmentWarmupInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = (() async {
      final latestAttempt = await getLatestAssessmentAttempt(chapterId, userId);
      if (latestAttempt != null) {
        return null;
      }

      final currentAttempt =
          await getCurrentAssessmentAttempt(chapterId, userId);
      if (currentAttempt != null) {
        return currentAttempt;
      }

      return prefetchAssessmentAttempt(chapterId, userId);
    })();

    _assessmentWarmupInFlight[key] = future;

    try {
      return await future;
    } finally {
      if (identical(_assessmentWarmupInFlight[key], future)) {
        _assessmentWarmupInFlight.remove(key);
      }
    }
  }

  static Future<AssessmentAttempt?> waitForAssessmentWarmup(
      int chapterId, int userId) async {
    final key = _attemptWarmupKey(chapterId, userId);
    final inFlight = _assessmentWarmupInFlight[key];
    if (inFlight == null) {
      return null;
    }
    return inFlight;
  }

  static Future<LearningMaterial> getMaterialByChapterId(
    int id, {
    void Function(LearningMaterial freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/chapter/$id/materials');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          onRevalidated(
            LearningMaterial(
              id: freshResult['id'],
              chapterId: freshResult['chapterId'],
              name: freshResult['name'],
              content: freshResult['content'],
              createdAt: DateTime.parse(freshResult['createdAt']),
              updatedAt: DateTime.parse(freshResult['updatedAt']),
            ),
          );
        },
      );
      final body = response.body;
      final result = jsonDecode(body);
      LearningMaterial material = LearningMaterial(
        id: result['id'],
        chapterId: result['chapterId'],
        name: result['name'],
        content: result['content'],
        createdAt: DateTime.parse(result['createdAt']),
        updatedAt: DateTime.parse(result['updatedAt']),
      );
      return material;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<Assessment> getAssessmentByChapterId(
    int id, {
    void Function(Assessment freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/chapter/$id/assessments');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          final List<dynamic> freshDecodeQuestion = freshResult['questions'] == null
              ? []
              : (freshResult['questions'] is String
                  ? jsonDecode(freshResult['questions'])
                  : freshResult['questions']);
          final freshQuestions = freshDecodeQuestion
              .map((q) => Question(
                    id: q['id'],
                    question: q['question'] ?? 'No question text',
                    option: q['options'] != null ? List<String>.from(q['options']) : [],
                    correctedAnswer: q['correctedAnswer'] ?? q['answer'] ?? '',
                    type: q['type'] ?? 'PG',
                    elo: q['elo'] ?? 1200,
                  ))
              .toList();

          final List<String>? freshDecodedAnswers = freshResult['answers'] != null
              ? List<String>.from(jsonDecode(freshResult['answers']))
              : null;

          onRevalidated(
            Assessment(
              id: freshResult['id'],
              chapterId: freshResult['chapterId'],
              instruction: freshResult['instruction'],
              questions: freshQuestions,
              answers: freshDecodedAnswers,
              createdAt: DateTime.parse(freshResult['createdAt']),
              updatedAt: DateTime.parse(freshResult['updatedAt']),
            ),
          );
        },
      );
      final result = jsonDecode(response.body);

      if (result == null || (result is List && result.isEmpty)) {
        throw Exception("No assessments found");
      }

      final List<dynamic> decodeQuestion = result['questions'] == null
          ? []
          : (result['questions'] is String
              ? jsonDecode(result['questions'])
              : result['questions']);
      List<Question> questions = decodeQuestion
          .map((q) => Question(
                id: q['id'],
                question: q['question'] ?? 'No question text',
                option:
                    q['options'] != null ? List<String>.from(q['options']) : [],
                correctedAnswer: q['correctedAnswer'] ?? q['answer'] ?? '',
                type: q['type'] ?? 'PG',
                elo: q['elo'] ?? 1200,
              ))
          .toList();

      final List<String>? decodedAnswers = result['answers'] != null
          ? List<String>.from(jsonDecode(result['answers']))
          : null;

      Assessment assessment = Assessment(
        id: result['id'],
        chapterId: result['chapterId'],
        instruction: result['instruction'],
        questions: questions,
        answers: decodedAnswers,
        createdAt: DateTime.parse(result['createdAt']),
        updatedAt: DateTime.parse(result['updatedAt']),
      );

      return assessment;
    } catch (e) {
      throw Exception("Error fetching assessment: ${e.toString()}");
    }
  }

  static Future<AssessmentAttempt> startAssessmentAttempt(
      int chapterId, int userId,
      {bool forceNew = false}) async {
    try {
      final response = await ApiCacheService.post(
        Uri.parse('${GlobalVar.baseUrl}/assessment/attempt/start'),
        body: {
          'userId': userId,
          'chapterId': chapterId,
          'forceNew': forceNew,
        },
      );

      final dynamic result = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final message = result is Map<String, dynamic>
            ? (result['message'] ?? 'Gagal memulai assessment').toString()
            : 'Gagal memulai assessment';
        throw Exception(message);
      }

      if (result is! Map<String, dynamic>) {
        throw Exception('Payload attempt tidak valid');
      }

      return AssessmentAttempt.fromJson(result);
    } catch (e) {
      throw Exception("Error starting assessment attempt: ${e.toString()}");
    }
  }

  static Future<AssessmentAttempt> prefetchAssessmentAttempt(
      int chapterId, int userId) async {
    try {
      final response = await ApiCacheService.post(
        Uri.parse('${GlobalVar.baseUrl}/assessment/attempt/prefetch'),
        body: {
          'userId': userId,
          'chapterId': chapterId,
        },
      );

      final dynamic result = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final message = result is Map<String, dynamic>
            ? (result['message'] ?? 'Gagal prefetch assessment').toString()
            : 'Gagal prefetch assessment';
        throw Exception(message);
      }

      if (result is! Map<String, dynamic>) {
        throw Exception('Payload prefetch attempt tidak valid');
      }

      return AssessmentAttempt.fromJson(result);
    } catch (e) {
      throw Exception("Error prefetching assessment attempt: ${e.toString()}");
    }
  }

  static Future<Map<String, dynamic>> answerAssessmentQuestion({
    required int chapterId,
    required int userId,
    required int attemptId,
    required int questionId,
    required String answer,
  }) async {
    try {
      final response = await ApiCacheService.post(
        Uri.parse('${GlobalVar.baseUrl}/assessment/attempt/answer'),
        body: {
          'userId': userId,
          'chapterId': chapterId,
          'attemptId': attemptId,
          'questionId': questionId,
          'answer': answer,
        },
      );

      final dynamic result = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final message = result is Map<String, dynamic>
            ? (result['message'] ?? 'Gagal submit jawaban soal').toString()
            : 'Gagal submit jawaban soal';
        throw Exception(message);
      }

      if (result is! Map<String, dynamic>) {
        throw Exception('Payload jawaban soal tidak valid');
      }

      return result;
    } catch (e) {
      throw Exception("Error answering assessment question: ${e.toString()}");
    }
  }

  static Future<AssessmentAttempt?> getCurrentAssessmentAttempt(
      int chapterId, int userId) async {
    try {
      final response = await ApiCacheService.get(
        Uri.parse(
            '${GlobalVar.baseUrl}/assessment/attempt/current?userId=$userId&chapterId=$chapterId'),
      );

      if (response.statusCode != 200) {
        final dynamic body = jsonDecode(response.body);
        final message = body is Map<String, dynamic>
            ? (body['message'] ?? 'Gagal mengambil attempt aktif').toString()
            : 'Gagal mengambil attempt aktif';
        throw Exception(message);
      }

      if (response.body.trim().isEmpty || response.body.trim() == 'null') {
        return null;
      }

      final dynamic result = jsonDecode(response.body);
      if (result == null) {
        return null;
      }
      if (result is! Map<String, dynamic>) {
        throw Exception('Payload attempt aktif tidak valid');
      }

      return AssessmentAttempt.fromJson(result);
    } catch (e) {
      throw Exception("Error fetching current attempt: ${e.toString()}");
    }
  }

  static Future<AssessmentAttempt?> getLatestAssessmentAttempt(
      int chapterId, int userId) async {
    try {
      final response = await ApiCacheService.get(
        Uri.parse(
            '${GlobalVar.baseUrl}/assessment/attempt/latest?userId=$userId&chapterId=$chapterId'),
      );

      if (response.statusCode != 200) {
        final dynamic body = jsonDecode(response.body);
        final message = body is Map<String, dynamic>
            ? (body['message'] ?? 'Gagal mengambil attempt terakhir').toString()
            : 'Gagal mengambil attempt terakhir';
        throw Exception(message);
      }

      if (response.body.trim().isEmpty || response.body.trim() == 'null') {
        return null;
      }

      final dynamic result = jsonDecode(response.body);
      if (result == null) {
        return null;
      }
      if (result is! Map<String, dynamic>) {
        throw Exception('Payload attempt terakhir tidak valid');
      }

      return AssessmentAttempt.fromJson(result);
    } catch (e) {
      throw Exception("Error fetching latest attempt: ${e.toString()}");
    }
  }

  static Future<Assignment> getAssignmentByChapterId(
    int id, {
    void Function(Assignment freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/chapter/$id/assignments');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          onRevalidated(Assignment.fromJson(freshResult));
        },
      );
      final result = jsonDecode(response.body);

      if (result == null || (result is Map && result.isEmpty)) {
        throw Exception("No assignment found");
      }

      Assignment assignment = Assignment.fromJson(result);

      return assignment;
    } catch (e) {
      throw Exception("Error fetching assessment: ${e.toString()}");
    }
  }

  static Future<Chapter> getChapterById(
    int id, {
    void Function(Chapter freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/chapter/$id');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) {
            return;
          }
          final freshResult = jsonDecode(freshResponse.body);
          onRevalidated(Chapter.fromJson(freshResult));
        },
      );
      final result = jsonDecode(response.body);

      if (result == null || (result is Map && result.isEmpty)) {
        throw Exception("No Chapter found");
      }

      Chapter chapter = Chapter.fromJson(result);

      return chapter;
    } catch (e) {
      throw Exception("Error fetching assessment: ${e.toString()}");
    }
  }

  static Future<double> checkSimiliarity(
      String reference, String answer) async {
    Map<String, dynamic> request = {'reference': reference, 'essay': answer};
    try {
      final response = await ApiCacheService.post(Uri.parse(GlobalVar.similiarityEssayUrl),
          body: request);
      final result = jsonDecode(response.body);

      if (result == null || (result is Map && result.isEmpty)) {
        throw Exception("No Chapter found");
      }

      double similiarity = result['similarity_score'];

      return similiarity;
    } catch (e) {
      throw Exception("Error get Response Essay Similiarity: ${e.toString()}");
    }
  }
}
