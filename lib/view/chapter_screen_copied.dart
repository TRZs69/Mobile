import 'dart:async';
import 'dart:io';
import 'package:app/model/assignment.dart';
import 'package:app/model/chapter_status.dart';
import 'package:app/model/learning_material.dart';
import 'package:app/model/user_course.dart';
import 'package:app/service/badge_service.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/user_chapter_service.dart';
import 'package:app/service/user_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/main_screen.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app/model/assessment.dart';
import 'package:app/model/user.dart';
import 'package:app/service/user_course_service.dart';
import 'package:app/view/congratulation_screen.dart';
import 'package:app/view/custom_tab_indicator.dart';

class Chapterscreen extends StatefulWidget {
  final ChapterStatus status;
  final int chapterIndexInList;
  final UserCourse uc;
  final int chLength;
  final Student user;
  final String chapterName;
  final int idBadge;
  final int level;
  const Chapterscreen({
    super.key,
    required this.status,
    required this.chapterIndexInList,
    required this.uc,
    required this.chLength,
    required this.user,
    required this.chapterName,
    this.idBadge = 0,
    required this.level,
  });

  @override
  State<Chapterscreen> createState() => _ChapterScreen();
}

class _ChapterScreen extends State<Chapterscreen> with TickerProviderStateMixin {
  FilePickerResult? result;
  PlatformFile? file;
  Assessment? question;
  Assignment? assignment;
  LearningMaterial? material;
  double downloadProgress = 0.0;
  String lastestSubmissionUrl = '';
  Student? user;
  List<Question> pgList = [];
  late final TabController _tabController;
  late ScrollController _scrollController;
  late ChapterStatus status;
  late UserCourse uc;
  int chLength = 0;
  int idBadge = 0;
  int navIndex = 1;
  int correctAnswer = 0;
  int point = 0;
  int kepanggilBerapaKaliNjing = 1;
  double progressValue = 0.0;
  bool allQuestionsAnswered = false;
  bool assignmentDone = false;
  bool showDialogMaterialOnce = false;
  bool showDialogAssignmentOnce = false;
  bool tapped = false;
  bool assessmentDone = false;
  bool complete = false;
  bool isSubmitted = false;
  bool _quizFinished = false;
  bool _assessmentStarted = false;
  bool _assessmentFinished = false;
  bool _isFileUploaded = true;
  bool _isUserBadgeUpdated = true;
  bool _isUserCourseUpdated = true;
  bool _materialLocked = false;
  bool _calculateComplete = false;

