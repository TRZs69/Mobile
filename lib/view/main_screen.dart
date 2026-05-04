import 'package:app/view/course_detail_screen.dart';
import 'package:app/view/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../global_var.dart';
import '../service/api_cache_service.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'mycourse_screen.dart';

Color purple = Color(0xFF441F7F);
Color backgroundNavHex = Color(0xFFF3EDF7);
const url = 'https://www.globalcareercounsellor.com/blog/wp-content/uploads/2018/05/Online-Career-Counselling-course.jpg';

class Mainscreen extends StatefulWidget {
  final int navIndex;
  const Mainscreen({super.key, this.navIndex = 0});

  @override
  State<Mainscreen> createState() => _MainState();
}

class _MainState extends State<Mainscreen> {
  static const String _mainTutorialKeyBase = 'hasSeenMainTutorial';
  static const String _profileEloTutorialDoneKeyBase = 'profileEloTutorialDone';
  static const String _selectedCourseLegacyKey = 'getCourseDetail';
  static const String _selectedCourseKey = 'lastestSelectedCourse';
  static const String _selectedCourseAltKey = 'latestSelectedCourse';

  late SharedPreferences pref;
  int idCourse = 0;
  int navIndex = 0;
  bool _isTutorialActive = false;
  int _tutorialStepIndex = 0;
  int _courseRefreshNonce = 0;
  int _profileTutorialReplayNonce = 0;
  Timer? _heartbeatTimer;
  StreamSubscription? _apiErrorSubscription;

  final List<_TutorialStep> _tutorialSteps = const [
    _TutorialStep(
      navIndex: 0,
      title: 'Selamat Datang di LeveLearn',
      description:
          'Ini adalah Home. Kamu bisa melihat ringkasan progres, akses cepat ke materi, dan rekomendasi pembelajaran.',
    ),
    _TutorialStep(
      navIndex: 1,
      title: 'Menu Search',
      description:
          'Di menu Search, kamu dapat mencari dan memilih course yang ingin dipelajari.',
    ),
    _TutorialStep(
      navIndex: 2,
      title: 'Menu Course',
      description:
          'Di menu Course, kamu melihat detail course aktif: chapter, materi, assignment, assessment, dan progres belajarmu.',
    ),
    _TutorialStep(
      navIndex: 3,
      title: 'Menu Friends',
      description:
          'Di menu Friends, kamu bisa melihat teman belajar dan membangun motivasi belajar bersama.',
    ),
    _TutorialStep(
      navIndex: 4,
      title: 'Menu Profile',
      description:
          'Di menu Profile, kamu dapat melihat profil, badge, dan pengaturan akun.',
    ),
  ];

  void getCourseDetail() async {
    int storedId = pref.getInt(_selectedCourseKey) ??
        pref.getInt(_selectedCourseAltKey) ??
        pref.getInt(_selectedCourseLegacyKey) ??
        0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        idCourse = storedId;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    navIndex = widget.navIndex;
    _initPreferences();
  }

  void _initPreferences() async {
    pref = await SharedPreferences.getInstance();
    if (!mounted) return;

    _apiErrorSubscription = ApiCacheService.errorController.stream.listen(_handleApiError);

    getCourseDetail();
    _maybeStartMainTutorial();
    _startHeartbeat();
  }

