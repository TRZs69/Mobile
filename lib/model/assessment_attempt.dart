import 'assessment.dart';

class AttemptProgress {
  final int poolSize;
  final int objectiveTarget;
  final int totalTarget;
  final int objectiveAnswered;
  final int objectiveCorrect;
  final int servedCount;
  final int answeredCount;
  final bool completed;

  const AttemptProgress({
    required this.poolSize,
    required this.objectiveTarget,
    required this.totalTarget,
    required this.objectiveAnswered,
    required this.objectiveCorrect,
    required this.servedCount,
    required this.answeredCount,
    required this.completed,
  });

  factory AttemptProgress.fromJson(Map<String, dynamic> map) {
    int asInt(dynamic value, int fallback) {
      if (value is int) return value;
      return int.tryParse('$value') ?? fallback;
    }

    return AttemptProgress(
      poolSize: asInt(map['poolSize'], 12),
      objectiveTarget: asInt(map['objectiveTarget'], 5),
      totalTarget: asInt(map['totalTarget'], 6),
      objectiveAnswered: asInt(map['objectiveAnswered'], 0),
      objectiveCorrect: asInt(map['objectiveCorrect'], 0),
      servedCount: asInt(map['servedCount'], 0),
      answeredCount: asInt(map['answeredCount'], 0),
      completed: map['completed'] == true,
    );
  }
}

class AssessmentAttempt {
  final int attemptId;
  final int chapterId;
  final String instruction;
  final List<Question> questions;
  final Question? currentQuestion;
  final AttemptProgress progress;
  final bool resumed;
  final String source;
  final String? status;
  final DateTime? submittedAt;
  final int? courseEloBefore;
  final int? courseEloAfter;
  final int? targetNextQuestionElo;
  final double? eloDeltaQuestion;
  final double? pointsAwardedPreview;

  AssessmentAttempt({
    required this.attemptId,
    required this.chapterId,
    required this.instruction,
    required this.questions,
    required this.currentQuestion,
    required this.progress,
    required this.resumed,
    required this.source,
    this.status,
    this.submittedAt,
    this.courseEloBefore,
    this.courseEloAfter,
    this.targetNextQuestionElo,
    this.eloDeltaQuestion,
    this.pointsAwardedPreview,
  });

  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) {
    final rawQuestions =
        json['questions'] is List ? json['questions'] as List : const [];
    final questions = rawQuestions
        .whereType<Map<String, dynamic>>()
        .map(_questionFromJson)
        .toList();
    final currentQuestionMap = json['currentQuestion'];
    final currentQuestion = currentQuestionMap is Map<String, dynamic>
        ? _questionFromJson(currentQuestionMap)
        : null;
    final progressMap = json['progress'];
    final progress = progressMap is Map<String, dynamic>
        ? AttemptProgress.fromJson(progressMap)
        : const AttemptProgress(
            poolSize: 12,
            objectiveTarget: 5,
            totalTarget: 6,
            objectiveAnswered: 0,
            objectiveCorrect: 0,
            servedCount: 0,
            answeredCount: 0,
            completed: false,
          );

    final submittedAtRaw = json['submittedAt'];

    return AssessmentAttempt(
      attemptId: json['attemptId'] is int
          ? json['attemptId'] as int
          : int.tryParse('${json['attemptId']}') ?? 0,
      chapterId: json['chapterId'] is int
          ? json['chapterId'] as int
          : int.tryParse('${json['chapterId']}') ?? 0,
      instruction: (json['instruction'] ?? '').toString(),
      questions: questions,
      currentQuestion: currentQuestion,
      progress: progress,
      resumed: json['resumed'] == true,
      source: (json['source'] ?? 'GENERATED').toString(),
      status: json['status']?.toString(),
      submittedAt: submittedAtRaw is String && submittedAtRaw.isNotEmpty
          ? DateTime.tryParse(submittedAtRaw)
          : null,
      courseEloBefore: json['courseEloBefore'] != null
          ? (json['courseEloBefore'] as num).toInt()
          : null,
      courseEloAfter: json['courseEloAfter'] != null
          ? (json['courseEloAfter'] as num).toInt()
          : null,
      targetNextQuestionElo: json['targetNextQuestionElo'] != null
          ? (json['targetNextQuestionElo'] as num).toInt()
          : null,
      eloDeltaQuestion: json['eloDeltaQuestion'] != null
          ? (json['eloDeltaQuestion'] as num).toDouble()
          : null,
      pointsAwardedPreview: json['pointsAwardedPreview'] != null
          ? (json['pointsAwardedPreview'] as num).toDouble()
          : null,
    );
  }

  Assessment toAssessment() {
    final assessmentQuestions = questions.isNotEmpty
        ? questions
        : (currentQuestion != null ? [currentQuestion!] : <Question>[]);
    return Assessment(
      id: attemptId,
      chapterId: chapterId,
      instruction: instruction,
      questions: assessmentQuestions,
      answers: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Question _questionFromJson(Map<String, dynamic> map) {
    return Question.fromJson(map);
  }
}
