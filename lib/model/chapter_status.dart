
import 'dart:convert';

class ChapterStatus {
  int id;
  int userId;
  int chapterId;
  bool isCompleted;
  bool isStarted;
  bool materialDone;
  bool assessmentDone;
  bool assignmentDone;
  List<String> assessmentAnswer;
  int assessmentGrade;
  int assessmentEloDelta;
  int assessmentPointsEarned;
  String? submission;
  DateTime timeStarted;
  DateTime timeFinished;
  int assignmentScore;
  String assignmentFeedback;
  DateTime createdAt;
  DateTime updatedAt;

  ChapterStatus({
    required this.id,
    required this.userId,
    required this.chapterId,
    required this.isCompleted,
    required this.isStarted,
    required this.materialDone,
    required this.assessmentDone,
    required this.assignmentDone,
    required this.assessmentAnswer,
    required this.assessmentGrade,
    required this.assessmentEloDelta,
    this.assessmentPointsEarned = 0,
    this.submission,
    required this.timeStarted,
    required this.timeFinished,
    required this.assignmentScore,
    required this.assignmentFeedback,
    required this.createdAt,
    required this.updatedAt
  });

  factory ChapterStatus.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    List<String> parseAnswers(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return ChapterStatus(
      id: safeInt(json['id']),
      userId: safeInt(json['userId']),
      chapterId: safeInt(json['chapterId']),
      isStarted: json['isStarted'] == true,
      isCompleted: json['isCompleted'] == true,
      materialDone: json['materialDone'] == true,
      assessmentDone: json['assessmentDone'] == true,
      assignmentDone: json['assignmentDone'] == true,
      assessmentAnswer: parseAnswers(json['assessmentAnswer']),
      assessmentGrade: safeInt(json['assessmentGrade']),
      assessmentEloDelta: safeInt(json['assessmentEloDelta']),
      assessmentPointsEarned: safeInt(json['assessmentPointsEarned']),
      submission: json['submission']?.toString(),
      timeStarted: DateTime.parse(json['timeStarted'] ?? DateTime.now().toIso8601String()),
      timeFinished: DateTime.parse(json['timeFinished'] ?? DateTime.now().toIso8601String()),
      assignmentScore: safeInt(json['assignmentScore']),
      assignmentFeedback: json['assignmentFeedback']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'chapterId': chapterId,
      'isCompleted': isCompleted,
      'isStarted': isStarted,
      'materialDone': materialDone,
      'assessmentDone': assessmentDone,
      'assignmentDone': assignmentDone,
      'assessmentAnswer': assessmentAnswer,
      'assessmentGrade': assessmentGrade,
      'assessmentEloDelta': assessmentEloDelta,
      'assessmentPointsEarned': assessmentPointsEarned,
      'submission': submission,
      'timeStarted': timeStarted.toUtc().toIso8601String(),
      'timeFinished': timeFinished.toUtc().toIso8601String(),
      'assignmentScore': assignmentScore,
      'assignmentFeedback': assignmentFeedback,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}