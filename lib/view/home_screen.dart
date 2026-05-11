import 'dart:async';

import 'package:app/model/user.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/course.dart';
import '../model/user_badge.dart';
import '../service/badge_service.dart';
import '../service/course_service.dart';
import '../service/user_service.dart';
import '../service/auth_service.dart';
import '../utils/colors.dart';
import 'chatbot_screen.dart';
import 'login_screen.dart';

import 'package:app/view/chatbot_response_rating.dart';
import 'package:app/view/widgets/custom_refresh_scroll.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) updateIndex;
  final VoidCallback onReplayTutorial;

  const HomeScreen({
    super.key,
    required this.updateIndex,
    required this.onReplayTutorial,
  });

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  static final Map<int, List<Course>> _enrolledCache = {};
  static final Map<int, Student> _userCache = {};

  List<Course> allCourses = [];
  double progress = 0.88;
  List<Student> list = [];
  String name = '';
  late SharedPreferences pref;
  Student? user;
  bool isLoading = true;
  Course? lastestCourse;
  int rank = 0;
  int idUser = 0;
  List<UserBadge>? userBadges = [];
  bool _isFetchingEnrolled = false;
  final GlobalKey _tutorialButtonKey = GlobalKey();

  Future<void> _showReplayTutorialPopup() async {
    final buttonContext = _tutorialButtonKey.currentContext;
    if (buttonContext == null) return;

    final buttonBox = buttonContext.findRenderObject() as RenderBox;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlayBox.size.width - bottomRight.dx,
        bottomRight.dy + 8,
        topLeft.dx,
        overlayBox.size.height - topLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ulangi tutorial?',
                  style: TextStyle(
                    fontFamily: 'DIN_Next_Rounded',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Lihat lagi panduan fitur utama LeveLearn dari awal.',
                  style: TextStyle(
                    fontFamily: 'DIN_Next_Rounded',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'start',
          child: Row(
            children: [
              Icon(Icons.replay_rounded, size: 18, color: AppColors.primaryColor),
              SizedBox(width: 8),
              Text(
                'Mulai ulang tutorial',
                style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'start' && mounted) {
      widget.onReplayTutorial();
    }
  }

  void _showInfoPopup() {
    showDialog(
      context: context,
      builder: (context) => const ChatbotResponseRating(),
    );
  }

  void _applyLatestSelectedCourseFromPrefs() {
    final idCourse = pref.getInt('lastestSelectedCourse') ?? 0;
    Course? selected;
    for (final c in allCourses) {
      if (c.id == idCourse) {
        selected = c;
        break;
      }
    }

    selected ??= allCourses.isEmpty
        ? null
        : (allCourses.toList()
              ..sort((a, b) => (b.progress ?? 0).compareTo(a.progress ?? 0)))
            .first;

    setState(() {
      lastestCourse = selected;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    pref = await SharedPreferences.getInstance();
    final storedIdUser = pref.getInt('userId');

    if (storedIdUser != null) {
      final cachedCourses = _enrolledCache[storedIdUser];
      final cachedUser = _userCache[storedIdUser];

      if (cachedCourses != null || cachedUser != null) {
        setState(() {
          idUser = storedIdUser;
          allCourses = cachedCourses != null ? List<Course>.from(cachedCourses) : allCourses;
          user = cachedUser ?? user;
          isLoading = false;
        });

        final idCourse = pref.getInt('lastestSelectedCourse') ?? 0;
        for (final c in allCourses) {
          if (c.id == idCourse) {
            lastestCourse = c;
            break;
          }
        }
      }
    }

    await getUserFromSharedPreference();
    unawaited(getEnrolledCourse());
    unawaited(getAllUser());
  }

  Future<void> getEnrolledCourse() async{
    if (_isFetchingEnrolled) {
      return;
    }

    _isFetchingEnrolled = true;
    pref = await SharedPreferences.getInstance();
    int? id = pref.getInt('userId');
    if(id != null) {
      try {
        final result = await CourseService.getEnrolledCourse(
          id,
          onRevalidated: (freshData) {
            if (!mounted) return;
            setState(() {
              allCourses = freshData;
              isLoading = false;
            });
            _enrolledCache[id] = List<Course>.from(freshData);
            _applyLatestSelectedCourseFromPrefs();
          },
        ).timeout(Duration(seconds: 10));
        if (!mounted) return;
        setState(() {
          allCourses = result;
          isLoading = false;
        });
        _enrolledCache[id] = List<Course>.from(result);
        _applyLatestSelectedCourseFromPrefs();
      } on TimeoutException catch (_) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Koneksi ke server terlalu lambat. Coba lagi nanti.')),
          );
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat course. Periksa koneksi internet Anda.')),
          );
        });
        print('Error getEnrolledCourse: $e');
      } finally {
        _isFetchingEnrolled = false;
      }
    } else {
      _isFetchingEnrolled = false;
    }
  }

  List<Student> sortUserByElo(List<Student> list) {
    final sorted = List<Student>.from(list);
    sorted.sort((a, b) => (b.elo ?? 0).compareTo(a.elo ?? 0));
    return sorted;
  }

  List<Student> studentRole(List<Student> list) {
    return list.where((user) => user.role == 'STUDENT').toList();
  }

  Future<void> getAllUser() async {
    try {
      final result = await UserService.getAllUser(
        onRevalidated: (freshData) {
          if (!mounted) return;
          final filtered = sortUserByElo(studentRole(freshData));
          setState(() {
            list = filtered;
          });
          for (int i = 0; i < list.length; i++) {
            if (list[i].id == idUser) {
              setState(() {
                rank = i + 1;
              });
              break;
            }
          }
        },
      ).timeout(Duration(seconds: 10));

      final filtered = sortUserByElo(studentRole(result));
      setState(() {
        list = filtered;
      });

      if (idUser == 0) return;

      for (int i = 0; i < list.length; i++) {
        if (list[i].id == idUser) {
          setState(() {
            rank = i + 1;
          });
          break;
        }
      }
    } on TimeoutException catch (_) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koneksi ke server terlalu lambat. Coba lagi nanti.')),
        );
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pengguna. Periksa koneksi internet Anda.')),
        );
      });
      print('Error getAllUser: $e');
    }
  }

  Future<void> getUserFromSharedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIdUser = prefs.getInt('userId');
    if (storedIdUser != null) {
      final fetchedUser = await UserService.getUserById(storedIdUser);
      if (!mounted) return;
      setState(() {
        idUser = storedIdUser;
        name = prefs.getString('name') ?? '';
        user = fetchedUser;
      });
      _userCache[storedIdUser] = fetchedUser;
      getUserBadges(storedIdUser);
    } else {
      logout();
    }
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

  void logout() async {
    await AuthService.logout();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("lib/assets/vectors/learn.png"),
              ),
            ),
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Mohon Tunggu",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'DIN_Next_Rounded'),
                    ),
                  ],
                ),
              ),
            ),
          )
          : allCourses.isEmpty && user == null
            ? Scaffold(
              body: Container(
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
                        Icon(LineAwesomeIcons.frown, size: 72, color: Colors.red),
                        SizedBox(height: 20),
                        Text(
                          'Gagal memuat data. Periksa koneksi internet Anda atau coba lagi nanti.',
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 16,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                });
                                getEnrolledCourse();
                                getAllUser();
                              },
                              child: Text('Coba Lagi', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: Colors.white)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                              onPressed: () {
                                logout();
                              },
                              child: Text('Log Out', style: TextStyle(fontFamily: 'DIN_Next_Rounded', color: AppColors.primaryColor)),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            : Scaffold(
              body: SingleChildScrollView(
                child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                            'lib/assets/pictures/background-pattern.png'
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: Column(
                          children: [
                            SizedBox(height: 30,),
                            _buildProfile(),
                            // _buildChatShortcut(),
                            _buildStats(),
                            _buildMyProgress(),
                            _buildMore(),
                            _buildTodayLeaderboard(),
                          ],
                        )
                    )
                ),
              )
            )
      ],
    );
  }

  Widget _buildTodayLeaderboard(){
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Papan Peringkat',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded'
                )),
            SizedBox(
              height: 16,
            ),
            Column(
              children: list.isNotEmpty ?
              List.generate(list.length > 3 ? 3 : list.length, (index) =>
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: (switch (index) {
                              0 => AssetImage('lib/assets/leaderboards/banner-gold-vertical.png'),
                              1 => AssetImage('lib/assets/leaderboards/banner-silver-vertical.png'),
                              2 => AssetImage('lib/assets/leaderboards/banner-bronze-vertical.png'),
                              _ => AssetImage('lib/assets/leaderboards/banner-silver.png'),
                            }),
                          fit: BoxFit.fitWidth,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Image.asset(
                          switch (index) {
                            0 => 'lib/assets/1st.png',
                            1 => 'lib/assets/2nd.png',
                            2 => 'lib/assets/3rd.png',
                            _ => ''
                          }
                          , height: 50, width: 50,),
                        title: Text(
                          list[index].name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'DIN_Next_Rounded',
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list[index].studentId ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.black, fontFamily: 'DIN_Next_Rounded'),
                            ),
                            Text(
                              list[index].eloTitle ?? 'Beginner',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, fontFamily: 'DIN_Next_Rounded'),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${list[index].elo ?? 0} ELO',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ),
                    ),
                  )
              )
              : [
                Center(
                  child: Text(
                      'Belum ada Pengguna',
                      style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded'
                      )),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyProgress() {
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: GestureDetector(
        onTap: () {
          widget.updateIndex(2);
        },
        child: Stack(
          children: [
            Positioned(
                top: 30,
                right: 30,
                width: 60,
                height: 60,
                child: Image.asset('lib/assets/check.png')
            ),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress Saya',
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DIN_Next_Rounded'
                        )),
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: lastestCourse == null
                        ? SizedBox(
                          height: 80,
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Center(
                              child: Text(
                                  'Akses Course untuk menampilkan Progress Bar!',
                                style: TextStyle(
                                  fontFamily: "DIN_Next_Rounded",
                                ),
                              ),
                            )],
                          ),
                        )
                        : Row(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                children: <Widget>[
                                  Center(
                                    child: SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 10,
                                        value: lastestCourse!.progress! / 100,
                                        strokeCap: StrokeCap.round,
                                        color: AppColors.primaryColor,
                                        backgroundColor: AppColors.accentColor,
                                      ),
                                    ),
                                  ),
                                  Center(child: Text('${lastestCourse!.progress!}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),)),
                                ],
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(left: 16),
                              width: (screenWidth / 9) * 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lastestCourse!.courseName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'DIN_Next_Rounded'
                                      )),
                                  Text('Sudah ${lastestCourse!.progress!}%! Lanjutkan Pengerjaan Course', style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'DIN_Next_Rounded'
                                  )),
                                ],
                              ),
                            )
                          ],
                        ),
                    ),
                    SizedBox(height: 8)
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    const title = 'Halo! Selamat Belajar';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.primaryColor,
                    fontFamily: 'DIN_Next_Rounded',
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.eloTitle ?? 'Beginner',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'DIN_Next_Rounded',
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              IconButton(
                key: _tutorialButtonKey,
                tooltip: 'Ulangi tutorial',
                onPressed: _showReplayTutorialPopup,
                icon: const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AppColors.primaryColor,
                ),
              ),
              IconButton(
                tooltip: 'Informasi',
                onPressed: _showInfoPopup,
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.updateIndex(4),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                  child: ClipOval(
                    child: user?.image != null && user?.image != ""
                        ? Image.network(
                      user!.image!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2,));
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
                    )
                        : Center(
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChatShortcut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotScreen(startFresh: false)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 6,
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 28, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Levely Chat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ngobrol dengan Levely untuk bantu jawab pertanyaanmu.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)
          ),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('lib/assets/pictures/dashboard.png'),
                  fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                            LineAwesomeIcons.medal_solid, 'Lencana', '${userBadges?.length ?? 0}', AppColors.accentColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoColumn(
                            LineAwesomeIcons.user_check_solid, 'Course', '${allCourses.isNotEmpty ? allCourses.length : 0}', AppColors.accentColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoColumn(
                            LineAwesomeIcons.trophy_solid, 'Peringkat', '$rank / ${list.length}', AppColors.accentColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              LineAwesomeIcons.gem_solid,
                              color: AppColors.accentColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Poin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                      color: Colors.white,
                                      fontFamily: 'DIN_Next_Rounded',
                                    ),
                                  ),
                                  Text("${user?.points ?? 0}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'DIN_Next_Rounded'))
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              LineAwesomeIcons.star_solid,
                              color: AppColors.accentColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rating ELO',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                      color: Colors.white,
                                      fontFamily: 'DIN_Next_Rounded',
                                    ),
                                  ),
                                  Text("${user?.elo ?? 0}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'DIN_Next_Rounded'))
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
      IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(
                  color: Colors.white,
                  fontFamily:
                  'DIN_Next_Rounded',
                ),
              ),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'DIN_Next_Rounded'))
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Jelajahi Course',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
                fontFamily: 'DIN_Next_Rounded',
              ),
            ),
          ),
          SizedBox(height: 16),
          allCourses.isEmpty
          ? SizedBox(
            height: 200,
            width: double.infinity,
            child: Center(
              child: Text(
                  'Kamu belum terdaftar pada course apapun',
                style: TextStyle(
                  fontFamily: "DIN_Next_Rounded",
                ),
              ),
            ),
          )
          : CarouselSlider.builder(
            itemCount: allCourses.length,
            itemBuilder: (context, index, realIndex) {
              final course = allCourses[index];
              return _courseCard(course);
            },
            options: CarouselOptions(
              height: 200,
              enlargeCenterPage: false,
              autoPlay: false,
              aspectRatio: 4 / 5,
              viewportFraction: 0.6,
              enableInfiniteScroll: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseCard(
      Course course
      ) {
    return GestureDetector(
      onTap: () async {
        unawaited(pref.setInt('lastestSelectedCourse', course.id));
        widget.updateIndex(2);
      },
      child: Container(
        width: MediaQuery.of(context).size.width *
            0.8,
        height: 200,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: course.image != ""
                    ? Image.network(
                        course.image,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'lib/assets/pictures/imk-picture.jpg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset('lib/assets/pictures/imk-picture.jpg', fit: BoxFit.cover),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DIN_Next_Rounded',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      course.description != null ? course.description! : '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'DIN_Next_Rounded',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  course.codeCourse,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DIN_Next_Rounded',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}