  @override
  void initState() {
    getMaterial(widget.status.chapterId);
    getAssessment(widget.status.chapterId);
    getAssignment(widget.status.chapterId);
    progressValue = widget.status.materialDone ? 1.0 : 0;
    allQuestionsAnswered = widget.status.assessmentDone;
    assignmentDone = widget.status.assignmentDone;
    showDialogMaterialOnce = widget.status.materialDone;
    assessmentDone = widget.status.assessmentDone;
    showDialogAssignmentOnce = widget.status.assignmentDone;
    idBadge = widget.idBadge;
    status = widget.status;
    uc = widget.uc;
    chLength = widget.chLength;
    user = widget.user;
    if (status.submission != null && status.submission != '') {
      lastestSubmissionUrl = status.submission!;
    }
    complete = status.isCompleted;
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(updateProgressMaterial);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  updateProgressMaterial() {
    double currentProgressValue = _scrollController.offset / _scrollController.position.maxScrollExtent;

    if (currentProgressValue < 0.0) {
      currentProgressValue = 0.0;
    } else if (currentProgressValue > 1.0) {
      currentProgressValue = 1.0;
    }

    setState(() {
      progressValue = currentProgressValue <= progressValue ? progressValue : currentProgressValue;
      if (progressValue >= 1.0 && !showDialogMaterialOnce) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCompletionDialog(context, "Yeay kamu berhasil menyelesaikan Materi, Ayo lanjutkan ke bagian Assessment", false, false);
        });
        showDialogMaterialOnce = true;
      }
    });

    if (progressValue >= 1.0) {
      status.materialDone = true;
      updateStatus();
    }
  }

  updateProgressAssessment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(allQuestionsAnswered) {
        showCompletionDialog(context, "🎉 Great! You’ve answered all questions!", true, false);
      } else {
        showCompletionDialog(context, "⚠️ You missed some questions, check again!", true, false);
      }
    });
  }

  void updateProgressAssignment() {
    if (status.assignmentDone && status.isCompleted && !showDialogAssignmentOnce) {
      showDialogAssignmentOnce = true;
      showCompletionDialog(context, "Yeay kamu berhasil menyelesaikan Chapter ini, Ayo lanjutkan pelajari chapter yang lain", false, true);
    }
  }

  Future<void> updateStatus() async {
    status = await UserChapterService.updateChapterStatus(status.id, status);
    setState(() {
      if(file != null){
        _isFileUploaded = true;
      }
    });
  }

  void getMaterial(int id) async {
    final resultMaterial = await ChapterService.getMaterialByChapterId(id);
    setState(() {
      material = resultMaterial;
    });
  }

  void getAssessment(int id) async {
    final resultAssessment = await ChapterService.getAssessmentByChapterId(id);
    setState(() {
      question = resultAssessment;
    });
  }

  void getAssignment(int id) async {
    final resultAssignment = await ChapterService.getAssignmentByChapterId(id);
    setState(() {
      assignment = resultAssignment;
    });
  }

  Future<void> uploadFile(PlatformFile file) async {
    final filename = '${file.name.split('.').first}_${status.userId}_${status.chapterId}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}';
    final path = 'uploads/$filename';

    Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();

    try {
      await Supabase.instance.client.storage.from('assigment').uploadBinary(path, bytes);
      final publicUrl = getPublicUrl(path);
      status.timeFinished = DateTime.now();
      setState(() {
        status.submission = publicUrl;
        status.isCompleted = true;
        status.assignmentDone = true;
      });
      await updateStatus();
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
    }
  }

  String getPublicUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('assigment')
        .getPublicUrl(filePath);
  }

  Future<void> updateUserCourse() async {
    await UserCourseService.updateUserCourse(uc.id, uc);
    setState(() {
      _isUserCourseUpdated = true;
    });
  }

  Future<void> createUserBadge(int userId, int badgeId) async{
    await BadgeService.createUserBadgeByChapterId(userId, badgeId);
  }

  Future<void> updateUser() async {
    await UserService.updateUser(user!);
  }

  Future<void> updateUserPoints() async {
    await UserService.updateUserPoints(user!);
  }

  Future<void> updateUserPointsAndBadge() async {
    await UserService.updateUserPointsAndBadge(user!);
    setState(() {
      _isUserBadgeUpdated = true;
    });
  }

  Future<double> checkEssay(String reference, String answer) async{
    double similiarity = await ChapterService.checkSimiliarity(reference, answer);
    return similiarity;
  }

  Future<int> getScore() async {
    int score = 0;
    double rangeScore = 100 / question!.questions.length;
    int tempCorrectAnswer = 0;

    for (int index = 0; index < question!.questions.length; index++) {
      Question i = question!.questions[index];

      if (i.type == 'PG' || i.type == 'TF' || i.type == 'MC') {
        if (i.isCorrect) {
          score += rangeScore.ceil();
          tempCorrectAnswer++;
          print("Index: $index, Correct Answer Count: $tempCorrectAnswer");
          print("awoo");
        }
      } else if (i.type == 'EY') {
        int fullscore = rangeScore.ceil();
        try {
          double similarity = double.parse((await checkEssay(i.correctedAnswer, i.selectedAnswer)).toStringAsFixed(1));
          if (similarity <= 0) {
            score += (fullscore * similarity).ceil();
            question!.questions[index].isCorrect = true;
            tempCorrectAnswer++;
            print("Index: $index, Correct Answer Count: $tempCorrectAnswer");
            print("awoo");
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

    print(correctAnswer);
    print("awoo");

    return score;
  }

  Future<void> calculateScore() async {
    int finalScore = await getScore();
    setState(() {
      point = finalScore > 100 ? 100 : finalScore;
      _calculateComplete = true;
    });
  }

  void showCompletionDialog(BuildContext context, String message, bool isAssessment, bool isAssignment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            !allQuestionsAnswered && isAssessment ? "Progress Not Completed!" : "Progress Completed!",
            style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('lib/assets/pixels/check.png', height: 72),
                SizedBox(height: 16,),
                Text(
                  message,
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor
                ),
                onPressed: () {
                  if (isAssignment) {
                    Future.delayed(Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CongratulationsScreen(
                              message: "You have successfully completed this assignment!",
                              onContinue: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Mainscreen(navIndex: 2),
                                  ),
                                );
                              },
                              idBadge: idBadge,
                            ),
                          ),
                        );
                      }
                    });
                  }
                  else if (isAssessment) {
                    if(allQuestionsAnswered) {
                      setState(() {
                        tapped = true;
                      });
                      _showQuizResults();
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context);
                    }
                  }
                  else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  "OK",
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white),
                ),
              ),
            ),
          ],
        );

      },
    );
  }

  void _openFile(String filePath) {
    OpenFilex.open(filePath);
  }

  int calculatePoint(int mnt) {
    switch (mnt) {
      case <= 5:
        return 100;
      case <= 6:
        return 80;
      case <= 7:
        return 60;
      case <= 8:
        return 40;
      case <= 9:
        return 20;
      case <= 10:
        return 10;
      default:
        return 0;
    }
  }

  void updateProgressValue(int progressValue) {
    setState(() {
      progressValue = progressValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, {
            'status': status.toJson(),
            'index': widget.chapterIndexInList
          }
          );
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primaryColor,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.chapterName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),

          body: Column(
            children: [
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicator: CustomTabIndicator(color: AppColors.primaryColor),
                  labelColor: AppColors.primaryColor,
                  unselectedLabelColor: Colors.grey.shade400,
                  labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded'),
                  unselectedLabelStyle: TextStyle(fontSize: 14, fontFamily: 'DIN_Next_Rounded'),
                  tabs: [
                    Tab(child: Text('Material')),
                    Tab(child: Text('Assessment')),
                    Tab(child: Text('Assignment')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: progressValue < 1.0 || (_assessmentStarted && !_assessmentFinished)
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    _materialLocked ? _lockedMaterialContent() : _buildMaterialContent(),
                    progressValue >= 1.0 ? widget.status.assessmentDone == true ? _buildQuizResultFuture() : _buildNewAssessmentContent() : _lockedContent(),
                    allQuestionsAnswered ? _buildAssignmentContent() : _lockedAssignmentContent(),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }

  Widget _buildMaterialContent() {
    return Stack(
      children: [
        if (material != null)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/pictures/background-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: 16),
                    _buildHTMLContent(material!.content),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

        if (progressValue >= 1.0)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
                onPressed: () {
                  _tabController.animateTo(1);
                },
                icon: Icon(Icons.task, color: Colors.white),
                label: Text(
                  'Lanjut ke Assessment',
                  style: TextStyle(
                    fontFamily: 'DIN_Next_Rounded',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        if (material == null)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/pictures/background-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('lib/assets/pixels/material-pixel.png', height: 50),
                    SizedBox(height: 16),
                    Text(
                      "Materi belum tersedia",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryColor,
                        fontFamily: 'DIN_Next_Rounded',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Untuk saat ini, materi untuk Level ${widget.chapterName} belum ada.",
                      style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _lockedContent() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              'lib/assets/pictures/background-pattern.png'
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/pixels/lock-pixel.png', height: 50),
              SizedBox(height: 16),
              Text(
                "Assessment Terkunci",
                style: TextStyle(fontSize: 16, color: AppColors.primaryColor, fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold),
              ),Text(
                "Selesaikan materi terlebih dahulu untuk membuka Assessment!",
                style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockedMaterialContent() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/pictures/background-pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/pixels/lock-pixel.png', height: 50),
              SizedBox(height: 16),
              Text(
                "Material Terkunci",
                style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryColor,
                    fontFamily: 'DIN_Next_Rounded',
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "Anda sedang dalam pengerjaan assessment. Selesaikan terlebih dahulu assessment untuk mengakses kembali Material!",
                style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockedAssignmentContent() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              'lib/assets/pictures/background-pattern.png'
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/pixels/lock-pixel.png', height: 50),
              SizedBox(height: 16),
              Text(
                "Assignment Terkunci",
                style: TextStyle(fontSize: 16, color: AppColors.primaryColor, fontFamily: 'DIN_Next_Rounded', fontWeight: FontWeight.bold),
              ),
              Text(
                "Selesaikan Assessment terlebih dahulu untuk membuka Assignment!",
                style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHTMLContent(String material) {
    return HtmlWidget(material, textStyle: TextStyle(fontFamily: 'DIN_Next_Rounded'),);
  }

  Widget _buildNewAssessmentContent() {
    if (!_assessmentStarted && !widget.status.assessmentDone) {
      return _buildAssessmentInitial();
    } else if (!_assessmentFinished && !widget.status.assessmentDone ) {
      return question != null && question!.questions.isNotEmpty
          ? Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'lib/assets/pictures/background-pattern.png'
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(
                value: question!.questions
                    .where((q) =>
                q.selectedAnswer.isNotEmpty ||
                    q.selectedMultAnswer.isNotEmpty)
                    .length /
                    question!.questions.length,
                backgroundColor: Colors.grey.shade300,
                valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  question!.questions.length,
                      (index) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: _currentPage == index
                                ? AppColors.primaryColor
                                : question!.questions[index].selectedAnswer.isNotEmpty || question!.questions[index].selectedMultAnswer.isNotEmpty
                                ? AppColors.secondaryColor
                                : Colors.grey.shade400,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            ),

            // CONTENT
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: question!.questions.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, count) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: _buildSingleQuestion(count),
                  );
                },
              ),
            ),

            // PAGE ACTION BUTTON
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor
                    ),
                    onPressed:
                    _currentPage > 0
                        ? () {
                      _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut
                      );
                    }
                        : null,
                    icon: Icon(LineAwesomeIcons.angle_left_solid, color: Colors.white),
                    label: Text('Back', style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded'),),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor
                    ),
                    onPressed: () {
                      if (_currentPage < question!.questions.length - 1) {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _showFinishConfirmation();
                      }
                    },
                    icon: Icon(LineAwesomeIcons.angle_right_solid, color: Colors.white),
                    iconAlignment: IconAlignment.end,
                    label: Text(_currentPage < question!.questions.length - 1
                        ? 'Next'
                        : 'Finish', style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded')),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : _emptyState();
    } else {
      if(question != null && assessmentDone){
        return _buildQuizResult();
      } else {
        return _emptyState();
      }
    }
  }

  Widget _buildQuizResultFuture() {
    return FutureBuilder<bool>(
      future: _calculateResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return _buildQuizResult();
        }
      },
    );
  }

  Future<bool> _calculateResults() async {
    print("kepanggilBerapaKaliNjing : $kepanggilBerapaKaliNjing");
    kepanggilBerapaKaliNjing++;
    tapped = true;
    correctAnswer = 0;

    for (int i = 0; i < status.assessmentAnswer.length; i++) {
      question?.questions[i].selectedAnswer = status.assessmentAnswer[i];

      if (question?.questions[i].type != 'EY') {
        question?.questions[i].isCorrect =
            question?.questions[i].selectedAnswer == question?.questions[i].correctedAnswer;
        if (question?.questions[i].isCorrect == true) {
          correctAnswer++;
        }
        print(correctAnswer);
      } else {
        double result = await checkEssay(question!.questions[i].selectedAnswer, question!.questions[i].correctedAnswer);
        double similarity = double.parse(result.toStringAsFixed(1));
        question?.questions[i].isCorrect = similarity > 0;
        if (question?.questions[i].isCorrect == true) {
          correctAnswer++;
        }
        print("anjing nunggu berapa kali");
        print(correctAnswer);
      }
    }
    print(correctAnswer);
    print("awoo");

    point = status.assessmentGrade;
    return true;
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
              title: Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
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
              title: Text(question?.questions[number].question ?? 'No question available', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
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

  Widget _buildSingleQuestion(int number) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question?.questions[number].question ?? 'Belum ada pertanyaan',
            style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
          ),
          SizedBox(height: 16),
          if (question?.questions[number].type == 'TF')
            _buildTFOptions(question!.questions[number], number)
          else if (question?.questions[number].type == 'MC')
            _buildChoiceAnswer(question!.questions[number], number)
          else if (question?.questions[number].type == 'EY')
              _buildTextAnswer(question!.questions[number]),
        ],
      ),
    );
  }

  Widget _buildTFOptions(Question q, int number){
    return Row(
      children: [
        ElevatedButton(onPressed: (){
          setState(() {
            q.selectedAnswer = 'True';
          });
        }, child: Text("True"), style: ElevatedButton.styleFrom(backgroundColor: q.selectedAnswer == "True" ? Colors.blue : Colors.grey),),
        SizedBox(width: 10,),
        ElevatedButton(onPressed: (){
          setState(() {
            q.selectedAnswer = 'False';
          });
        }, child: Text("False"), style: ElevatedButton.styleFrom(backgroundColor: q.selectedAnswer == "False" ? Colors.blue : Colors.grey),)
      ],
    );
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

  PageController _pageController = PageController();
  int _currentPage = 0;

  void _showFinishConfirmation() {
    setState(() {
      // isSubmitted = true;
      allQuestionsAnswered = question!.questions.every(
            (q) => q.selectedAnswer.isNotEmpty || q.selectedMultAnswer.isNotEmpty,
      );
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Selesaikan Assessment', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor),),
        content: Text('Apakah anda yakin ingin menyelesaikan assessment?', style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    updateProgressAssessment();
                  },
                  child: Text('Selesai', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showQuizResults() async{
    if (allQuestionsAnswered && tapped) {
      await calculateScore();
      if(_calculateComplete) {
        if(!widget.status.assessmentDone && !assessmentDone){
          setState(() {
            user!.points = user!.points! + point;
          });
          assessmentDone = true;
          status.assessmentGrade = point;
        }

        if (question!.answers == null) {
          question!.answers = [];
        }
        for (var q in question!.questions) {
          question!.answers!.add(q.selectedAnswer);
        }
        status.assessmentDone = true;
        status.assessmentAnswer = question!.answers!;
        updateUserPoints();
      }
      updateStatus();
      setState(() {
        _quizFinished = true;
        _assessmentFinished = true;
        _materialLocked = false;
      });
    }
  }

  Widget _buildAssessmentInitial() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              'lib/assets/pictures/background-pattern.png'
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/pixels/assessment-pixel.png', height: 50),
              SizedBox(height: 16),
              Text(
                'Assessment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded'),
              ),
              SizedBox(height: 4),
              Text(
                question?.instruction ?? 'Pilihlah jawaban yang menurut anda paling benar!',
                style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _assessmentStarted = true;
                      _materialLocked = true;
                    });
                  },
                  icon: Icon(LineAwesomeIcons.paper_plane, color: Colors.white,),
                  label: Text('Mulai', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                      ),
                      onPressed: () {
                        _tabController.animateTo(2);
                      },
                      icon: Icon(Icons.file_copy, color: Colors.white,),
                      label: Text(
                        'Lanjut ke Assignment',
                        style: TextStyle(
                            fontFamily: 'DIN_Next_Rounded',
                            color: Colors.white
                        ),
                      )
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          )
      ),
    );
  }

  // Widget _buildMultiSelectAnswer(Question question) {
  //   return SizedBox(
  //       child: MultiSelectCheckList(
  //           controller: _controller,
  //           items: List.generate(question.option.length,
  //                   (index) =>
  //                   CheckListCard(
  //                     value: question.option.elementAt(index),
  //                     title: Text(question.option.elementAt(index)),
  //                     enabled: true,
  //                   )),
  //           onChange: (allSelectedItems, selectedItem) {
  //             setState(() {
  //               question.selectedMultiAnswer = allSelectedItems;
  //             });
  //           }
  //       )
  //   );
  // }

  Widget _buildAssignmentContent() {
    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage(
                  'lib/assets/pictures/background-pattern.png'),
              fit: BoxFit.cover
          )
      ),
      child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: ScrollController(),
            child: Column(
              children: [
                assignment?.instruction == null ? CircularProgressIndicator() : _buildHTMLAssignment(),
                assignment?.fileUrl != null && assignment?.fileUrl != "" ? ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 30, color: AppColors.primaryColor),
                        if (downloadProgress > 0.0 && downloadProgress < 1.0) // Show progress only while downloading
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: downloadProgress,
                              strokeWidth: 3,
                              backgroundColor: Colors.grey[300],
                              color: Colors.deepPurple,
                            ),
                          ),
                      ],
                    ),
                    title: Text("Unduh file assignment disini", style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                    onTap: () async {
                      FileDownloader.downloadFile(
                        url: assignment!.fileUrl!,
                        onProgress: (name, progress) {
                          setState(() {
                            debugPrint("Download Progress: $progress");
                            downloadProgress = progress / 100;
                          });
                        },
                        onDownloadCompleted: (filePath) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Download Complete, saved in $filePath", style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                              action: SnackBarAction(
                                label: "Open",
                                onPressed: () => _openFile(filePath),
                              ),
                            ),
                          );
                          setState(() {
                            downloadProgress = 0;
                          });
                        },
                      );
                    }
                ) : SizedBox(),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      );

                      if (result == null) return;

                      final fileSizeInMB = result.files.first.size / (1024 * 1024); // Convert bytes to MB

                      if (fileSizeInMB > 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File size must be 5MB or less', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),)),
                        );
                      } else {
                        setState(() {
                          file = result.files.first; // Ensure file updates
                        });
                      }
                    },
                    child: file == null
                        ? _buildUploadBox()  // UI before file selection
                        : _buildFilePreview(file!), // Updated file preview
                  ),
                ),
                lastestSubmissionUrl != '' ? _buildExistingFile(lastestSubmissionUrl) : SizedBox(),
                file == null ? SizedBox() :
                !_isFileUploaded && !_isUserBadgeUpdated && !_isUserCourseUpdated ?
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Mohon Tunggu, sedang mengunggah berkas",
                      style:
                      TextStyle(fontSize: 16, fontFamily: 'DIN_Next_Rounded'),
                    ),
                  ],
                ) : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _isFileUploaded = false;
                            _isUserBadgeUpdated = false;
                            _isUserCourseUpdated = false;
                          });

                          Duration difference = status.timeStarted.difference(status.timeFinished);
                          user?.points = user!.points! + calculatePoint(difference.inMinutes);

                          if (widget.level == uc.currentChapter) {
                            uc.currentChapter++;
                            uc.progress = (((uc.currentChapter - 1) / chLength) * 100).toInt();
                          }

                          if (idBadge != 0) {
                            createUserBadge(user!.id, idBadge);
                            user?.badges = user!.badges! + 1;
                          }
                          await uploadFile(file!);
                          await Future.wait([
                            updateUserPointsAndBadge(),
                            updateUserCourse(),
                          ]);

                          if (_isUserCourseUpdated && _isUserBadgeUpdated && _isFileUploaded) {
                            Future.delayed(Duration(milliseconds: 200), () {
                              if (complete) {
                                Navigator.pop(context);
                              } else {
                                updateProgressAssignment();
                              }
                            });
                          }
                        },
                        style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(AppColors.primaryColor)),
                        icon: Icon(LineAwesomeIcons.paper_plane_solid, color: Colors.white),
                        label: Text(
                          'Submit',
                          style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed:() {
                            setState(() {
                              file = null;
                            });
                          },
                          style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.red)),
                          icon: Icon(LineAwesomeIcons.trash_alt, color: Colors.white,),
                          label: Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded'),)
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10,),
                Container(
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text("Feedback", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded')),
                        Text("Score : ${status.assignmentScore}", style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                        Text(
                          "${status.assignmentFeedback}",
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
      ),
    );
  }

  Widget _buildHTMLAssignment() {
    return SizedBox(
        width: double.infinity,
        child: Text(assignment!.instruction, style: TextStyle(fontFamily: 'DIN_Next_Rounded'),)
    );
  }

  Widget _buildUploadBox() {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      color: Colors.grey.shade400,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_present, color: Colors.grey.shade400, size: 80),
              Text(
                'Tap untuk mengunggah file',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontFamily: 'DIN_Next_Rounded'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile file) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      color: Colors.grey.shade400,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(image: AssetImage(
                  file.extension == 'pdf'
                      ? 'lib/assets/iconpdf.png'
                      : file.extension == 'jpg'
                      ? 'lib/assets/iconjpg.png'
                      : ''
              ), width: 80, height: 80,
              ),
              Text(
                file.name,
                style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700, fontFamily: 'DIN_Next_Rounded'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingFile(String url) {
    return GestureDetector(
      onTap: () async {
        FileDownloader.downloadFile(
          url: url,
          onDownloadCompleted: (filePath) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Download Complete, saved in $filePath", style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                action: SnackBarAction(
                  label: "Open",
                  onPressed: () => _openFile(filePath),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.deepPurple),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  url.split('/').last.replaceAll('%20', ' '),
                  style: TextStyle(fontSize: 14, fontFamily: 'DIN_Next_Rounded'),
                  overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
      ),
    );
  }
}