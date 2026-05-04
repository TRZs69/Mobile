import 'dart:ui' as ui;

import 'package:app/global_var.dart';
import 'package:app/model/chapter.dart';
import 'package:app/model/user_badge.dart';
import 'package:app/service/badge_service.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/user_service.dart';
import 'package:app/view/about_app.dart';
import 'package:app/view/quick_access_screen.dart';
import 'package:app/view/trade_screen.dart';
import 'package:app/view/update_profile_screen.dart';
import 'package:app/view/widgets/custom_refresh_scroll.dart';
import 'package:app/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/badge.dart';
import '../model/course.dart';
import '../model/user.dart';
import '../service/course_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isActive;
  final bool isMainTutorialActive;
  final int tutorialReplayNonce;
  final VoidCallback? onSubTutorialCompleted;

  const ProfileScreen({
    super.key,
    this.isActive = false,
    this.isMainTutorialActive = false,
    this.tutorialReplayNonce = 0,
    this.onSubTutorialCompleted,
  });

  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  static const String _profileEloTutorialDoneKeyBase = 'profileEloTutorialDone';

  late SharedPreferences prefs;
  Student? user;
  bool isLoading = true;
  List<Student> list = [];
  int rank = 0;
  List<UserBadge>? userBadges = [];
  Course? course;
  Chapter? chapter;
  List<Course>? allCourses;
  bool _isEloSubTutorialDone = false;
  bool _isEloSubTutorialActive = false;
  int _eloTutorialStep = 0;
  final GlobalKey _eloHighlightKey = GlobalKey();
  final GlobalKey _tutorialOverlayStackKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  final List<String> _eloTutorialSteps = const [
    'Ini adalah ELO kamu. Angka ini jadi acuan sistem baru untuk mengatur tingkat kesulitan soal secara adaptif.',
    'Performa assessment bagus akan menaikkan ELO dan mendorong soal berikutnya lebih menantang. Jika performa turun, ELO menyesuaikan agar ritme belajar tetap pas. ELO juga dipakai untuk progres badge.',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onProfileScroll);
    getUserData();
  }

  void _onProfileScroll() {
    if (_isEloSubTutorialActive && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onProfileScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.tutorialReplayNonce != oldWidget.tutorialReplayNonce) {
      setState(() {
        _isEloSubTutorialDone = false;
        _isEloSubTutorialActive = false;
        _eloTutorialStep = 0;
      });
    }

    if ((widget.isActive && !oldWidget.isActive) ||
        (widget.isActive && oldWidget.isMainTutorialActive && !widget.isMainTutorialActive)) {
      _maybeStartEloSubTutorial();
    }
  }

  Future<void> getUserData() async {
    try {
      prefs = await SharedPreferences.getInstance();
      final idUser = prefs.getInt('userId');

      if (idUser == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      Student fetchedUser = await UserService.getUserById(
        idUser,
        onRevalidated: (freshUser) {
          if (!mounted) return;
          setState(() {
            user = freshUser;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        user = fetchedUser;
      });

      await Future.wait([
        getUserBadges(idUser),
        getAllUser(),
        getEnrolledCourse(idUser),
      ]);

      await _prepareProfileEloTutorial();
      _maybeStartEloSubTutorial();
    } catch (e) {
      // Keep profile screen responsive when network/data fetch fails.
      debugPrint('Failed to load profile data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Student> sortUserByElo(List<Student> list) {
    final sorted = List<Student>.from(list);
    sorted.sort((a, b) => (b.elo ?? 0).compareTo(a.elo ?? 0));
    return sorted;
  }

  Future<void> getAllUser() async {
    final result = await UserService.getAllUser();
    if (!mounted) return;
    setState(() {
      list = sortUserByElo(studentRole(result));
    });
    for (int i = 0; i < list.length; i++) {
      if(list[i].id == user?.id){
        setState(() {
          rank = i + 1;
        });
        break;
      }
    }
  }

  Future<void> getEnrolledCourse(int userId) async {
    final result = await CourseService.getEnrolledCourse(userId);
    if (!mounted) return;
    setState(() {
      allCourses = result;
    });
  }

  Future<void> getUserBadges(int userId) async {
    final result = await BadgeService.getUserBadgeListByUserId(
      userId,
      onRevalidated: (freshBadges) {
        if (!mounted) return;
        setState(() {
          userBadges = freshBadges;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      userBadges = result;
    });
  }

  Future<void> _prepareProfileEloTutorial() async {
    final tutorialDone = prefs.getBool(_profileEloTutorialKeyForCurrentUser()) ?? false;
    if (!mounted) return;

    setState(() {
      _isEloSubTutorialDone = tutorialDone;
    });

  }

  void _maybeStartEloSubTutorial() {
    if (!mounted) return;
    if (isLoading || user == null) return;
    if (!widget.isActive || widget.isMainTutorialActive) return;
    if (_isEloSubTutorialDone || _isEloSubTutorialActive) return;

    setState(() {
      _isEloSubTutorialActive = true;
      _eloTutorialStep = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureEloHighlightVisible();
    });
  }

  Future<void> _ensureEloHighlightVisible() async {
    final targetContext = _eloHighlightKey.currentContext;
    if (targetContext == null || !mounted) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  Future<void> _completeEloSubTutorial() async {
    await prefs.setBool(_profileEloTutorialKeyForCurrentUser(), true);
    if (!mounted) return;
    setState(() {
      _isEloSubTutorialDone = true;
      _isEloSubTutorialActive = false;
    });

    if (widget.onSubTutorialCompleted != null) {
      widget.onSubTutorialCompleted!();
    }
  }

  String _profileEloTutorialKeyForCurrentUser() {
    final id = user?.id ?? prefs.getInt('userId');
    if (id == null) {
      return _profileEloTutorialDoneKeyBase;
    }
    return '${_profileEloTutorialDoneKeyBase}_$id';
  }

  List<Student> studentRole(List<Student> list) {
    return list.where((user) => user.role == 'STUDENT').toList();
  }

  Future<Course> getCourseById(int id) {
    return CourseService.getCourse(id);
  }

  Future<Chapter> getChapterById(int id) {
    return ChapterService.getChapterById(id);
  }

  Future<void> logout() async {
    await AuthService.logout();
  }

  /// Navigasi setelah logout: selalu ke login.
  void _navigateAfterLogout() {
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    if (isLoading) {
      return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'lib/assets/pictures/background-pattern.png'
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Mohon Tunggu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
        ),
      )
    );
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: GlobalVar.primaryColor,
          automaticallyImplyLeading: false,
          title: const Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'DIN_Next_Rounded',
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Data profil tidak tersedia. Silakan login ulang.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'DIN_Next_Rounded',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalVar.primaryColor,
        automaticallyImplyLeading: false,
        title: Text(
            "Profile",
            style: TextStyle(
                fontFamily: 'DIN_Next_Rounded',
                color: Colors.white
            )),
      ),
      body:  Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(
                        'lib/assets/pictures/background-pattern.png'),
                    fit: BoxFit.cover
                )
            ),
          ),
          isLoading 
          ? Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                      'lib/assets/pictures/background-pattern.png'
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Mohon Tunggu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
              ),
            )
          ) 
          : Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              key: _tutorialOverlayStackKey,
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage(
                            'lib/assets/pictures/background-pattern.png'),
                        fit: BoxFit.cover
                    )
                  ),
                ),
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      Container(
                        color: GlobalVar.primaryColor,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child: ClipOval(
                                    child: currentUser.image != "" && currentUser.image != null ? Image.network(
                                      currentUser.image!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 100, color: Colors.white),
                                    )
                                        : const Icon(Icons.person, size: 100, color: Colors.white,),
                                  ),
                                ),
                              Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => UpdateProfile(user: currentUser)),
                                      );
                                    },
                                    child: Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: GlobalVar.secondaryColor),
                                      child: const Icon(
                                        LineAwesomeIcons.pencil_alt_solid,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  )
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                            Text(currentUser.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                  color: Colors.white
                              )),
                            Text(currentUser.studentId ?? '',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                  color: GlobalVar.accentColor
                              )),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              currentUser.eloTitle ?? 'Beginner',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontFamily: 'DIN_Next_Rounded',
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 32),
                            padding: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: _buildInfoColumn(
                                          LineAwesomeIcons.medal_solid,
                                          'Lencana',
                                          '${userBadges?.length}',
                                          GlobalVar.secondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: _buildInfoColumn(
                                          LineAwesomeIcons.user_check_solid,
                                          'Course',
                                          '${allCourses != null ? allCourses?.length : '0'}',
                                          GlobalVar.secondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: _buildInfoColumn(
                                          LineAwesomeIcons.trophy_solid,
                                          'Peringkat',
                                          '$rank / ${list.length}',
                                          GlobalVar.secondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: SizedBox()),
                                    Expanded(
                                      child: Center(
                                        child: _buildInfoColumn(
                                          LineAwesomeIcons.gem_solid,
                                          'Poin',
                                          '${currentUser.points ?? 0}',
                                          GlobalVar.secondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: _buildEloMetricWithHighlight(currentUser),
                                      ),
                                    ),
                                    Expanded(child: SizedBox()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                      SizedBox(
                      height: 4,
                    ),
                      Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 8,
                          ),
                          Text(
                            'Lencana Saya',
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: GlobalVar.primaryColor,
                              fontFamily: 'DIN_Next_Rounded',
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          SizedBox(
                            height: 64,
                            child: userBadges!.isNotEmpty ? ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: userBadges?.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    _showBadgeDetails(context, userBadges![index].badge);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: userBadges?[index].badge.image != null && userBadges?[index].badge.image != '' ?
                                      Image.network(
                                        userBadges![index].badge.image!,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(child: CircularProgressIndicator(strokeWidth: 2,));
                                        },
                                        errorBuilder: (context, error, stackTrace) => Image.asset('lib/assets/pictures/icon.png', fit: BoxFit.cover),
                                      ) : Image.asset('lib/assets/pictures/icon.png', fit: BoxFit.cover)
                                    ),
                                  ),
                                );
                              },
                            ) : Center(
                              child: Text('Kamu belum mempunyai badge', style: TextStyle(fontFamily: 'DIN_Next_Rounded'),),
                            )
                          ),
                          SizedBox(
                            height: 8,
                          ),
                        ],
                      ),
                    ),
                      ProfileMenuWidget(
                        title: "Trades",
                        icon: LineAwesomeIcons.coins_solid,
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TradeScreen(user: currentUser)),
                          );
                        },
                      ),
                      ProfileMenuWidget(
                        title: "Update Profile",
                        icon: LineAwesomeIcons.person_booth_solid,
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UpdateProfile(user: currentUser)),
                          );
                        },
                      ),
                      ProfileMenuWidget(
                        title: "Quick Access",
                        icon: LineAwesomeIcons.accessible,
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => QuickAccessScreen()),
                          );
                        },
                      ),
                      ProfileMenuWidget(
                        title: "App Rating",
                        icon: LineAwesomeIcons.star,
                        onPress: () {},
                      ),
                      ProfileMenuWidget(
                        title: "About App",
                        icon: LineAwesomeIcons.info_circle_solid,
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AboutAppScreen()),
                          );
                        },
                      ),
                      SizedBox(
                          height: 16
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                              onPressed: () async {
                                await logout();
                                _navigateAfterLogout();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GlobalVar.primaryColor,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                              ),
                              child: Text("Log Out", style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontFamily: 'DIN_Next_Rounded',
                                  color: Colors.white
                              ),)
                          ),
                        ),
                      ),
                      SizedBox(
                          height: 16
                      ),
                    ],
                  ),
                ),
                if (_isEloSubTutorialActive) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SpotlightScrimPainter(
                          focusRect: _getEloFocusRect(),
                          scrimColor: Colors.black.withOpacity(0.12),
                        ),
                      ),
                    ),
                  ),
                  _buildEloFloatingTutorialDialog(),
                ],
              ],
            ),
          ),
        ]
      )
    );
  }

  Rect? _getEloFocusRect() {
    final targetContext = _eloHighlightKey.currentContext;
    if (targetContext == null) return null;

    final targetBox = targetContext.findRenderObject();
    final overlayContext = _tutorialOverlayStackKey.currentContext;
    final overlayBox = overlayContext?.findRenderObject();
    if (targetBox is! RenderBox || overlayBox is! RenderBox) {
      return null;
    }

    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = topLeft & targetBox.size;
    return rect;
  }

  String _buildBadgeDescription(BadgeModel badge, Course course, Chapter chapter) {
    final normalizedName = badge.name.trim().toLowerCase();

    switch (normalizedName) {
      case 'beginner':
        return 'Badge Beginner diberikan saat kamu mulai menunjukkan pemahaman dasar pada materi ${course.courseName}. Terus lanjutkan progresmu ke level berikutnya.';
      case 'basic understanding':
        return 'Badge Basic Understanding menandakan kamu sudah memahami konsep-konsep inti pada materi ${course.courseName}. Pertahankan konsistensi belajarmu.';
      case 'developing learner':
        return 'Badge Developing Learner menunjukkan kemampuanmu mulai berkembang dengan stabil. Kamu sedang berada di jalur yang tepat untuk naik level.';
      case 'intermediate':
        return 'Badge Intermediate menandakan kemampuanmu sudah berada di tingkat menengah. Kamu berhasil melewati tantangan materi ${chapter.name} dengan baik.';
      case 'proficient':
        return 'Badge Proficient diberikan saat performamu sudah kuat dan konsisten. Tingkat pemahamanmu berada di atas rata-rata pembelajar.';
      case 'advanced':
        return 'Badge Advanced menunjukkan penguasaan materi yang tinggi. Kamu siap menghadapi soal dengan tingkat kesulitan lebih menantang.';
      case 'mastery':
        return 'Badge Mastery adalah pencapaian tertinggi. Ini menandakan kamu telah menunjukkan penguasaan mendalam pada materi ${course.courseName}.';
      default:
        return 'Badge ini diperoleh karena telah berhasil menyelesaikan ${course.courseName} sampai pada chapter ${chapter.name}.';
    }
  }

  void _showBadgeDetails(BuildContext context, BadgeModel badge) async {
    Course resultCourse = await getCourseById(badge.courseId);
    Chapter resultChapter = await getChapterById(badge.chapterId);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: badge.image != null  ?
                  Image.network(
                    badge.image!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => Image.asset('lib/assets/pictures/icon.png', fit: BoxFit.cover),
                  ) : Image.asset('lib/assets/pictures/icon.png', fit: BoxFit.cover),
                ),
                SizedBox(height: 16),
                Text(
                  badge.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded',
                    color: AppColors.primaryColor,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _buildBadgeDescription(badge, resultCourse, resultChapter),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Tutup',
                    style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildEloMetricWithHighlight(Student currentUser) {
    final isFocused = _isEloSubTutorialActive;
    return AnimatedContainer(
      key: _eloHighlightKey,
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isFocused ? Colors.amber.withOpacity(0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? Colors.amber.shade600 : Colors.transparent,
          width: 2,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: _buildInfoColumn(
        LineAwesomeIcons.fire_solid,
        'ELO',
        '${currentUser.elo ?? 750}',
        GlobalVar.secondaryColor,
      ),
    );
  }

  Widget _buildEloFloatingTutorialDialog() {
    final isLastStep = _eloTutorialStep == _eloTutorialSteps.length - 1;
    final isSecondStep = _eloTutorialStep == 1;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(14, isSecondStep ? 10 : 12, 14, isSecondStep ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 18, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ELO',
                      style: TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  Text(
                    '${_eloTutorialStep + 1}/${_eloTutorialSteps.length}',
                    style: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      fontSize: isSecondStep ? 10.5 : 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSecondStep ? 6 : 8),
              Text(
                _eloTutorialSteps[_eloTutorialStep],
                style: TextStyle(
                  fontFamily: 'DIN_Next_Rounded',
                  fontSize: isSecondStep ? 11.5 : 12,
                  height: 1.4,
                ),
              ),
              SizedBox(height: isSecondStep ? 10 : 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _completeEloSubTutorial,
                    child: const Text(
                      'Lewati',
                      style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: () {
                      if (isLastStep) {
                        _completeEloSubTutorial();
                      } else {
                        setState(() {
                          _eloTutorialStep++;
                        });
                      }
                    },
                    child: Text(
                      isLastStep ? 'Selesai' : 'Lanjut',
                      style: const TextStyle(fontFamily: 'DIN_Next_Rounded'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
      IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28,),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                // fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily:
                'DIN_Next_Rounded',
              ),
            ),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: GlobalVar.primaryColor,
                    fontFamily: 'DIN_Next_Rounded'))
          ],
        )
      ],
    );
  }
}

