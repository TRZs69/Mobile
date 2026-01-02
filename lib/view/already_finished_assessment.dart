import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/assessment.dart';
import '../model/chapter_status.dart';
import '../model/user.dart';
import '../service/chapter_service.dart';
import '../service/user_chapter_service.dart';
import '../service/user_service.dart';
import '../utils/colors.dart';

class AlreadyFinishedAssessmentAssessmentScreen extends StatefulWidget {
  final ChapterStatus status;
  final Student user;
  const AlreadyFinishedAssessmentAssessmentScreen({
    super.key,
    required this.status,
    required this.user,
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
    final resultAssessment = await ChapterService.getAssessmentByChapterId(id);
    setState(() {
      question = resultAssessment;
      _resultFuture = _calculateResults();
    });
  }

  Future<int> getScore() async {
    int score = 0;
    double rangeScore = 100 / question!.questions.length;
    int tempCorrectAnswer = 0; // Temporary counter for correctAnswer

    for (int index = 0; index < question!.questions.length; index++) {
      Question i = question!.questions[index]; // Ambil elemen berdasarkan index

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

    // Update state once after all calculations
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
    if (question != null) {
      return _buildQuizResultFuture();
    } else {
      return _emptyState();
    }
  }

  Widget _buildQuizResultFuture() {
    final resultFuture = _resultFuture;
    if (resultFuture == null) {
      return _loadingState();
    }
    return FutureBuilder<bool>(
      future: resultFuture, // Move result calculation to async function
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingState(); // Show loading indicator while waiting
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
    correctAnswer = 0; // Reset the counter before starting the calculation
    final questions = question?.questions ?? [];
    if (questions.isEmpty) {
      point = status.assessmentGrade;
      return true;
    }
    double rangeScore = 100 / questions.length;
    final answerCount = status.assessmentAnswer.length;
    final total = answerCount < questions.length ? answerCount : questions.length;

    for (int i = 0; i < total; i++) {
      questions[i].selectedAnswer = status.assessmentAnswer[i];

      if (questions[i].type != 'EY') {
        questions[i].isCorrect =
            questions[i].selectedAnswer == questions[i].correctedAnswer;
        if (questions[i].isCorrect == true) {
          questions[i].score = rangeScore.ceil();
          correctAnswer++;
          print(correctAnswer);
        }
      } else {
        double similarity = 0;
        try {
          final result = await checkEssay(
            questions[i].correctedAnswer,
            questions[i].selectedAnswer,
          ).timeout(const Duration(seconds: 8), onTimeout: () => 0.0);
          similarity = double.parse(result.toStringAsFixed(1));
          print(similarity);
        } catch (e) {
          if (kDebugMode) {
            print("Error processing essay at index $i: $e");
          }
        }
        questions[i].isCorrect = similarity > 0;
        if (questions[i].isCorrect == true) {
          questions[i].score = (rangeScore * similarity).ceil();
          correctAnswer++;
          print(correctAnswer);
        }
      }
    }

    point = status.assessmentGrade;
    return true; // Ensure the future completes successfully
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
                                    child: Text(': $correctAnswer / ${question!.questions.length}', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white),),
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
                                    child: Text(': $point / ${((question!.questions.length/question!.questions.length)*100).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text('Poin', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(': +$point', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
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
              title: Column(
                children: [
                  allQuestionsAnswered && tapped ? Text("Skor : ${question?.questions[number].score} / ${(100 / (question!.questions.length)).ceil()}", style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)) : SizedBox(),
                  Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
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
              title: Column(
                children: [
                  allQuestionsAnswered && tapped ? Text("Skor : ${question?.questions[number].score} / ${(100 / (question!.questions.length)).ceil()}", style: TextStyle(fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold)) : SizedBox(),
                  Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
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
    TextEditingController controller = TextEditingController(text: question.selectedAnswer ?? '');
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
              controller: controller, // ✅ Always initializes with selectedAnswer
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
                  question.selectedAnswer = answer; // ✅ Saves the answer
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
