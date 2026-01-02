import 'dart:math';

import 'package:app/model/levely_models.dart';
import 'package:app/service/levely_gamification.dart';
import 'package:app/service/levely_llm_client.dart';
import 'package:app/service/levely_prompt.dart';
import 'package:app/service/levely_quiz_bank.dart';
import 'package:app/service/levely_storage.dart';

class LevelyEngine {
  final LevelyLlmClient? llm;
  final Random _rng = Random();

  LevelyEngine({this.llm});

  Future<LevelyProgress> loadProgress() => LevelyStorage.load();

  Future<void> saveProgress(LevelyProgress progress) => LevelyStorage.save(progress);

  QuizQuestion nextQuestion({
    required LevelyProgress progress,
    required String topic,
  }) {
    final tp = progress.topicOrDefault(topic);
    final difficulty = tp.currentDifficulty;
    final candidates = LevelyQuizBank.by(topic, difficulty);
    if (candidates.isEmpty) {
      // Fallback: ambil apapun di topik tsb.
      final any = LevelyQuizBank.allQuestions().where((q) => q.topic == topic).toList();
      return any[_rng.nextInt(any.length)];
    }
    return candidates[_rng.nextInt(candidates.length)];
  }

  Future<({LevelyProgress progress, List<LevelyBadge> newlyUnlocked, int pointsDelta})> submitAnswer({
    required LevelyProgress progress,
    required QuizQuestion question,
    required int selectedIndex,
    DateTime? now,
  }) async {
    final correct = selectedIndex == question.correctIndex;
    final result = LevelyGamification.applyQuizResult(
      progress: progress,
      question: question,
      isCorrect: correct,
      now: now ?? DateTime.now(),
    );
    await saveProgress(result.progress);
    return result;
  }

  String feedbackForQuiz({
    required QuizQuestion question,
    required int selectedIndex,
    required int pointsDelta,
  }) {
    final correct = selectedIndex == question.correctIndex;
    if (correct) {
      return "Jawaban kamu sudah benar. +$pointsDelta poin.\n\n${question.explanation}";
    }
    final chosen = question.choices[selectedIndex];
    final correctChoice = question.choices[question.correctIndex];
    return "Sepertinya kamu masih bingung. Jawaban kamu: \"$chosen\".\nYang benar: \"$correctChoice\". +$pointsDelta poin.\n\n${question.explanation}\n\nMau coba contoh lain atau lanjut soal berikutnya?";
  }

  String recommendation(LevelyProgress progress) => LevelyGamification.buildRecommendation(progress);

  Future<String> answerChat({
    required String userMessage,
    required LevelyProgress progress,
    int? courseId,
    int? level,
    String? chapterName,
    String? materialSnippet,
    required List<LevelyChatMessage> history,
  }) async {
    final system = LevelyPrompt.system(appName: 'LeveLearn', assistantName: 'Levely', language: 'Indonesia');
    final ctx = LevelyPrompt.context(
      courseId: courseId,
      level: level,
      chapterName: chapterName,
      progress: progress,
      materialSnippet: materialSnippet,
    );

    // Batasi konteks percakapan agar tidak terlalu panjang.
    final recent = history.take(10).toList().reversed.toList();
    final msgs = <({String role, String content})>[
      for (final m in recent)
        (
          role: m.fromUser ? 'user' : 'assistant',
          content: m.text,
        ),
      (role: 'user', content: userMessage),
    ];

    if (llm == null) {
      return _offlineAnswer(userMessage);
    }

    final out = await llm!.complete(system: system, context: ctx, messages: msgs);
    if (out.trim().isEmpty) return _offlineAnswer(userMessage);
    return out.trim();
  }

  String _offlineAnswer(String userMessage) {
    final p = userMessage.toLowerCase();
    if (p.contains('heuristik') || p.contains('heuristics')) {
      return "Heuristik adalah aturan praktis untuk mengevaluasi UI (misalnya Nielsen). Sebutkan prinsip heuristik yang ingin kamu bahas di bab ini.";
    }
    if (p.contains('usability')) {
      return "Usability adalah seberapa mudah dan efektif user mencapai tujuan. Sebutkan metrik usability yang ingin kamu bahas di bab ini.";
    }
    return "Jelaskan topik di bab ini dan bagian yang membingungkan. Jika ada, sertakan contoh soal atau kalimatnya.";
  }
}