class _SpotlightScrimPainter extends CustomPainter {
  final Rect? focusRect;
  final Color scrimColor;

  const _SpotlightScrimPainter({
    required this.focusRect,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final layerBounds = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(fullRect, Paint()..color = scrimColor);

    if (focusRect != null) {
      final cutout = RRect.fromRectAndRadius(
        focusRect!,
        const Radius.circular(12),
      );
      canvas.drawRRect(
        cutout,
        Paint()
          ..blendMode = ui.BlendMode.clear
          ..isAntiAlias = true,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightScrimPainter oldDelegate) {
    return oldDelegate.focusRect != focusRect ||
        oldDelegate.scrimColor != scrimColor;
  }
}

class ProfileMenuWidget extends StatelessWidget {
  const ProfileMenuWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.onPress,
    this.endIcon = true,
    this.textColor
  });

  final String title;
  final IconData icon;
  final VoidCallback onPress;
  final bool endIcon;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
          onTap: onPress,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: AppColors.primaryColor,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(title, style: Theme
              .of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: textColor,
            fontFamily: 'DIN_Next_Rounded',
          )),
          trailing: endIcon ? Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.grey.withOpacity(0.1),
              ),
              child: const Icon(LineAwesomeIcons.angle_right_solid, size: 18.0,
                  color: Colors.grey)) : null
      ),
    );
  }
}