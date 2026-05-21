import 'dart:async';
import 'dart:math' as math;
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
import 'package:app/service/api_cache_service.dart';
import 'home_screen.dart';
import 'package:app/utils/colors.dart';

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
  bool _isFinishing = false;
  Map<int, int> _gamificationPoints = {};
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

    if (widget.uc != null) {
      _courseEloBefore = widget.uc!.elo;
    }

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
      // Refresh user and user course data for the latest Elo synchronization
      final refreshedUser = await UserService.getUserById(user!.id);
      UserCourse? freshUc;
      if (widget.courseId != null) {
        try {
          freshUc = await UserCourseService.getUserCourse(user!.id, widget.courseId!);
        } catch (_) {}
      }

      final currentAttempt = await ChapterService.getCurrentAssessmentAttempt(
        status.chapterId,
        user!.id,
      );

      if (!mounted) return;

      setState(() {
        user = refreshedUser;
        // Baseline "Elo Berjalan" with the Global Elo for perfect synchronization.
        _courseEloBefore = refreshedUser.elo ?? 750;
      });

      if (currentAttempt == null) {
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

      // Prioritize refreshed Elo for fresh attempts, but trust attempt record for ongoing ones
      if (attempt.courseEloBefore != null) {
        if (attempt.progress.answeredCount == 0 && _courseEloBefore != null) {
          // Keep our refreshed _courseEloBefore from bootstrap
        } else {
          _courseEloBefore = attempt.courseEloBefore;
        }
      }

      if (attempt.courseEloAfter != null) {
        _courseEloAfter = attempt.courseEloAfter;
      }
      if (attempt.targetNextQuestionElo != null) {
        _targetNextQuestionElo = attempt.targetNextQuestionElo;
      }

      // Trust backend's question-specific delta if provided
      if (attempt.eloDeltaQuestion != null) {
        _eloDeltaQuestion = attempt.eloDeltaQuestion;
      } else if (_courseEloBefore != null && _courseEloAfter != null && attempt.progress.answeredCount > 0) {
        // Derive delta from the total change if missing (at least it won't be 0)
        _eloDeltaQuestion = (_courseEloAfter! - _courseEloBefore!).toDouble();
      } else {
        _eloDeltaQuestion = null;
      }

      if (attempt.pointsAwardedPreview != null) {
        _pointsAwardedPreview = attempt.pointsAwardedPreview;
      } else if (mergedQuestions.isNotEmpty) {
        // Find last answered question and its score for "Poin Soal"
        final lastAnswered = mergedQuestions.lastWhere(
          (q) => q.selectedAnswer.isNotEmpty,
          orElse: () => mergedQuestions.first,
        );
        if (lastAnswered.selectedAnswer.isNotEmpty) {
          _pointsAwardedPreview = lastAnswered.score.toDouble();
        }
      }
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

      if (completed) {
        setState(() {
          _isFinishing = true;
          _isSubmittingAnswer = false;
        });

        // Ensure the last question's answer is recorded in our local list before finalization
        _upsertServedQuestion(current);

        final result = response['result'] as Map<String, dynamic>? ?? {};
        // Reload fresh data from server FIRST to ensure _servedQuestions is correct
        await _reloadLatestAttemptForResult();
        
        // THEN apply result and show the view
        await _applyFinalResult(result);

        setState(() {
          _isFinishing = false;
        });
        return;
      }

      _upsertServedQuestion(current);
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

      HomeScreen.clearCaches();
      ApiCacheService.clearCacheContaining('/user');

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
        
        // Sync the local user model's Elo immediately for the UI
        if (_courseEloAfter != null) {
          user?.elo = _courseEloAfter!;
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
      // Use forceRefresh: true to bypass cache and ensure we get the fresh submitted attempt.
      // This prevents the UI from falling back to the 23-question bank shown in 1.png.
      final latestAttempt = await ChapterService.getLatestAssessmentAttempt(
          status.chapterId, user!.id, forceRefresh: true);
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

    final serverObjectiveTarget = safeInt(result['objectiveTarget']);
    final localObjectiveTotal = _servedQuestions
        .where((q) => q.servedOrder != null && q.type.toUpperCase() != 'EY')
        .length;

    setState(() {
      _grade = safeInt(result['grade']);
      _pointsEarned = safeInt(result['pointsEarned']);
      _eloDeltaFinal = result.containsKey('eloDelta')
          ? safeInt(result['eloDelta'])
          : _pointsEarned;
      _correctAnswer = safeInt(result['correctAnswers']);
      _aiFeedback = result['aiFeedback']?.toString();
      _newDifficultyLabel = result['newDifficulty']?.toString();
      // Use the local count if the server returns 0, but only if we have served questions
      _progress = AttemptProgress(
        poolSize: _progress.poolSize,
        objectiveTarget: serverObjectiveTarget > 0
            ? serverObjectiveTarget
            : (localObjectiveTotal > 0 ? localObjectiveTotal : 5),
        totalTarget: _progress.totalTarget,
        objectiveAnswered: _progress.objectiveAnswered,
        objectiveCorrect: _correctAnswer,
        servedCount: _progress.servedCount,
        answeredCount: _progress.answeredCount,
        completed: true,
      );
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
        
        // Sync Elo to UserCourse
        if (_courseEloAfter != null) {
          widget.uc!.elo = _courseEloAfter!;
        }
        
        UserCourseService.updateUserCourse(widget.uc!.id, widget.uc!);
      }

      // Explicitly clear caches to force Home and Profile screens to refresh data.
      // This solves the issue where Elo/stats don't update immediately.
      HomeScreen.clearCaches();
      ApiCacheService.clearCacheContaining('/user');
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
      servedOrder: source.servedOrder,
    );
    copy.selectedAnswer = source.selectedAnswer;
    copy.selectedMultiAnswer = List<String>.from(source.selectedMultAnswer);
    copy.isCorrect = source.isCorrect;
    copy.score = source.score;
    return copy;
  }

  Question _questionFromJson(Map<String, dynamic> map) {
    return Question.fromJson(map);
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
    if (_isLoadingAttempt || _isFinishing) {
      return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/assets/pictures/background-pattern.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: AppColors.primaryColor),
                SizedBox(height: 10),
                Text(
                  "Mohon Tunggu",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DIN_Next_Rounded',
                      color: AppColors.primaryColor),
                ),
              ],
            ),
          ));
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
                    icon: const Icon(Icons.send,
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

  Widget _buildStatsBar() {
    final currentElo = _courseEloAfter ?? _courseEloBefore;
    if (currentElo == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            label: 'Elo Berjalan',
            value: '$currentElo',
            icon: Icons.emoji_events,
            color: AppColors.primaryColor,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            label: 'Poin Soal',
            subLabel: 'Terakhir',
            value: '+${(_pointsAwardedPreview ?? 0).toInt()}',
            icon: Icons.monetization_on,
            color: Colors.orange,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            label: 'Delta Soal',
            subLabel: 'Terakhir',
            value:
                '${(_eloDeltaQuestion ?? 0) >= 0 ? '+' : ''}${(_eloDeltaQuestion ?? 0).toStringAsFixed(1)}',
            icon: (_eloDeltaQuestion ?? 0) >= 0
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: (_eloDeltaQuestion ?? 0) >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    String? subLabel,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subLabel != null)
                      Text(
                        subLabel,
                        style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontSize: 8,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'DIN_Next_Rounded',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
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
                    _buildStatsBar(),
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

  void _calculateGamificationPoints() {
    _gamificationPoints.clear();
    final questions = _servedQuestions;
    if (questions.isEmpty) return;

    final nonEssayQuestions =
        questions.where((q) => q.type.toUpperCase() != 'EY').toList();
    int totalEarned = _pointsEarned;
    double totalWeight = 0;
    List<double> weights = List.filled(questions.length, 0.0);

    int currentUserElo = user?.elo ?? 800;
    if (currentUserElo < 800) currentUserElo = 800;

    for (int i = 0; i < questions.length; i++) {
      final current = questions[i];
      if (current.type.toUpperCase() == 'EY') continue;

      if (current.isCorrect) {
        int qElo = current.elo;
        double expectedProb =
            1 / (1 + math.pow(10, -(currentUserElo - qElo) / 400));
        double w = 1 - expectedProb;
        weights[i] = w;
        totalWeight += w;
      }
    }

    int distributedPoints = 0;
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].isCorrect && totalWeight > 0) {
        int pts = ((totalEarned * weights[i]) / totalWeight).round();
        _gamificationPoints[i] = pts;
        distributedPoints += pts;
      } else {
        _gamificationPoints[i] = 0;
      }
    }

    if (totalWeight > 0 && distributedPoints != totalEarned) {
      int diff = totalEarned - distributedPoints;
      for (int i = 0; i < questions.length; i++) {
        if (questions[i].isCorrect) {
          _gamificationPoints[i] = (_gamificationPoints[i] ?? 0) + diff;
          break;
        }
      }
    }
  }

  Widget _buildDetailedQuestions() {
    final visibleQuestions = _servedQuestions
        .where((q) => q.servedOrder != null)
        .toList()
      ..sort((a, b) => (a.servedOrder ?? 0).compareTo(b.servedOrder ?? 0));

    return Column(
      children: visibleQuestions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        final pts = _gamificationPoints[i] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Soal ${i + 1}: ${q.question}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (q.type.toUpperCase() != 'EY')
                      Icon(
                        q.isCorrect ? Icons.check_circle : Icons.cancel,
                        color: q.isCorrect ? Colors.green : Colors.red,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Jawaban Anda: ${q.selectedAnswer}',
                    style: TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        color: q.type.toUpperCase() == 'EY'
                            ? Colors.black
                            : (q.isCorrect ? Colors.green : Colors.red))),
                if (q.type.toUpperCase() != 'EY' && !q.isCorrect)
                  Text('Jawaban Benar: ${q.correctedAnswer}',
                      style: const TextStyle(
                          fontFamily: 'DIN_Next_Rounded', color: Colors.green)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Elo Soal: ${q.elo}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    if (pts > 0)
                      Text('+$pts Poin',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultView() {
    _calculateGamificationPoints();
    final visibleQuestions =
        _servedQuestions.where((q) => q.servedOrder != null).toList();
    final objectiveTotal =
        visibleQuestions.where((q) => q.type.toUpperCase() != 'EY').length;

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
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Detail Pengerjaan',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontFamily: 'DIN_Next_Rounded'),
                  ),
                ),
              ),
              _buildDetailedQuestions(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup',
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'DIN_Next_Rounded')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