  void _handleApiError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'DIN_Next_Rounded')),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _startHeartbeat() async {
    final sessionId = pref.getInt('sessionId');
    final token = pref.getString('token');
    
    if (sessionId == null || token == null) return;

    await _sendHeartbeat(sessionId, token);

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      await _sendHeartbeat(sessionId, token);
    });
  }

  Future<void> _sendHeartbeat(int sessionId, String token) async {
    try {
      final response = await ApiCacheService.post(
        Uri.parse('${GlobalVar.baseUrl}/evaluation/session/heartbeat'),
        body: {'sessionId': sessionId},
      );
      
      if (response.statusCode != 204) {
        print('Heartbeat failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Heartbeat error: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _apiErrorSubscription?.cancel();
    super.dispose();
  }

  String _mainTutorialKeyForCurrentUser() {
    final userId = pref.getInt('userId');
    if (userId == null) {
      return _mainTutorialKeyBase;
    }
    return '${_mainTutorialKeyBase}_$userId';
  }

  String _profileEloTutorialKeyForCurrentUser() {
    final userId = pref.getInt('userId');
    if (userId == null) {
      return _profileEloTutorialDoneKeyBase;
    }
    return '${_profileEloTutorialDoneKeyBase}_$userId';
  }

  Future<void> _maybeStartMainTutorial() async {
    final hasSeenTutorial = pref.getBool(_mainTutorialKeyForCurrentUser()) ?? false;
    if (hasSeenTutorial || !mounted) {
      return;
    }

    _isTutorialActive = true;
    _tutorialStepIndex = 0;
    _showTutorialDialogForStep(0);
  }

  Future<void> _finishTutorial() async {
    await pref.setBool(_mainTutorialKeyForCurrentUser(), true);
    if (!mounted) return;
    setState(() {
      _isTutorialActive = false;
    });
  }

  Future<void> _restartTutorialFromHome() async {
    await pref.setBool(_mainTutorialKeyForCurrentUser(), false);
    await pref.setBool(_profileEloTutorialKeyForCurrentUser(), false);
    if (!mounted) return;

    setState(() {
      _isTutorialActive = true;
      _tutorialStepIndex = 0;
      navIndex = 0;
      _profileTutorialReplayNonce++;
    });

    _showTutorialDialogForStep(0);
  }

  void _onProfileEloTutorialCompleted() {
    if (!mounted) return;

    setState(() {
      navIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'welcome-learning-dialog',
        barrierColor: Colors.black.withOpacity(0.1),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration,
                            color: Color(0xFF441F7F), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tutorial selesai. Selamat belajar dan semangat level up!',
                            style: TextStyle(
                              fontFamily: 'DIN_Next_Rounded',
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Oke',
                            style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      );
    });
  }

  void _showTutorialDialogForStep(int stepIndex) {
    if (!mounted) return;

    if (stepIndex >= _tutorialSteps.length) {
      _finishTutorial();
      return;
    }

    setState(() {
      _tutorialStepIndex = stepIndex;
      navIndex = _tutorialSteps[stepIndex].navIndex;
    });
  }


  void updateIndex(int index) {
    if (_isTutorialActive) {
      return;
    }

    setState(() {
      navIndex = index;
    });
  }

  void _onNavTapped(int index) {
    if (_isTutorialActive) {
      return;
    }

    if (index == 2) {
      getCourseDetail();
    }

    setState(() {
      navIndex = index;
      if (index == 2) {
        _courseRefreshNonce++;
      }
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          updateIndex: updateIndex,
          onReplayTutorial: _restartTutorialFromHome,
        );
      case 1:
        return MycourseScreen();
      case 2:
        return CourseDetailScreen(id: idCourse, refreshNonce: _courseRefreshNonce);
      case 3:
        return FriendsScreen();
      case 4:
        return ProfileScreen(
          isActive: navIndex == 4,
          isMainTutorialActive: _isTutorialActive,
          tutorialReplayNonce: _profileTutorialReplayNonce,
          onSubTutorialCompleted: _onProfileEloTutorialCompleted,
        );
      default:
        return HomeScreen(
          updateIndex: updateIndex,
          onReplayTutorial: _restartTutorialFromHome,
        );
    }
  }

  List<Widget> _buildTutorialOverlay() {
    return [
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.18),
        ),
      ),
      _buildTutorialCard(),
    ];
  }

  Widget _buildTutorialCard() {
    final step = _tutorialSteps[_tutorialStepIndex];
    final isLastStep = _tutorialStepIndex == _tutorialSteps.length - 1;

    return Positioned(
      right: 14,
      bottom: 14,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lightbulb_outline_rounded,
                          size: 14, color: purple),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: purple,
                        ),
                      ),
                    ),
                    Text(
                      '${_tutorialStepIndex + 1}/${_tutorialSteps.length}',
                      style: TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(_tutorialSteps.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 4),
                      width: i == _tutorialStepIndex ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _tutorialStepIndex
                            ? purple
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontFamily: 'DIN_Next_Rounded',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: _finishTutorial,
                      child: Text(
                        'Lewati',
                        style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        if (isLastStep) {
                          _finishTutorial();
                        } else {
                          _showTutorialDialogForStep(_tutorialStepIndex + 1);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: purple,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          isLastStep ? 'Selesai' : 'Lanjut →',
                          style: const TextStyle(
                            fontFamily: 'DIN_Next_Rounded',
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: navIndex,
            children: [
              _buildPage(0),
              _buildPage(1),
              _buildPage(2),
              _buildPage(3),
              _buildPage(4),
            ],
          ),
          if (_isTutorialActive) ..._buildTutorialOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          onTap: _onNavTapped,
          currentIndex: navIndex,
          selectedLabelStyle: TextStyle(
              fontFamily:
              'DIN_Next_Rounded',
              fontWeight: FontWeight.bold
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily:
            'DIN_Next_Rounded',
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LineAwesomeIcons.building),
              label: 'Home',
            ),
            BottomNavigationBarItem(
                icon: Icon(LineAwesomeIcons.search_solid),
                label: 'Search',
                backgroundColor: Colors.black
            ),
            BottomNavigationBarItem(
                icon: Icon(LineAwesomeIcons.project_diagram_solid),
                label: 'Course',
                backgroundColor: Colors.black
            ),
            BottomNavigationBarItem(
                icon: Icon(LineAwesomeIcons.user_friends_solid),
                label: 'Friends',
                backgroundColor: Colors.black
            ),
            BottomNavigationBarItem(
                icon: Icon(LineAwesomeIcons.person_booth_solid),
                label: 'Profile',
                backgroundColor: Colors.black
            )
          ]
      ),
    );
  }

}

class _TutorialStep {
  final int navIndex;
  final String title;
  final String description;

  const _TutorialStep({
    required this.navIndex,
    required this.title,
    required this.description,
  });
}