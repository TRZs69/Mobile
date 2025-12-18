import 'package:app/model/levely_models.dart';

class LevelyGamification {
  static const badgeCatalog = <LevelyBadge>[
    LevelyBadge(
      id: LevelyBadgeId.consistency3Days,
      title: 'Consistency',
      description: 'Belajar 3 hari berturut-turut.',
    ),
    LevelyBadge(
      id: LevelyBadgeId.fastLearner,
      title: 'Fast Learner',
      description: 'Banyak jawaban benar di awal latihan.',
    ),
    LevelyBadge(
      id: LevelyBadgeId.comeback,
      title: 'Comeback',
      description: 'Berhasil bangkit setelah beberapa kali salah.',
    ),
    LevelyBadge(
      id: LevelyBadgeId.quizMaster,
      title: 'Quiz Master',
      description: 'Total 20 jawaban benar.',
    ),
    LevelyBadge(
      id: LevelyBadgeId.topicExplorer,
      title: 'Topic Explorer',
      description: 'Mencoba kuis di 3 topik berbeda.',
    ),
  ];

  static int pointsForAnswer({
    required QuizDifficulty difficulty,
    required bool isCorrect,
    required int correctStreak,
    required int wrongStreak,
  }) {
    final base = switch (difficulty) {
      QuizDifficulty.easy => 10,
      QuizDifficulty.medium => 20,
      QuizDifficulty.hard => 30,
    };

    if (!isCorrect) {
      // Penalti adaptif: makin sering salah beruntun, "attempt point" makin kecil.
      final attempt = (base * 0.15).round(); // 2/3/5
      final penalty = (1 - (wrongStreak.clamp(0, 4) * 0.15)).clamp(0.4, 1.0);
      return (attempt * penalty).round();
    }

    // Bonus adaptif: makin panjang streak benar, poin makin besar.
    final streakBonus = 1 + (correctStreak.clamp(0, 6) * 0.12);
    return (base * streakBonus).round();
  }

  static QuizDifficulty adjustDifficulty(TopicProgress p) {
    // Aturan sederhana (3 level):
    // - Jika benar beruntun >= 3 atau akurasi tinggi -> naik
    // - Jika salah beruntun >= 2 atau akurasi rendah -> turun
    if (p.correctStreak >= 3 || (p.attempted >= 6 && p.accuracy >= 0.80)) {
      return switch (p.currentDifficulty) {
        QuizDifficulty.easy => QuizDifficulty.medium,
        QuizDifficulty.medium => QuizDifficulty.hard,
        QuizDifficulty.hard => QuizDifficulty.hard,
      };
    }
    if (p.wrongStreak >= 2 || (p.attempted >= 6 && p.accuracy <= 0.45)) {
      return switch (p.currentDifficulty) {
        QuizDifficulty.hard => QuizDifficulty.medium,
        QuizDifficulty.medium => QuizDifficulty.easy,
        QuizDifficulty.easy => QuizDifficulty.easy,
      };
    }
    return p.currentDifficulty;
  }

  static ({LevelyProgress progress, List<LevelyBadge> newlyUnlocked, int pointsDelta}) applyQuizResult({
    required LevelyProgress progress,
    required QuizQuestion question,
    required bool isCorrect,
    required DateTime now,
  }) {
    final updatedStreak = _updateDailyStreak(progress, now);
    final beforeTopic = updatedStreak.topicOrDefault(question.topic);
    final comebackTrigger = isCorrect && beforeTopic.wrongStreak >= 3;

    final attempted = beforeTopic.attempted + 1;
    final correct = beforeTopic.correct + (isCorrect ? 1 : 0);
    final correctStreak = isCorrect ? beforeTopic.correctStreak + 1 : 0;
    final wrongStreak = isCorrect ? 0 : beforeTopic.wrongStreak + 1;
    final pointsDelta = pointsForAnswer(
      difficulty: question.difficulty,
      isCorrect: isCorrect,
      correctStreak: correctStreak,
      wrongStreak: wrongStreak,
    );

    final afterTopicBase = beforeTopic.copyWith(
      attempted: attempted,
      correct: correct,
      correctStreak: correctStreak,
      wrongStreak: wrongStreak,
    );
    final nextDifficulty = adjustDifficulty(afterTopicBase);
    final afterTopic = afterTopicBase.copyWith(currentDifficulty: nextDifficulty);

    final topics = Map<String, TopicProgress>.from(updatedStreak.topics);
    topics[question.topic] = afterTopic;

    var next = updatedStreak.copyWith(
      points: updatedStreak.points + pointsDelta,
      attemptedTotal: updatedStreak.attemptedTotal + 1,
      correctTotal: updatedStreak.correctTotal + (isCorrect ? 1 : 0),
      topics: topics,
    );

    final unlocked = <LevelyBadge>[];
    next = _checkBadges(next, newlyUnlocked: unlocked, comebackTrigger: comebackTrigger);
    return (progress: next, newlyUnlocked: unlocked, pointsDelta: pointsDelta);
  }

