import 'dart:math';

import 'package:app/model/chapter_status.dart';
import 'package:app/model/user_course.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/already_finished_assessment.dart';
import 'package:app/view/assessment_screen.dart';
import 'package:app/view/assignment_screen.dart';
import 'package:app/view/learning_assistant_quick_ask.dart';
import 'package:app/view/learning_assistant_screen.dart';
import 'package:app/view/material_screen.dart';
import 'package:flutter/material.dart';

import '../model/user.dart';
import 'custom_tab_indicator.dart';

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
  State<Chapterscreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<Chapterscreen> with TickerProviderStateMixin {
  Student? user;
  late TabController _tabController;
  int _currentIndex = 0;
  final List<Widget?> _screens = [null, null, null]; // Lazy-loaded tabs
  late ChapterStatus status;
  bool materialComplete = false;
  bool _materialLocked = false;
  bool _assessmentStarted = false;
  bool _assessmentFinished = false;
  bool _showFabHelp = true;
  late final String _fabHelpText;

  static const List<String> _fabHelpTexts = [
    "Butuh bantuan?",
    "Ada yang belum kamu pahami?",
  ];

  @override
  void initState() {
    materialComplete = widget.status.materialDone;
    status = widget.status;
    user = widget.user;
    super.initState();
    _fabHelpText = _fabHelpTexts[Random().nextInt(_fabHelpTexts.length)];
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showFabHelp = true);
      Future.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        setState(() => _showFabHelp = false);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void updateProgress(bool value) {
    setState(() {
      materialComplete = true;// Update progress in real-time
    });
    print("Material complete : $materialComplete");
  }

  void updateStatus(ChapterStatus value) {
    setState(() {
      status = value; // Update progress in real-time
    });
  }

  void updateMaterialLocked(bool value) {
    setState(() {
      _materialLocked = value; // Update progress in real-time
    });
  }

  void updateAssessmentStarted(bool value) {
    setState(() {
      _assessmentStarted = value; // Update progress in real-time
    });
  }

  void updateAssessmentFinished(bool value) {
    setState(() {
      _assessmentFinished = value; // Update progress in real-time
    });
  }

  Widget _buildPage(int index) {
    if (_screens[index] == null) {
      switch (index) {
        case 0:
          _screens[index] = _materialLocked
              ? _lockedMaterialContent()
              : MaterialScreen(status: widget.status, chapterName: widget.chapterName, updateProgress: updateProgress, updateStatus: updateStatus,);
          break;
        case 1:
          print('$materialComplete awoooooo');
          _screens[index] = materialComplete
              ? widget.status.assessmentDone
              ? AlreadyFinishedAssessmentAssessmentScreen(status: widget.status, user: widget.user)
              : AssessmentScreen(status: widget.status, user: widget.user, updateMaterialLocked: updateMaterialLocked, updateStatus: updateStatus, updateAssessmentFinished: updateAssessmentFinished, updateAssessmentStarted: updateAssessmentStarted,)
              : _lockedContent();
          break;
        case 2:
          _screens[index] = widget.status.assessmentDone || _assessmentFinished ?
              AssignmentScreen(status: status, user: widget.user, uc: widget.uc, level: widget.level, chLength: widget.chLength, idBadge: widget.idBadge, updateProgress: updateProgress, updateStatus: updateStatus) :
              _lockedAssignmentContent();
          break;
      }
    }
    return _screens[index]!;
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
            title: Text(widget.chapterName, style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'DIN_Next_Rounded')),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Material(
                color: Colors.white,
                child: IgnorePointer(
                  ignoring: _assessmentStarted && !_assessmentFinished, // Disable interaction when assessment is active
                  child: TabBar(
                    controller: _tabController,
                    indicator: CustomTabIndicator(color: AppColors.primaryColor),
                    labelColor: AppColors.primaryColor,
                    unselectedLabelColor: Colors.grey.shade400,
                    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded'),
                    unselectedLabelStyle: TextStyle(fontSize: 14, fontFamily: 'DIN_Next_Rounded'),
                    onTap: (index) {
                      if (_assessmentStarted && !_assessmentFinished) {
                        return; // Prevent tab switch
                      }
                      setState(() {
                        _currentIndex = index; // Allow tab switch
                      });
                    },
                    tabs: [
                      Tab(child: Text('Material')),
                      Tab(child: Text('Assessment')),
                      Tab(child: Text('Assignment')),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildPage(_currentIndex), // Only build the selected tab
              ),
            ],
          ),
          floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showFabHelp)
                  GestureDetector(
                    onTap: () => setState(() => _showFabHelp = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(color: AppColors.accentColor),
                      ),
                      child: Text(
                        _fabHelpText,
                        style: const TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  tooltip: 'Tanya Levely',
                  onPressed: () async {
                    setState(() => _showFabHelp = false);
                    final messages = await showLearningAssistantQuickAsk(
                      context,
                      courseId: widget.uc.courseId,
                      level: widget.level,
                      chapterName: widget.chapterName,
                    );
                    if (!context.mounted) return;
                    if (messages == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LearningAssistantScreen(
                          courseId: widget.uc.courseId,
                          level: widget.level,
                          chapterName: widget.chapterName,
                          initialMessages: messages,
                        ),
                      ),
                    );
                  },
                  child: Icon(Icons.smart_toy_outlined),
                ),
              ],
            ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        )
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

}
