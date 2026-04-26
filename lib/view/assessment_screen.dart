import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import 'package:app/model/assessment.dart';
import 'package:app/model/assessment_attempt.dart';
import 'package:app/model/chapter_status.dart';
import 'package:app/model/user.dart';
import 'package:app/model/user_course.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/user_chapter_service.dart';
import 'package:app/service/user_course_service.dart';
import 'package:app/service/user_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/questionnaire_screen.dart';

class AssessmentScreen extends StatefulWidget {
  final ChapterStatus status;
  final Student user;
  final int? courseId;
  final int? level;
  final String? chapterName;
  final UserCourse? uc;
  final int? chLength;
  final Function(bool) updateMaterialLocked;
  final Function(ChapterStatus) updateStatus;
  final Function(bool) updateAssessmentStarted;
  final Function(bool) updateAssessmentFinished;

  const AssessmentScreen({
    super.key,
    required this.status,
    required this.user,
    this.courseId,
    this.level,
    this.chapterName,
    this.uc,
    this.chLength,
    required this.updateMaterialLocked,
    required this.updateStatus,
    required this.updateAssessmentStarted,
    required this.updateAssessmentFinished,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  bool _isLoadingAttempt = false;
  bool _isStartingAttempt = false;
  bool _isSubmittingAnswer = false;
  bool _assessmentStarted = false;
  bool _assessmentFinished = false;
  bool _forceNewOnNextStart = false;

  int? _attemptId;
  Student? user;
  late ChapterStatus status;
  Question? _currentQuestion;
  List<Question> _servedQuestions = [];
  AttemptProgress _progress = const AttemptProgress(
    poolSize: 12,
    objectiveTarget: 5,
    totalTarget: 6,
    objectiveAnswered: 0,
    objectiveCorrect: 0,
    servedCount: 0,
    answeredCount: 0,
    completed: false,
  );

  int _grade = 0;
  int _pointsEarned = 0;
  int _eloDeltaFinal = 0;
  int _correctAnswer = 0;
  String? _aiFeedback;
  String? _newDifficultyLabel;
  int? _courseEloBefore;
  int? _courseEloAfter;
  int? _targetNextQuestionElo;
  double? _eloDeltaQuestion;
  double? _pointsAwardedPreview;

  final TextEditingController _essayController = TextEditingController();
  String _selectedChoice = '';

  @override
  void initState() {
    super.initState();
    status = widget.status;
    user = widget.user;
    _grade = status.assessmentGrade;
    _pointsEarned = status.assessmentPointsEarned;
    _eloDeltaFinal = status.assessmentEloDelta;
    _bootstrapCurrentAttempt();
  }

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapCurrentAttempt() async {
    if (user == null) return;

    setState(() {
      _isLoadingAttempt = true;
    });

    try {
      final currentAttempt = await ChapterService.getCurrentAssessmentAttempt(
        status.chapterId,
        user!.id,
      );
      if (!mounted || currentAttempt == null) {
        return;
      }
      _applyAttempt(currentAttempt, lockMaterial: true);
    } catch (_error) {
      // Keep initial state when no active attempt.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAttempt = false;
        });
      }
    }
  }

  void _applyAttempt(AssessmentAttempt attempt, {required bool lockMaterial}) {
    final question = attempt.currentQuestion ??
        (attempt.questions.isNotEmpty
            ? _copyQuestion(attempt.questions.last)
            : null);

    final mergedQuestions = <Question>[];
    for (final q in attempt.questions) {
      mergedQuestions.add(_copyQuestion(q));
    }
    if (question != null && !mergedQuestions.any((q) => q.id == question.id)) {
      mergedQuestions.add(_copyQuestion(question));
    }

    setState(() {
      _attemptId = attempt.attemptId;
      _currentQuestion = question != null ? _copyQuestion(question) : null;
      _servedQuestions = mergedQuestions;
      _progress = attempt.progress;
      _assessmentStarted = true;
      _assessmentFinished = false;
      _selectedChoice = _currentQuestion?.selectedAnswer ?? '';
      _essayController.text = _currentQuestion?.selectedAnswer ?? '';
      _courseEloBefore = attempt.courseEloBefore;
      _courseEloAfter = attempt.courseEloAfter;
      _targetNextQuestionElo = attempt.targetNextQuestionElo;
      _eloDeltaQuestion = attempt.eloDeltaQuestion;
      _pointsAwardedPreview = attempt.pointsAwardedPreview;
    });

    widget.updateAssessmentStarted(true);
    widget.updateAssessmentFinished(false);
    widget.updateMaterialLocked(lockMaterial);
  }

  Future<void> _startAssessmentAttempt() async {
    if (_isStartingAttempt || user == null) return;

    setState(() {
      _isStartingAttempt = true;
    });

    try {
      await ChapterService.waitForAssessmentWarmup(status.chapterId, user!.id);

      final currentAttempt = await ChapterService.getCurrentAssessmentAttempt(
        status.chapterId,
        user!.id,
      );
      if (!mounted) return;
      if (currentAttempt != null) {
        _forceNewOnNextStart = false;
        _applyAttempt(currentAttempt, lockMaterial: true);
        return;
      }

      final startedAttempt = await ChapterService.startAssessmentAttempt(
        status.chapterId,
        user!.id,
        forceNew: _forceNewOnNextStart,
      );
      if (!mounted) return;

      _forceNewOnNextStart = false;
      _applyAttempt(startedAttempt, lockMaterial: true);
      if (startedAttempt.source == 'FALLBACK_BANK') {
        _showInfo(
            'LLM belum berhasil generate soal, sistem memakai bank soal cadangan.');
      }
    } catch (error) {
      _showError('Gagal memulai assessment', error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isStartingAttempt = false;
        });
      }
    }
  }

  Future<void> _submitCurrentQuestion() async {
    if (_isSubmittingAnswer ||
        _attemptId == null ||
        user == null ||
        _currentQuestion == null) {
      return;
    }

    final current = _currentQuestion!;
    if (current.id == null) {
      _showInfo('Soal aktif tidak valid. Coba muat ulang assessment.');
      return;
    }
    final normalizedType = current.type.toUpperCase();
    final answer = normalizedType == 'EY'
        ? _essayController.text.trim()
        : _selectedChoice.trim();

    if (answer.isEmpty) {
      _showInfo('Jawaban tidak boleh kosong.');
      return;
    }

    setState(() {
      _isSubmittingAnswer = true;
    });

    try {
      final response = await ChapterService.answerAssessmentQuestion(
        chapterId: status.chapterId,
        userId: user!.id,
        attemptId: _attemptId!,
        questionId: current.id!,
        answer: answer,
      );

      if (!mounted) return;

      final completed = response['completed'] == true;
      current.selectedAnswer = answer;
      _upsertServedQuestion(current);
      if (completed) {
        final result = response['result'] as Map<String, dynamic>? ?? {};
        await _applyFinalResult(result);
        await _reloadLatestAttemptForResult();
        return;
      }

      final isCorrect = response['isCorrect'] == true;
      current.isCorrect = isCorrect;
      current.score = isCorrect
          ? (100 /
                  (_progress.objectiveTarget == 0
                      ? 1
                      : _progress.objectiveTarget))
              .ceil()
          : 0;
      _upsertServedQuestion(current);

      final progressMap = response['progress'];
      if (progressMap is Map<String, dynamic>) {
        _progress = AttemptProgress.fromJson(progressMap);
      }

      final nextMap = response['nextQuestion'];
      if (nextMap is! Map<String, dynamic>) {
        throw Exception('Next question tidak valid');
      }
      final nextQuestion = _questionFromJson(nextMap);
      _upsertServedQuestion(nextQuestion);

      setState(() {
        _currentQuestion = nextQuestion;
        _selectedChoice = nextQuestion.selectedAnswer;
        _essayController.text = nextQuestion.selectedAnswer;
        if (response['courseEloBefore'] != null) {
          _courseEloBefore = (response['courseEloBefore'] as num).toInt();
        }
        if (response['courseEloAfter'] != null) {
          _courseEloAfter = (response['courseEloAfter'] as num).toInt();
        }
        if (response['targetNextQuestionElo'] != null) {
          _targetNextQuestionElo =
              (response['targetNextQuestionElo'] as num).toInt();
        }
        if (response['eloDeltaQuestion'] != null) {
          _eloDeltaQuestion = (response['eloDeltaQuestion'] as num).toDouble();
        }
        if (response['pointsAwardedPreview'] != null) {
          _pointsAwardedPreview =
              (response['pointsAwardedPreview'] as num).toDouble();
        }
      });

      if (normalizedType != 'EY') {
        _showInfo(isCorrect
            ? 'Benar. Soal berikutnya akan menyesuaikan Elo kamu.'
            : 'Salah. Soal berikutnya akan menyesuaikan Elo kamu.');
      }
    } catch (error) {
      _showError('Gagal submit jawaban', error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingAnswer = false;
        });
      }
    }
  }

  Future<void> _reloadLatestAttemptForResult() async {
    if (user == null) return;
    try {
      final latestAttempt = await ChapterService.getLatestAssessmentAttempt(
          status.chapterId, user!.id);
      if (!mounted || latestAttempt == null) return;
      setState(() {
        _servedQuestions = latestAttempt.questions.map(_copyQuestion).toList();
      });
    } catch (_error) {
      // Best effort only.
    }
  }

  Future<void> _applyFinalResult(Map<String, dynamic> result) async {
    int safeInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    setState(() {
      _grade = safeInt(result['grade']);
      _pointsEarned = safeInt(result['pointsEarned']);
      _eloDeltaFinal = result.containsKey('eloDelta')
          ? safeInt(result['eloDelta'])
          : _pointsEarned;
      _correctAnswer = safeInt(result['correctAnswers']);
      _aiFeedback = result['aiFeedback']?.toString();
      _newDifficultyLabel = result['newDifficulty']?.toString();
      if (result['courseEloStart'] is num) {
        _courseEloBefore = (result['courseEloStart'] as num).toInt();
      }
      if (result['courseEloEnd'] is num) {
        _courseEloAfter = (result['courseEloEnd'] as num).toInt();
      }
      _assessmentFinished = true;
      _assessmentStarted = false;
      _attemptId = null;
      status.assessmentDone = true;
      status.assessmentGrade = _grade;
      status.assessmentEloDelta = _eloDeltaFinal;
      status.assessmentPointsEarned = _pointsEarned;
      status.assessmentAnswer =
          _servedQuestions.map((q) => q.selectedAnswer).toList();

      if (widget.uc != null && widget.level != null && widget.chLength != null) {
        final totalChapter = widget.chLength!;
        if (widget.level == widget.uc!.currentChapter) {
          widget.uc!.currentChapter++;
        }

        final normalizedCurrentChapter =
            widget.uc!.currentChapter.clamp(1, totalChapter + 1);
        final completedChapter = (normalizedCurrentChapter - 1).clamp(0, totalChapter);
        final normalizedProgress = ((completedChapter / totalChapter) * 100).toInt();

        widget.uc!.currentChapter = normalizedCurrentChapter;
        widget.uc!.progress = normalizedProgress;
        UserCourseService.updateUserCourse(widget.uc!.id, widget.uc!);
      }
    });

    widget.updateAssessmentFinished(true);
    widget.updateAssessmentStarted(false);
    widget.updateMaterialLocked(false);
    widget.updateStatus(status);
    await _persistStatus();
    await _refreshUserSnapshot();
  }

  Future<void> _persistStatus() async {
    try {
      status = await UserChapterService.updateChapterStatus(status.id, status);
    } catch (_error) {
      // Keep local optimistic state.
    }
  }

  Future<void> _refreshUserSnapshot() async {
    if (user == null) return;
    try {
      final refreshed = await UserService.getUserById(user!.id);
      if (!mounted) return;
      setState(() {
        user?.points = refreshed.points;
        user?.elo = refreshed.elo;
        user?.eloTitle = refreshed.eloTitle;
      });
    } catch (_error) {
      // Keep local data if refresh fails.
    }
  }

  Question _copyQuestion(Question source) {
    final copy = Question(
      id: source.id,
      question: source.question,
      option: List<String>.from(source.option),
      correctedAnswer: source.correctedAnswer,
      type: source.type,
      elo: source.elo,
    );
    copy.selectedAnswer = source.selectedAnswer;
    copy.selectedMultiAnswer = List<String>.from(source.selectedMultAnswer);
    copy.isCorrect = source.isCorrect;
    copy.score = source.score;
    return copy;
  }

  Question _questionFromJson(Map<String, dynamic> map) {
    final optionsRaw = map['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final q = Question(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      question: (map['question'] ?? '').toString(),
      option: options,
      correctedAnswer:
          (map['correctedAnswer'] ?? map['answer'] ?? '').toString(),
      type: (map['type'] ?? 'MC').toString(),
      elo: map['elo'] is int
          ? map['elo'] as int
          : int.tryParse('${map['elo']}') ?? 1200,
    );
    final submitted = (map['submittedAnswer'] ?? '').toString();
    if (submitted.isNotEmpty) {
      q.selectedAnswer = submitted;
    }
    q.isCorrect = map['isCorrect'] == true;
    q.score = map['score'] is int
        ? map['score'] as int
        : int.tryParse('${map['score']}') ?? 0;
    return q;
  }

  void _upsertServedQuestion(Question question) {
    final idx = _servedQuestions.indexWhere((q) => q.id == question.id);
    if (idx >= 0) {
      _servedQuestions[idx] = _copyQuestion(question);
    } else {
      _servedQuestions.add(_copyQuestion(question));
    }
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message,
              style: const TextStyle(fontFamily: 'DIN_Next_Rounded'))),
    );
  }

  void _showError(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message,
            style: const TextStyle(fontFamily: 'DIN_Next_Rounded')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAttempt) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assessmentFinished || status.assessmentDone) {
      return _buildResultView();
    }

    if (!_assessmentStarted) {
      return _buildStartView();
    }

    return _buildQuestionView();
  }

  Widget _buildStartView() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/pictures/background-pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.chapterName ?? 'Assessment',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded',
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Assessment adaptif 1v1 Elo, 6 soal (5 objektif + 1 essay).',
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor),
                    onPressed:
                        _isStartingAttempt ? null : _startAssessmentAttempt,
                    icon: const Icon(LineAwesomeIcons.paper_plane,
                        color: Colors.white),
                    label: const Text('Mulai',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'DIN_Next_Rounded')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    final current = _currentQuestion;
    if (current == null) {
      return const Center(child: Text('Tidak ada soal aktif.'));
    }

    final type = current.type.toUpperCase();
    final progressValue = (_progress.totalTarget <= 0)
        ? 0.0
        : (_progress.answeredCount / _progress.totalTarget).clamp(0.0, 1.0);

    final mcCount =
        _servedQuestions.where((q) => q.type.toUpperCase() == 'MC').length;
    final tfCount =
        _servedQuestions.where((q) => q.type.toUpperCase() == 'TF').length;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/pictures/background-pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Terjawab ${_progress.answeredCount}/${_progress.totalTarget}',
                          style: const TextStyle(
                              fontFamily: 'DIN_Next_Rounded',
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Kuota MC: $mcCount/4 | TF: $tfCount/1',
                          style: const TextStyle(
                              fontFamily: 'DIN_Next_Rounded', fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_courseEloBefore != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Elo Berjalan',
                                    style: const TextStyle(
                                        fontFamily: 'DIN_Next_Rounded',
                                        fontSize: 12,
                                        color: Colors.grey)),
                                Text('${_courseEloAfter ?? _courseEloBefore}',
                                    style: const TextStyle(
                                        fontFamily: 'DIN_Next_Rounded',
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryColor)),
                              ],
                            ),
                            if (_pointsAwardedPreview != null && _pointsAwardedPreview! > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Poin Diraih',
                                      style: const TextStyle(
                                          fontFamily: 'DIN_Next_Rounded',
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  Text(
                                    '+${_pointsAwardedPreview?.toInt()}',
                                    style: const TextStyle(
                                      fontFamily: 'DIN_Next_Rounded',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            if (_eloDeltaQuestion != null &&
                                _eloDeltaQuestion != 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Delta Soal',
                                      style: const TextStyle(
                                          fontFamily: 'DIN_Next_Rounded',
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  Text(
                                    '${_eloDeltaQuestion! > 0 ? '+' : ''}${_eloDeltaQuestion!.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontFamily: 'DIN_Next_Rounded',
                                      fontWeight: FontWeight.bold,
                                      color: _eloDeltaQuestion! > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    if (_targetNextQuestionElo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Target Elo Soal Saat Ini: $_targetNextQuestionElo',
                            style: const TextStyle(
                                fontFamily: 'DIN_Next_Rounded',
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(current.question,
                                style: const TextStyle(
                                    fontFamily: 'DIN_Next_Rounded')),
                            const SizedBox(height: 12),
                            if (type == 'MC' || type == 'TF') ...[
                              ...current.option
                                  .map((opt) => RadioListTile<String>(
                                        title: Text(opt,
                                            style: const TextStyle(
                                                fontFamily:
                                                    'DIN_Next_Rounded')),
                                        value: opt,
                                        groupValue: _selectedChoice,
                                        onChanged: _isSubmittingAnswer
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _selectedChoice = value ?? '';
                                                });
                                              },
                                      )),
                            ] else ...[
                              TextField(
                                controller: _essayController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Ketik jawaban essay...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor),
                onPressed: _isSubmittingAnswer ? null : _submitCurrentQuestion,
                child: Text(
                  _isSubmittingAnswer ? 'Mengirim...' : 'Kirim Jawaban',
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'DIN_Next_Rounded'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final objectiveTotal =
        _servedQuestions.where((q) => q.type.toUpperCase() != 'EY').length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/pictures/background-pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: AppColors.primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hasil Assessment',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded')),
                    const SizedBox(height: 8),
                    Text('Jumlah Benar: $_correctAnswer / $objectiveTotal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'DIN_Next_Rounded')),
                    Text('Skor: $_grade / 100',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'DIN_Next_Rounded')),
                    const Divider(color: Colors.white54, height: 24),
                    Text(
                        'Elo Delta (Perubahan Elo Course): ${_eloDeltaFinal > 0 ? '+' : ''}$_eloDeltaFinal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded')),
                    Text(
                        'Points Earned (Gamifikasi): ${_pointsEarned > 0 ? '+' : ''}$_pointsEarned',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded')),
                  ],
                ),
              ),
            ),
            if (_newDifficultyLabel != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_up,
                      color: AppColors.primaryColor),
                  title: Text(
                      'Tingkat kesulitan berikutnya: $_newDifficultyLabel',
                      style: const TextStyle(fontFamily: 'DIN_Next_Rounded')),
                ),
              ),
            if (_aiFeedback != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_aiFeedback!,
                      style: const TextStyle(fontFamily: 'DIN_Next_Rounded')),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