  static LevelyProgress _updateDailyStreak(LevelyProgress p, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = p.lastActiveDate == null
        ? null
        : DateTime(p.lastActiveDate!.year, p.lastActiveDate!.month, p.lastActiveDate!.day);

    if (last == null) {
      return p.copyWith(dailyStreak: 1, lastActiveDate: today);
    }

    final diffDays = today.difference(last).inDays;
    if (diffDays == 0) {
      return p.copyWith(lastActiveDate: today);
    }
    if (diffDays == 1) {
      return p.copyWith(dailyStreak: p.dailyStreak + 1, lastActiveDate: today);
    }
    return p.copyWith(dailyStreak: 1, lastActiveDate: today);
  }

  static LevelyProgress _checkBadges(
    LevelyProgress p, {
    required List<LevelyBadge> newlyUnlocked,
    required bool comebackTrigger,
  }) {
    final unlocked = Set<LevelyBadgeId>.from(p.badges);

    void award(LevelyBadgeId id) {
      if (unlocked.contains(id)) return;
      unlocked.add(id);
      newlyUnlocked.add(badgeCatalog.firstWhere((b) => b.id == id));
    }

    if (p.dailyStreak >= 3) award(LevelyBadgeId.consistency3Days);
    if (p.correctTotal >= 20) award(LevelyBadgeId.quizMaster);
    if (p.topics.keys.length >= 3) award(LevelyBadgeId.topicExplorer);

    // Fast Learner: 5 benar dalam 7 attempt pertama.
    if (p.attemptedTotal <= 7 && p.correctTotal >= 5) award(LevelyBadgeId.fastLearner);

    // Comeback: benar setelah salah beruntun (>=3) di topik yang sama.
    if (comebackTrigger) award(LevelyBadgeId.comeback);

    return p.copyWith(badges: unlocked);
  }

  static String buildRecommendation(LevelyProgress p) {
    if (p.attemptedTotal < 3) {
      return "Mulai dengan kuis mudah dulu. Setelah itu, Levely bisa kasih rekomendasi berdasarkan progresmu.";
    }

    TopicProgress? weakest;
    TopicProgress? strongest;
    for (final tp in p.topics.values) {
      if (tp.attempted < 3) continue;
      if (weakest == null || tp.accuracy < weakest!.accuracy) weakest = tp;
      if (strongest == null || tp.accuracy > strongest!.accuracy) strongest = tp;
    }

    if (weakest != null && weakest!.accuracy <= 0.55) {
      return "Kamu masih sering salah di topik ${weakest!.topic}. Coba ulangi materi inti topik itu, lalu latihan kuis ${weakest!.currentDifficulty.name} lagi.";
    }
    if (strongest != null && strongest!.accuracy >= 0.85) {
      return "Kamu sudah kuat di topik ${strongest!.topic}. Kamu bisa lanjut ke level berikutnya atau coba kuis yang lebih sulit.";
    }
    return "Progresmu stabil. Lanjutkan latihan, dan fokuskan 1 topik sampai akurasimu naik.";
  }
}
