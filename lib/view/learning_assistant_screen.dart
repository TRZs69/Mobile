import 'package:app/utils/colors.dart';
import 'package:app/model/levely_models.dart';
import 'package:app/service/levely_gamification.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/levely_companion.dart';
import 'package:app/service/levely_quiz_bank.dart';
import 'package:flutter/material.dart';

class LearningAssistantScreen extends StatefulWidget {
  final int? courseId;
  final int? level;
  final String? chapterName;
  final int? chapterId;
  final List<LevelyChatMessage>? initialMessages;

  const LearningAssistantScreen({
    super.key,
    this.courseId,
    this.level,
    this.chapterName,
    this.chapterId,
    this.initialMessages,
  });

  @override
  State<LearningAssistantScreen> createState() => _LearningAssistantScreenState();
}

class _LearningAssistantScreenState extends State<LearningAssistantScreen> {
  final LevelyCompanion _companion = LevelyCompanion();
  final TextEditingController _composer = TextEditingController();
  final List<LevelyChatMessage> _messages = [];
  LevelyProgress _progress = LevelyProgress.empty();
  bool _loadingProgress = false;
  int _tabIndex = 1; // 0 chat, 1 quiz
  String? _materialContent;

  String _selectedTopic = LevelyQuizBank.topics.first;
  QuizQuestion? _question;
  int? _selectedChoice;
  String? _quizFeedback;

