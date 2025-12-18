import 'package:app/model/levely_models.dart';

class LevelyPrompt {
  static String system({
    required String appName,
    required String assistantName,
    required String language,
  }) {
    return '''
Kamu adalah ${assistantName}, asisten belajar di aplikasi gamified ${appName}.
Bahasa utama: ${language}. Gunakan gaya ramah, singkat, jelas.

Tujuan:
1) Menjawab pertanyaan mahasiswa tentang topik materi.
2) Memberi feedback berbasis input pengguna (mis. benar/salah, bagian yang perlu ditingkatkan).
3) Mendorong belajar aktif: tanya klarifikasi jika konteks kurang.

Aturan:
- Jangan mengaku manusia.
- Jika tidak yakin, jelaskan keterbatasan dan ajukan pertanyaan klarifikasi.
- Jangan mengarang referensi/rumus yang tidak diminta.
- Format jawaban: 
  (a) Jawaban inti 2–5 kalimat
  (b) Langkah/poin penting (bullet 3–6)
  (c) Pertanyaan balik 1 kalimat untuk cek pemahaman
''';
  }

  static String context({
    int? courseId,
    int? level,
    String? chapterName,
    required LevelyProgress progress,
  }) {
    final parts = <String>[];
    if (courseId != null) parts.add('courseId=$courseId');
    if (level != null) parts.add('level=$level');
    if (chapterName != null && chapterName.trim().isNotEmpty) parts.add('chapter="$chapterName"');

    final topTopics = progress.topics.values.toList()
      ..sort((a, b) => b.attempted.compareTo(a.attempted));
    final topicSummary = topTopics.take(3).map((t) => '${t.topic}:${t.correct}/${t.attempted}(${(t.accuracy * 100).round()}%)').join(', ');

    return '''
KONTEKS APP:
- ${parts.isEmpty ? 'no_context' : parts.join(' ')}

PROGRES RINGKAS:
- poin=${progress.points}
- totalQuiz=${progress.correctTotal}/${progress.attemptedTotal} (${(progress.accuracy * 100).round()}%)
- streakHarian=${progress.dailyStreak}
- topikTeratas=$topicSummary
''';
  }
}

