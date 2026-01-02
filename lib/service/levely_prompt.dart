import 'package:app/model/levely_models.dart';

class LevelyPrompt {
  static String system({
    required String appName,
    required String assistantName,
    required String language,
  }) {
    return '''
Kamu adalah ${assistantName}, personal learning companion di aplikasi ${appName}.
Bahasa utama: ${language}. Gunakan gaya ramah, singkat, jelas.

Tujuan:
1) Menjawab pertanyaan mahasiswa tentang topik materi yang sedang dipelajari.
2) Memberi feedback reflektif berbasis progres (benar/salah, tren, langkah berikutnya).
3) Mendorong belajar aktif: tanya klarifikasi jika konteks kurang.

Aturan:
- Jangan mengaku manusia.
- Jangan menjadi chatbot umum. Jawab hanya untuk course/bab/topik yang sedang aktif.
- Jika pertanyaan di luar scope, tolak singkat dan arahkan ke bab/topik aktif.
- Jika tidak yakin, jelaskan keterbatasan dan ajukan pertanyaan klarifikasi.
- Jangan mengarang referensi/rumus yang tidak diminta.
- Feedback performa hanya setelah submission (quiz/assessment/assignment); jangan memberi evaluasi spontan di Quick-Ask.
- Tidak memberi reminder atau menyela; hanya jawab ketika ditanya.
- Jawaban ringkas, maksimal 6 kalimat, tetap edukatif.
''';
  }

  static String context({
    int? courseId,
    int? level,
    String? chapterName,
    required LevelyProgress progress,
    String? materialSnippet,
  }) {
    final parts = <String>[];
    if (courseId != null) parts.add('courseId=$courseId');
    if (level != null) parts.add('level=$level');
    if (chapterName != null && chapterName.trim().isNotEmpty) parts.add('chapter="$chapterName"');

    final topTopics = progress.topics.values.toList()
      ..sort((a, b) => b.attempted.compareTo(a.attempted));
    final topicSummary = topTopics.take(3).map((t) => '${t.topic}:${t.correct}/${t.attempted}(${(t.accuracy * 100).round()}%)').join(', ');
    final topicSummaryLabel = topicSummary.isEmpty ? '-' : topicSummary;
    final topicAttempted = progress.topicsAttempted.isEmpty ? '-' : progress.topicsAttempted.take(3).join(', ');
    final recentTrend = _trendSummary(progress);
    final lastFeedback = _trim(progress.lastFeedback ?? '', 160);
    final lastFeedbackAt = progress.lastFeedbackAt == null ? '-' : progress.lastFeedbackAt!.toIso8601String();
    final recentScores = _recentScores(progress);

    return '''
KONTEKS APP:
- ${parts.isEmpty ? 'no_context' : parts.join(' ')}

PROGRES RINGKAS:
- poin=${progress.points}
- totalQuiz=${progress.correctTotal}/${progress.attemptedTotal} (${(progress.accuracy * 100).round()}%)
- streakHarian=${progress.dailyStreak}
- topikTeratas=$topicSummaryLabel
- topikDicoba=$topicAttempted
- skorTerbaru=${recentScores.isEmpty ? '-' : recentScores}
- trenTerakhir=${recentTrend.isEmpty ? '-' : recentTrend}
- feedbackTerakhir=${lastFeedback.isEmpty ? '-' : lastFeedback}
- feedbackTerakhirAt=$lastFeedbackAt
${_materialContext(materialSnippet)}
''';
  }

  static String _materialContext(String? snippet) {
    final cleaned = snippet?.trim() ?? '';
    if (cleaned.isEmpty) return '';
    return '''

MATERI TERKAIT (cuplikan):
$cleaned
''';
  }

  static String _trendSummary(LevelyProgress progress) {
    if (progress.trend.isEmpty) return '';
    final start = progress.trend.length <= 3 ? 0 : progress.trend.length - 3;
    final recent = progress.trend.sublist(start);
    return recent.map((t) => '${_trendLabel(t.type)}:${t.value.round()}%').join(', ');
  }

  static String _trendLabel(LevelyLearningEventType type) {
    return switch (type) {
      LevelyLearningEventType.quiz => 'quiz',
      LevelyLearningEventType.assessment => 'assessment',
      LevelyLearningEventType.assignment => 'assignment',
    };
  }

  static String _recentScores(LevelyProgress progress) {
    if (progress.history.isEmpty) return '';
    final recent = progress.history.length <= 3 ? progress.history : progress.history.sublist(progress.history.length - 3);
    return recent
        .map((e) {
          final label = _trendLabel(e.type);
          if (e.score != null && e.score! > 0) return '$label:${e.score}';
          if (e.attempted != null && e.attempted! > 0 && e.correct != null) {
            final pct = ((e.correct! / e.attempted!) * 100).round();
            return '$label:${pct}%';
          }
          return '$label:-';
        })
        .join(', ');
  }

  static String _trim(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength).trim()}...';
  }
}
