import 'dart:convert';

class LevelyChatMessage {
  final bool fromUser;
  final String text;

  const LevelyChatMessage._(this.fromUser, this.text);

  factory LevelyChatMessage.user(String text) => LevelyChatMessage._(true, text);
  factory LevelyChatMessage.assistant(String text) => LevelyChatMessage._(false, text);
}

enum QuizDifficulty { easy, medium, hard }

enum LevelyBadgeId {
  consistency3Days,
  fastLearner,
  comeback,
  quizMaster,
  topicExplorer,
}

class LevelyBadge {
  final LevelyBadgeId id;
  final String title;
  final String description;

  const LevelyBadge({
    required this.id,
    required this.title,
    required this.description,
  });
}

class QuizQuestion {
  final String id;
  final String topic;
  final QuizDifficulty difficulty;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.topic,
    required this.difficulty,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });
}

class TopicProgress {
  final String topic;
  final int attempted;
  final int correct;
  final int correctStreak;
  final int wrongStreak;
  final QuizDifficulty currentDifficulty;

  const TopicProgress({
    required this.topic,
    required this.attempted,
    required this.correct,
    required this.correctStreak,
    required this.wrongStreak,
    required this.currentDifficulty,
  });

  double get accuracy => attempted == 0 ? 0 : (correct / attempted);

  TopicProgress copyWith({
    int? attempted,
    int? correct,
    int? correctStreak,
    int? wrongStreak,
    QuizDifficulty? currentDifficulty,
  }) {
    return TopicProgress(
      topic: topic,
      attempted: attempted ?? this.attempted,
      correct: correct ?? this.correct,
      correctStreak: correctStreak ?? this.correctStreak,
      wrongStreak: wrongStreak ?? this.wrongStreak,
      currentDifficulty: currentDifficulty ?? this.currentDifficulty,
    );
  }

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'attempted': attempted,
        'correct': correct,
        'correctStreak': correctStreak,
        'wrongStreak': wrongStreak,
        'currentDifficulty': currentDifficulty.name,
      };

  factory TopicProgress.fromJson(Map<String, dynamic> json) {
    return TopicProgress(
      topic: json['topic'] as String,
      attempted: (json['attempted'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      correctStreak: (json['correctStreak'] as num).toInt(),
      wrongStreak: (json['wrongStreak'] as num).toInt(),
      currentDifficulty: QuizDifficulty.values.byName(json['currentDifficulty'] as String),
    );
  }
}

class LevelyProgress {
  final int points;
  final int correctTotal;
  final int attemptedTotal;
  final int dailyStreak;
  final DateTime? lastActiveDate;
  final Map<String, TopicProgress> topics;
  final Set<LevelyBadgeId> badges;

  const LevelyProgress({
    required this.points,
    required this.correctTotal,
    required this.attemptedTotal,
    required this.dailyStreak,
    required this.lastActiveDate,
    required this.topics,
    required this.badges,
  });

  factory LevelyProgress.empty() => LevelyProgress(
        points: 0,
        correctTotal: 0,
        attemptedTotal: 0,
        dailyStreak: 0,
        lastActiveDate: null,
        topics: const {},
        badges: const {},
      );

  double get accuracy => attemptedTotal == 0 ? 0 : (correctTotal / attemptedTotal);

  TopicProgress topicOrDefault(String topic) {
    return topics[topic] ??
        TopicProgress(
          topic: topic,
          attempted: 0,
          correct: 0,
          correctStreak: 0,
          wrongStreak: 0,
          currentDifficulty: QuizDifficulty.easy,
        );
  }

  LevelyProgress copyWith({
    int? points,
    int? correctTotal,
    int? attemptedTotal,
    int? dailyStreak,
    DateTime? lastActiveDate,
    Map<String, TopicProgress>? topics,
    Set<LevelyBadgeId>? badges,
  }) {
    return LevelyProgress(
      points: points ?? this.points,
      correctTotal: correctTotal ?? this.correctTotal,
      attemptedTotal: attemptedTotal ?? this.attemptedTotal,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      topics: topics ?? this.topics,
      badges: badges ?? this.badges,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'correctTotal': correctTotal,
        'attemptedTotal': attemptedTotal,
        'dailyStreak': dailyStreak,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'topics': topics.map((k, v) => MapEntry(k, v.toJson())),
        'badges': badges.map((b) => b.name).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory LevelyProgress.fromJson(Map<String, dynamic> json) {
    final rawTopics = (json['topics'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final topics = <String, TopicProgress>{};
    for (final entry in rawTopics.entries) {
      topics[entry.key] = TopicProgress.fromJson((entry.value as Map).cast<String, dynamic>());
    }
    final rawBadges = (json['badges'] as List?)?.cast<dynamic>() ?? const [];
    final badges = rawBadges.map((e) => LevelyBadgeId.values.byName(e as String)).toSet();

    return LevelyProgress(
      points: (json['points'] as num?)?.toInt() ?? 0,
      correctTotal: (json['correctTotal'] as num?)?.toInt() ?? 0,
      attemptedTotal: (json['attemptedTotal'] as num?)?.toInt() ?? 0,
      dailyStreak: (json['dailyStreak'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['lastActiveDate'] == null ? null : DateTime.parse(json['lastActiveDate'] as String),
      topics: topics,
      badges: badges,
    );
  }

  factory LevelyProgress.fromJsonString(String jsonString) {
    return LevelyProgress.fromJson((jsonDecode(jsonString) as Map).cast<String, dynamic>());
  }
}