  @override
  void initState() {
    super.initState();
    _question = _pickQuestion(
      topic: _selectedTopic,
      difficulty: _progress.topicOrDefault(_selectedTopic).currentDifficulty,
    );
    _loadProgress();
    _loadMaterial();

    if (widget.initialMessages != null && widget.initialMessages!.isNotEmpty) {
      _messages.addAll(widget.initialMessages!);
      return;
    }

    _messages.insert(
      0,
      LevelyChatMessage.assistant(
        "Halo! Aku Levely. Tanyakan soal bab atau topik yang sedang kamu pelajari.",
      ),
    );
    if (widget.courseId != null || widget.level != null || widget.chapterName != null) {
      _messages.insert(0, LevelyChatMessage.assistant(_contextSummary()));
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    setState(() => _loadingProgress = true);
    final progress = await _companion.loadProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _question = _pickQuestion(
        topic: _selectedTopic,
        difficulty: _progress.topicOrDefault(_selectedTopic).currentDifficulty,
      );
      _loadingProgress = false;
    });
  }

  Future<void> _loadMaterial() async {
    final chapterId = widget.chapterId;
    if (chapterId == null) return;
    try {
      final material = await ChapterService.getMaterialByChapterId(chapterId);
      if (!mounted) return;
      setState(() {
        _materialContent = material.content;
      });
    } catch (_) {
      // Ignore material load failures; fallback to non-RAG answers.
    }
  }

  String _contextSummary() {
    final parts = <String>[];
    if (widget.courseId != null) parts.add("Course ID: ${widget.courseId}");
    if (widget.level != null) parts.add("Level: ${widget.level}");
    if (widget.chapterName != null && widget.chapterName!.trim().isNotEmpty) {
      parts.add("Bab: ${widget.chapterName}");
    }
    return parts.isEmpty ? "" : "Konteks aktif: ${parts.join(" • ")}";
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    _composer.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.insert(0, LevelyChatMessage.user(text));
      _messages.insert(0, LevelyChatMessage.assistant(_mockTyping()));
    });

    final history = _messages.skip(1).toList();
    final reply = await _companion.quickAsk(
      prompt: text,
      progress: _progress,
      history: history,
      courseId: widget.courseId,
      level: widget.level,
      chapterName: widget.chapterName,
      materialContent: _materialContent,
    );
    if (!mounted) return;
    setState(() {
      _messages.removeAt(0);
      _messages.insert(0, LevelyChatMessage.assistant(reply));
    });
  }

  String _mockTyping() => ".";

  QuizQuestion _pickQuestion({required String topic, required QuizDifficulty difficulty}) {
    final candidates = LevelyQuizBank.by(topic, difficulty);
    return candidates.isNotEmpty ? candidates.first : LevelyQuizBank.allQuestions().first;
  }

  Future<void> _startNewQuestion() async {
    final next = _pickQuestion(
      topic: _selectedTopic,
      difficulty: _progress.topicOrDefault(_selectedTopic).currentDifficulty,
    );
    setState(() {
      _question = next;
      _selectedChoice = null;
      _quizFeedback = null;
    });
  }

  Future<void> _submitQuiz() async {
    final q = _question;
    final selected = _selectedChoice;
    if (q == null || selected == null) return;

    final result = await _companion.observeQuiz(
      progress: _progress,
      question: q,
      selectedIndex: selected,
      now: DateTime.now(),
    );
    if (!mounted) return;

    setState(() {
      _progress = result.progress;
      _quizFeedback = result.feedback;
    });

    if (result.newlyUnlocked.isNotEmpty) {
      final title = result.newlyUnlocked.map((b) => b.title).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Badge baru terbuka: $title")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/assets/pictures/background-pattern.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: AppColors.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Levely",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _ProgressHeader(progress: _progress, loading: _loadingProgress),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Chat'), icon: Icon(Icons.chat_bubble_outline)),
                      ButtonSegment(value: 1, label: Text('Kuis'), icon: Icon(Icons.quiz_outlined)),
                    ],
                    selected: {_tabIndex},
                    onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                if (widget.courseId != null || widget.level != null || widget.chapterName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _ContextChips(
                      courseId: widget.courseId,
                      level: widget.level,
                      chapterName: widget.chapterName,
                    ),
                  ),
                Expanded(child: _tabIndex == 0 ? _buildChat() : _buildQuiz()),
                if (_tabIndex == 0)
                  _Composer(
                    controller: _composer,
                    onSend: _send,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChat() {
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: _messages.length,
      separatorBuilder: (context, _) => const SizedBox(height: 2),
      itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _buildQuiz() {
    final q = _question ?? _pickQuestion(topic: _selectedTopic, difficulty: _progress.topicOrDefault(_selectedTopic).currentDifficulty);
    _question = q;

    final tp = _progress.topicOrDefault(_selectedTopic);
    final diffLabel = switch (tp.currentDifficulty) {
      QuizDifficulty.easy => 'Mudah',
      QuizDifficulty.medium => 'Sedang',
      QuizDifficulty.hard => 'Sulit',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            color: Colors.white.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTopic,
                          decoration: InputDecoration(
                            labelText: 'Topik',
                            labelStyle: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: LevelyQuizBank.topics
                              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontFamily: 'DIN_Next_Rounded'))))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedTopic = v;
                              _question = _companion.engine.nextQuestion(progress: _progress, topic: _selectedTopic);
                              _selectedChoice = null;
                              _quizFeedback = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Level: $diffLabel',
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    q.prompt,
                    style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < q.choices.length; i++)
                    RadioListTile<int>(
                      value: i,
                      groupValue: _selectedChoice,
                      onChanged: _quizFeedback == null ? (v) => setState(() => _selectedChoice = v) : null,
                      title: Text(q.choices[i], style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                      activeColor: AppColors.primaryColor,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: (_selectedChoice == null || _quizFeedback != null) ? null : _submitQuiz,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColor),
                          child: Text('Submit', style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _startNewQuestion,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryColor),
                        child: Text('Soal baru', style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_quizFeedback != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.white.withValues(alpha: 0.95),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _quizFeedback!,
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded', height: 1.35),
                ),
              ),
            ),
          ],
          if (_quizFeedback != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.white.withValues(alpha: 0.95),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  LevelyGamification.buildRecommendation(_progress),
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final LevelyProgress progress;
  final bool loading;

  const _ProgressHeader({required this.progress, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Card(
        color: Colors.white.withValues(alpha: 0.95),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Memuat progres Levely…', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
            ],
          ),
        ),
      );
    }

    final badgeTitles = LevelyGamification.badgeCatalog
        .where((b) => progress.badges.contains(b.id))
        .map((b) => b.title)
        .toList();

    return Card(
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _pill('Poin', '${progress.points}'),
                const SizedBox(width: 8),
                _pill('Streak', '${progress.dailyStreak} hari'),
                const SizedBox(width: 8),
                _pill('Akurasi', '${(progress.accuracy * 100).round()}%'),
              ],
            ),
            if (badgeTitles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in badgeTitles) _chip(t),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentColor),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final LevelyChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleColor = message.fromUser ? AppColors.primaryColor : Colors.white.withValues(alpha: 0.95);
        final textColor = message.fromUser ? Colors.white : Colors.black87;
        final radius = message.fromUser
            ? const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              );

        const reservedForAlignment = 36.0;
        const avatarDiameter = 28.0;
        const avatarGap = 8.0;

        final maxWidthUser = (constraints.maxWidth - reservedForAlignment).clamp(0.0, constraints.maxWidth);
        final maxWidthAssistant =
            (constraints.maxWidth - reservedForAlignment - avatarDiameter - avatarGap).clamp(0.0, constraints.maxWidth);

        if (message.fromUser) {
          return Padding(
            padding: const EdgeInsets.only(left: reservedForAlignment),
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidthUser),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'DIN_Next_Rounded',
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: reservedForAlignment),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: avatarDiameter / 2,
                backgroundColor: AppColors.primaryColor,
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: avatarGap),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidthAssistant),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                      border: Border.all(color: AppColors.accentColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'DIN_Next_Rounded',
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;

  const _Composer({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final canSend = controller.text.trim().isNotEmpty;
            return TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: "Tulis pertanyaanmu…",
                hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'DIN_Next_Rounded'),
                filled: true,
                fillColor: const Color(0xFFF3EDF7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    onPressed: canSend ? () => onSend() : null,
                    icon: const Icon(Icons.send_rounded),
                    color: AppColors.primaryColor,
                    disabledColor: AppColors.primaryColor.withValues(alpha: 0.35),
                    tooltip: "Kirim",
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContextChips extends StatelessWidget {
  final int? courseId;
  final int? level;
  final String? chapterName;

  const _ContextChips({
    required this.courseId,
    required this.level,
    required this.chapterName,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (courseId != null) {
      chips.add(_chip("Course $courseId"));
    }
    if (level != null) {
      chips.add(_chip("Level $level"));
    }
    if (chapterName != null && chapterName!.trim().isNotEmpty) {
      chips.add(_chip(chapterName!.trim()));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'DIN_Next_Rounded',
          color: AppColors.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
