import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:app/model/assessment.dart';
import 'package:app/model/chapter_status.dart';
import 'package:app/model/user.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/utils/colors.dart';

class AlreadyFinishedAssessmentAssessmentScreen extends StatefulWidget {
  final ChapterStatus status;
  final Student user;
  final Function(ChapterStatus)? updateStatus;
  final int? level;
  const AlreadyFinishedAssessmentAssessmentScreen({
    super.key,
    required this.status,
    required this.user,
    this.updateStatus,
    this.level,
  });

  @override
  State<AlreadyFinishedAssessmentAssessmentScreen> createState() => _AlreadyFinishedAssessmentAssessmentScreenState();
}

class _AlreadyFinishedAssessmentAssessmentScreenState extends State<AlreadyFinishedAssessmentAssessmentScreen> {
  bool tapped = false;
  bool assessmentDone = false;
  bool allQuestionsAnswered = false;
  int correctAnswer = 0;
  int point = 0;
  Student? user;
  late ChapterStatus status;
  Assessment? question;
  Future<bool>? _resultFuture;
  Map<int, int> _gamificationPoints = {};

  @override
  void initState() {
    getAssessment(widget.status.chapterId);
    allQuestionsAnswered = widget.status.assessmentDone;
    assessmentDone = widget.status.assessmentDone;
    status = widget.status;
    user = widget.user;
    super.initState();
  }

  void getAssessment(int id) async {
    try {
      final latestAttempt = await ChapterService.getLatestAssessmentAttempt(id, widget.user.id);
      if (latestAttempt != null) {
        setState(() {
          question = latestAttempt.toAssessment();
          _resultFuture = _calculateResults();
        });
        return;
      }
    } catch (_error) {
      // fallback to legacy endpoint below
    }

    final resultAssessment = await ChapterService.getAssessmentByChapterId(id);
    setState(() {
      question = resultAssessment;
      _resultFuture = _calculateResults();
    });
  }

  Future<int> getScore() async {
    int score = 0;
    double rangeScore = 100 / question!.questions.length;
    int tempCorrectAnswer = 0;

    for (int index = 0; index < question!.questions.length; index++) {
      Question i = question!.questions[index];

      if (i.type == 'PG' || i.type == 'TF' || i.type == 'MC') {
        if (i.isCorrect) {
          question!.questions[index].score = rangeScore.ceil();
          score += rangeScore.ceil();
          tempCorrectAnswer++;
        }
      } else if (i.type == 'EY') {
        int fullscore = rangeScore.ceil();
        try {
          double similarity = double.parse((await checkEssay(i.correctedAnswer, i.selectedAnswer)).toStringAsFixed(1));
          if (similarity > 0) {
            question!.questions[index].score = rangeScore.ceil();
            score += (fullscore * similarity).ceil();
            question!.questions[index].isCorrect = true;
            tempCorrectAnswer++;
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error processing essay at index $index: $e");
          }
        }
      }
    }

    setState(() {
      correctAnswer = tempCorrectAnswer;
    });

    return score;
  }


  Future<double> checkEssay(String reference, String answer) async{
    double similiarity = await ChapterService.checkSimiliarity(reference, answer);
    return similiarity;
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (question != null) {
      child = _buildQuizResultFuture();
    } else {
      child = _emptyState();
    }
    return child;
  }

  Widget _buildQuizResultFuture() {
    final resultFuture = _resultFuture;
    if (resultFuture == null) {
      return _loadingState();
    }
    return FutureBuilder<bool>(
      future: resultFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingState();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return _buildQuizResult();
        }
      },
    );
  }

  Future<bool> _calculateResults() async {
    tapped = true;
    correctAnswer = 0;
    final questions = question?.questions ?? [];
    if (questions.isEmpty) {
      point = status.assessmentGrade;
      return true;
    }
    
    final nonEssayQuestions = questions.where((q) => q.type != 'EY').toList();
    final totalAssessable = nonEssayQuestions.isEmpty ? 1 : nonEssayQuestions.length;
    final rangeScore = (100 / totalAssessable).ceil();

    final hasPreloadedAnswers = questions.any((q) => q.selectedAnswer.trim().isNotEmpty);
    if (!hasPreloadedAnswers && status.assessmentAnswer.isNotEmpty) {
      final total = status.assessmentAnswer.length < questions.length
          ? status.assessmentAnswer.length
          : questions.length;
      for (int i = 0; i < total; i++) {
        questions[i].selectedAnswer = status.assessmentAnswer[i];
      }
    }

    int totalEarned = status.assessmentPointsEarned;
    double totalWeight = 0;
    List<double> weights = List.filled(questions.length, 0.0);
    
    int currentUserElo = widget.user.elo ?? 800;
    if (currentUserElo < 800) currentUserElo = 800;

    for (int i = 0; i < questions.length; i++) {
      final current = questions[i];
      if (current.type == 'EY') {
        current.isCorrect = false;
        current.score = 0;
        continue;
      }

      final normalizedSelected = current.selectedAnswer.trim().toLowerCase();
      final normalizedCorrect = current.correctedAnswer.trim().toLowerCase();
      final isCorrect = current.isCorrect ||
          (normalizedSelected.isNotEmpty && normalizedSelected == normalizedCorrect);

      current.isCorrect = isCorrect;
      if (isCorrect) {
        if (current.score <= 0) {
          current.score = rangeScore;
        }
        correctAnswer++;
        
        int qElo = current.elo ?? 800;
        double expectedProb = 1 / (1 + math.pow(10, -(currentUserElo - qElo) / 400));
        double w = 1 - expectedProb;
        weights[i] = w;
        totalWeight += w;
      } else {
        current.score = 0;
      }
    }
    
    int distributedPoints = 0;
    _gamificationPoints.clear();
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

    point = nonEssayQuestions.fold<int>(0, (sum, q) => sum + q.score);

    if (nonEssayQuestions.isEmpty) {
      point = status.assessmentGrade;
    }
    return true;
  }

  Widget _loadingState() {
    return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text(
                "Mohon Tunggu",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded'),
              ),
            ],
          ),
        )
    );
  }

  Widget _buildQuizResult() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              'lib/assets/pictures/background-pattern.png'
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: AppColors.primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hasil Assessment', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'DIN_Next_Rounded')),
                          SizedBox(height: 4),
                          Table(
                            columnWidths: {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(2),
                            },
                            children: [
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text('Jumlah Benar', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(': $correctAnswer / ${question!.questions.where((q) => q.type != 'EY').length}', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white),),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text('Skor', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(': $point / 100', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text('Pertambahan Elo', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(': ${status.assessmentEloDelta > 0 ? "+" : ""}${status.assessmentEloDelta}', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text('Poin Didapat', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(': ${status.assessmentPointsEarned > 0 ? "+" : ""}${status.assessmentPointsEarned}', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.amber.shade200)),
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Column(
                children: List.generate(
                  question!.questions.length,
                      (count) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildQuestion(count),
                  ),
                ),
              ),
            ],
          )
      ),
    );
  }

  Widget _buildQuestion(int number) {
    switch (question?.questions[number].type) {
      case 'PG':
      case 'TF':
      case 'MC':
        return Card.outlined(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Text('${number + 1}', style: TextStyle(fontSize: 20, fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor)),
              isThreeLine: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        allQuestionsAnswered && tapped ? Text("Skor : ${question?.questions[number].score} / ${(100 / (question!.questions.where((q) => q.type != 'EY').isNotEmpty ? question!.questions.where((q) => q.type != 'EY').length : 1)).ceil()}", style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)) : SizedBox(),
                        Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade400)
                        ),
                        child: Text(
                          '${question?.questions[number].elo} ELO',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', fontSize: 12)
                        ),
                      ),
                      SizedBox(height: 4),
                      Builder(builder: (_) {
                        final pts = _gamificationPoints[number] ?? 0;
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pts > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: pts > 0 ? Colors.green.shade400 : Colors.grey.shade300)
                          ),
                          child: Text(
                            pts > 0 ? '+$pts Poin' : '0 Poin',
                            style: TextStyle(
                              color: pts > 0 ? Colors.green.shade800 : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DIN_Next_Rounded',
                              fontSize: 12
                            )
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              subtitle: question?.questions[number].option.isNotEmpty ?? false
                  ? _buildChoiceAnswer(question!.questions[number], number)
                  : null,
            ),
          ),
        );
      case 'EY':
        return Card.outlined(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Text('${number + 1}', style: TextStyle(fontSize: 20, fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor)),
              isThreeLine: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        allQuestionsAnswered && tapped ? Text("Skor : Menunggu Review", style: TextStyle(color: Colors.orange, fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)) : SizedBox(),
                        Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade400)
                        ),
                        child: Text(
                          '${question?.questions[number].elo} ELO',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', fontSize: 12)
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade300)
                        ),
                        child: Text(
                          'Essay',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded',
                            fontSize: 12
                          )
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              subtitle: _buildTextAnswer(question!.questions[number]),
            ),
          ),
        );
      default:
        return const SizedBox(
          width: double.infinity,
          height: 100,
          child: Center(
            child: Text('There is no Question yet', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
          ),
        );
    }
  }

  Widget _buildChoiceAnswer(Question question, int number) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: question.option.map((answer) {
        final bool isSelected = question.selectedAnswer == answer;
        final bool isCorrectAnswer = answer == question.correctedAnswer;
        final bool isIncorrectSelected = isSelected && !question.isCorrect;

        Color borderColor;
        Color backgroundColor;

        if (tapped) {
          if (isIncorrectSelected) {
            borderColor = Colors.red;
            backgroundColor = Colors.red.shade50;
          } else if (isCorrectAnswer) {
            borderColor = AppColors.secondaryColor;
            backgroundColor = Colors.green.shade50;
          } else {
            borderColor = Colors.grey.shade300;
            backgroundColor = Colors.white;
          }
        } else {
          borderColor = isSelected ? AppColors.primaryColor : Colors.grey.shade300;
          backgroundColor = isSelected ? Colors.deepPurple.shade50 : Colors.white;
        }

        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.2),
                blurRadius: 6,
                spreadRadius: 1,
                offset: Offset(0, 2),
              )
            ]
                : [],
          ),
          child: RadioListTile<String>(
            title: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'DIN_Next_Rounded',
                color: isSelected ? AppColors.primaryColor : Colors.black87,
              ),
            ),
            value: answer,
            groupValue: question.selectedAnswer,
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: tapped
                ? null
                : (String? value) {
              if (value != null) {
                setState(() {
                  question.selectedAnswer = value;
                  question.isCorrect = value == question.correctedAnswer;
                });
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextAnswer(Question question) {
    TextEditingController controller = TextEditingController(text: question.selectedAnswer);
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Jawaban:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'DIN_Next_Rounded',
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              readOnly: allQuestionsAnswered && tapped ? true : false,
              style: TextStyle(
                fontFamily: 'DIN_Next_Rounded',
              ),
              decoration: InputDecoration(
                hintText: "Ketikkan jawaban anda...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.deepPurple.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
              enabled: !tapped,

              onChanged: (String answer) {
                setState(() {
                  question.selectedAnswer = answer;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('lib/assets/empty.png', width: 120, height: 120),
          SizedBox(height: 20),
          Text(
            'No questions available yet.',
            style: TextStyle(fontSize: 16, fontFamily: 'DIN_Next_Rounded'),
          ),
        ],
      ),
    );
  }
}
