import 'dart:async';

import 'package:app/model/chapter.dart';
import 'package:app/model/chapter_status.dart';
import 'package:app/service/api_cache_service.dart';
import 'package:app/service/badge_service.dart';
import 'package:app/service/chapter_service.dart';
import 'package:app/service/course_service.dart';
import 'package:app/service/user_chapter_service.dart';
import 'package:app/service/user_course_service.dart';
import 'package:app/service/user_service.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/model/badge.dart';
import 'package:app/model/course.dart';
import 'package:app/model/user.dart';
import 'package:app/model/user_course.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/chapter_screen.dart';
import 'package:app/view/widgets/custom_refresh_scroll.dart';

class CourseDetailScreen extends StatefulWidget {
  final int id;
  final int refreshNonce;

  const CourseDetailScreen({
    super.key,
    required this.id,
    this.refreshNonce = 0,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetail();
}

class _CourseDetail extends State<CourseDetailScreen> {
  static const String _selectedCourseKey = 'lastestSelectedCourse';
  static const String _selectedCourseAltKey = 'latestSelectedCourse';
  static const String _selectedCourseLegacyKey = 'getCourseDetail';

  static final Map<int, Course> _courseCache = {};
  static final Map<int, List<BadgeModel>> _badgeCache = {};
  static final Map<String, List<Chapter>> _chapterCache = {};
  static final Map<String, UserCourse> _userCourseCache = {};

  Course? courseDetail;
  List<Chapter> listChapter = [];
  late SharedPreferences pref;
  int idCourse = 0;
  int idUser = 0;
  bool isLoading = true;
  UserCourse? uc;
  Student? user;
  List<BadgeModel>? listBadge;
  bool _isBootstrapped = false;
  bool _isFetchingCourse = false;
  bool _isFetchingBadges = false;
  bool _isFetchingChapters = false;
  bool _isFetchingUserCourse = false;
  bool _isSyncingUserCourse = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(covariant CourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.id != oldWidget.id || widget.refreshNonce != oldWidget.refreshNonce) {
      unawaited(_refreshForCurrentSelection());
    }
  }

  String _chapterCacheKey() {
    return '${idUser}_${idCourse}';
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapped) {
      return;
    }
    _isBootstrapped = true;

    pref = await SharedPreferences.getInstance();
    idCourse = await _resolveSelectedCourseId();
    idUser = pref.getInt('userId') ?? 0;

    if (idCourse != 0) {
      unawaited(pref.setInt(_selectedCourseKey, idCourse));
      unawaited(pref.setInt(_selectedCourseAltKey, idCourse));
      unawaited(pref.setInt(_selectedCourseLegacyKey, idCourse));
    }

    _hydrateInstantCache();

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = listChapter.isEmpty;
    });

    if (idUser != 0) {
      unawaited(getUser(idUser));
      unawaited(getUserCourse());
    }

    if (idCourse != 0) {
      unawaited(getCourseDetail());
      unawaited(getChapter(idCourse));
      unawaited(getListBadge(idCourse));
    }
  }

  Future<void> _refreshForCurrentSelection() async {
    if (!_isBootstrapped) {
      return;
    }

    final resolvedCourseId = await _resolveSelectedCourseId();
    if (!mounted) return;

    if (resolvedCourseId != 0 && resolvedCourseId != idCourse) {
      setState(() {
        idCourse = resolvedCourseId;
        courseDetail = null;
        listChapter = [];
        listBadge = null;
        uc = null;
        isLoading = true;
      });
    }

    if (idCourse == 0) {
      return;
    }

    unawaited(getUserCourse());
    unawaited(getCourseDetail());
    unawaited(getChapter(idCourse));
    unawaited(getListBadge(idCourse));
  }

  Future<int> _resolveSelectedCourseId() async {
    final prefsInstance = pref;
    if (widget.id != 0) {
      return widget.id;
    }

    int persistedId = prefsInstance.getInt(_selectedCourseKey) ??
        prefsInstance.getInt(_selectedCourseAltKey) ??
        prefsInstance.getInt(_selectedCourseLegacyKey) ??
        0;

    if (persistedId != 0) {
      return persistedId;
    }

    final userId = prefsInstance.getInt('userId') ?? 0;
    if (userId == 0) {
      return 0;
    }

    try {
      final enrolled = await CourseService.getEnrolledCourse(userId);
      if (enrolled.isEmpty) {
        return 0;
      }

      final preferred = enrolled.firstWhere(
        (course) => (course.progress ?? 0) > 0,
        orElse: () => enrolled.first,
      );
      persistedId = preferred.id;
      unawaited(prefsInstance.setInt(_selectedCourseKey, persistedId));
      unawaited(prefsInstance.setInt(_selectedCourseAltKey, persistedId));
      unawaited(prefsInstance.setInt(_selectedCourseLegacyKey, persistedId));
      return persistedId;
    } catch (_) {
      return 0;
    }
  }

  void _hydrateInstantCache() {
    final cachedCourse = _courseCache[idCourse];
    final cachedBadges = _badgeCache[idCourse];
    final cachedChapters = _chapterCache[_chapterCacheKey()];
    final cachedUc = _userCourseCache[_chapterCacheKey()];

    if (cachedCourse != null) {
      courseDetail = cachedCourse;
    }
    if (cachedBadges != null) {
      listBadge = List<BadgeModel>.from(cachedBadges);
    }
    if (cachedChapters != null) {
      listChapter = List<Chapter>.from(cachedChapters);
      isLoading = false;
    }
    if (cachedUc != null) {
      uc = cachedUc;
    }
  }

  Future<void> updateStatus(index) async {
    final chapter = listChapter[index];
    final status = chapter.status!;

    if (status.id <= 0) {
      final persistedStatus =
        await UserChapterService.getChapterStatus(idUser, chapter.id);
      status.id = persistedStatus.id;
      status.userId = persistedStatus.userId;
      status.chapterId = persistedStatus.chapterId;
      status.createdAt = persistedStatus.createdAt;
      status.updatedAt = persistedStatus.updatedAt;
    }

    final result = await UserChapterService.updateChapterStatus(
      status.id, status);
    setState(() {
      listChapter[index].status = result;
    });
  }

  Future<void> getUser(int id) async {
    user = await UserService.getUserById(id);
  }

  Future<void> getCourseDetail() async {
    if (_isFetchingCourse || idCourse == 0) {
      return;
    }

    _isFetchingCourse = true;
    try {
      final result = await CourseService.getCourse(
        idCourse,
        onRevalidated: (freshData) {
          if (!mounted || freshData.id != idCourse) return;
          setState(() {
            courseDetail = freshData;
          });
          _courseCache[idCourse] = freshData;
        },
      );
      if (!mounted) return;
      setState(() {
        courseDetail = result;
      });
      _courseCache[idCourse] = result;
    } finally {
      _isFetchingCourse = false;
    }
  }

  Future<void> getUserCourse() async {
    if (_isFetchingUserCourse || idUser == 0 || idCourse == 0) {
      return;
    }

    _isFetchingUserCourse = true;
    try {
      final fetched = await UserCourseService.getUserCourse(
        idUser,
        idCourse,
        onRevalidated: (freshData) {
          if (!mounted || freshData.courseId != idCourse) return;
          setState(() {
            uc = freshData;
          });
          _userCourseCache[_chapterCacheKey()] = freshData;
          unawaited(_syncCourseProgressFromChapters());
        },
      );
      if (!mounted) return;
      setState(() {
        uc = fetched;
      });
      _userCourseCache[_chapterCacheKey()] = fetched;
      unawaited(_syncCourseProgressFromChapters());
    } finally {
      _isFetchingUserCourse = false;
    }
  }

  void updateUserCourse() async {
    await UserCourseService.updateUserCourse(uc!.id, uc!);
  }

  Future<void> getChapter(int id) async {
    if (_isFetchingChapters) {
      return;
    }

    _isFetchingChapters = true;
    if (listChapter.isEmpty && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      List<Chapter> result;

      if (idUser != 0) {
        try {
          result = await CourseService.getChapterByCourseForUser(id, idUser);
        } catch (_) {
          final fallback = await CourseService.getChapterByCourse(id);
          result = await getStatusChapter(fallback);
        }
      } else {
        result = await CourseService.getChapterByCourse(id);
      }

      final updatedList = _ensureChapterStatuses(result);
      if (!mounted) return;
      setState(() {
        listChapter = updatedList;
        isLoading = false;
      });
      _chapterCache[_chapterCacheKey()] = List<Chapter>.from(updatedList);
      unawaited(_syncCourseProgressFromChapters());
    } finally {
      _isFetchingChapters = false;
    }
  }

  Future<void> _syncCourseProgressFromChapters() async {
    if (_isSyncingUserCourse || uc == null || listChapter.isEmpty) {
      return;
    }

    _isSyncingUserCourse = true;
    try {
      final sorted = List<Chapter>.from(listChapter)
        ..sort((a, b) => a.level.compareTo(b.level));

      int completedContiguous = 0;
      for (final chapter in sorted) {
        final st = chapter.status;
        final done = (st?.materialDone ?? false) && (st?.assessmentDone ?? false);
        if (!done) {
          break;
        }
        completedContiguous++;
      }

      final total = sorted.length;
      final desiredCurrentChapter = (completedContiguous + 1).clamp(1, total + 1);
      final desiredProgress = ((completedContiguous / total) * 100).toInt();

      if (uc!.currentChapter == desiredCurrentChapter && uc!.progress == desiredProgress) {
        return;
      }

      uc!.currentChapter = desiredCurrentChapter;
      uc!.progress = desiredProgress;

      if (mounted) {
        setState(() {});
      }

      _userCourseCache[_chapterCacheKey()] = uc!;
      await UserCourseService.updateUserCourse(uc!.id, uc!);
    } finally {
      _isSyncingUserCourse = false;
    }
  }

  Future<void> getListBadge(int courseId) async {
    if (_isFetchingBadges) {
      return;
    }

    _isFetchingBadges = true;
    try {
      final badges = await BadgeService.getBadgeListCourseByCourseId(courseId);
      if (!mounted) return;
      setState(() {
        listBadge = badges;
      });
      _badgeCache[courseId] = List<BadgeModel>.from(badges);
    } finally {
      _isFetchingBadges = false;
    }
  }

  Future<List<Chapter>> getStatusChapter(List<Chapter> list) async {
    if (idUser == 0) {
      return _ensureChapterStatuses(list);
    }

    final statuses = await Future.wait(
      list.map((chapter) => UserChapterService.getChapterStatus(idUser, chapter.id)),
    );

    for (int i = 0; i < list.length; i++) {
      list[i].status = statuses[i];
    }

    return list;
  }

  List<Chapter> _ensureChapterStatuses(List<Chapter> chapters) {
    return chapters.map((chapter) {
      chapter.status ??= _buildDefaultChapterStatus(chapter.id);
      return chapter;
    }).toList();
  }

  ChapterStatus _buildDefaultChapterStatus(int chapterId) {
    final now = DateTime.now();
    return ChapterStatus(
      id: 0,
      userId: idUser,
      chapterId: chapterId,
      isCompleted: false,
      isStarted: false,
      materialDone: false,
      assessmentDone: false,
      assignmentDone: false,
      assessmentAnswer: const [],
      assessmentGrade: 0,
      assessmentEloDelta: 0,
      submission: '',
      timeStarted: now,
      timeFinished: now,
      assignmentScore: 0,
      assignmentFeedback: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  int idOfBadge(int isCheckpoint) {
    int idbadge = 0;
    switch (isCheckpoint) {
      case 1:
        {
          for (BadgeModel i in listBadge!) {
            if (i.type == 'BEGINNER') {
              idbadge = i.id;
            }
          }
        }
      case 2:
        {
          for (BadgeModel i in listBadge!) {
            if (i.type == 'INTERMEDIATE') {
              idbadge = i.id;
            }
          }
        }
      case 3:
        {
          for (BadgeModel i in listBadge!) {
            if (i.type == 'ADVANCE') {
              idbadge = i.id;
            }
          }
        }
      default:
        idbadge = 0;
    }
    return idbadge;
  }

  @override
  Widget build(BuildContext context) {
    return _buildDetailCourse();
  }

  Widget _buildDetailCourse() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            image: DecorationImage(
                image: AssetImage("lib/assets/learnbg.png"),
                fit: BoxFit.cover,
                opacity: 0.7),
          ),
        ),
        idCourse != 0 && courseDetail != null
            ? Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  leading: Navigator.canPop(context)
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        )
                      : null,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Level',
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
                      const SizedBox(height: 4),
                      Text(
                        courseDetail!.courseName,
                        style: TextStyle(
                            fontSize: 12, fontFamily: 'DIN_Next_Rounded'),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primaryColor,
                  titleTextStyle: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      fontSize: 24,
                      color: Colors.white),
                  iconTheme: IconThemeData(
                    color: Colors.white,
                  ),
                ),
                body: isLoading
                    ? SizedBox(
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
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'DIN_Next_Rounded'),
                              ),
                            ],
                          ),
                        ))
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          itemCount: listChapter.length + 1,
                          itemBuilder: (context, count) {
                            if (count == 0) {
                              return _buildCourseCover();
                            }

                            final chapterIndex = count - 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                              child: chapterIndex <= (uc?.currentChapter ?? 0) - 1
                                  ? _buildCourseItem(chapterIndex)
                                  : _buildCourseItemLocked(chapterIndex),
                            );
                          },
                        ),
                      ),
              )
            : Scaffold(
                backgroundColor: Colors.transparent,
                body: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage(
                              'lib/assets/pictures/background-pattern.png'),
                          fit: BoxFit.cover)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'lib/assets/pixels/lock-pixel.png',
                          height: 50,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          'Belum ada Course yang dikerjakan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'DIN_Next_Rounded',
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor),
                        ),
                        Text(
                          'Akses course terlebih dahulu untuk mengaktifkan halaman ini!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                        ),
                      ],
                    )),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildCourseCover() {
    final hasRemoteImage = (courseDetail?.image ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: hasRemoteImage
                  ? Image.network(
                      courseDetail!.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'lib/assets/pictures/icon.png',
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      'lib/assets/pictures/icon.png',
                      fit: BoxFit.cover,
                    ),
            ),
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      courseDetail?.codeCourse ?? 'COURSE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontFamily: 'DIN_Next_Rounded',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    courseDetail?.courseName ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    courseDetail?.description?.isNotEmpty == true
                        ? courseDetail!.description!
                        : 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'DIN_Next_Rounded',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseItem(int index) {
    final chapter = listChapter[index];

    return Padding(
      padding: index == listChapter.length - 1
          ? EdgeInsets.only(top: 32, bottom: 16)
          : EdgeInsets.only(top: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: AppColors.primaryColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                ChapterService.warmupAssessmentAttempt(chapter.id, user!.id)
                    .catchError((_) {
                  // Best effort warmup only.
                });

                uc?.currentChapter = uc!.currentChapter < chapter.level
                    ? chapter.level
                    : uc!.currentChapter;
                updateUserCourse();
                if (!chapter.status!.isStarted) {
                  chapter.status?.timeStarted = DateTime.now();
                  chapter.status?.isStarted = true;
                }
                updateStatus(index);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Chapterscreen(
                      status: chapter.status!,
                      chapterIndexInList: index,
                      uc: uc!,
                      chLength: listChapter.length,
                      user: user!,
                      chapterName: listChapter[index].name,
                      idBadge: idOfBadge(listChapter[index].isCheckpoint),
                      level: listChapter[index].level,
                    ),
                  ),
                );

                if (result != null) {
                  final returnedIndex = result['index'] as int?;
                  final returnedStatus = result['status'];
                  if (returnedIndex != null && returnedStatus != null) {
                    setState(() {
                      listChapter[returnedIndex].status =
                          ChapterStatus.fromJson(returnedStatus as Map<String, dynamic>);
                    });
                  }

                  if (idCourse != 0) {
                    await ApiCacheService.clearCacheContaining('chapter');
                    await ApiCacheService.clearCacheContaining('userchapter');
                  }
                  unawaited(getChapter(idCourse));
                  unawaited(getUserCourse());
                }

              },
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 16, left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    SizedBox(height: 48), // Space for the floating badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatusIcon(
                            chapter.status!.materialDone, Icons.menu_book),
                        SizedBox(width: 10),
                        _buildStatusIcon(
                            chapter.status!.assessmentDone, Icons.task),
                        SizedBox(width: 10),
                        _buildStatusIcon(
                            chapter.status!.assignmentDone, Icons.file_copy),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      chapter.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                          fontFamily: 'DIN_Next_Rounded'),
                    ),
                    SizedBox(height: 4),
                    Text(
                      chapter.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontFamily: 'DIN_Next_Rounded'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          listChapter[index].isCheckpoint == 1
              ? Positioned(
                  top: 32,
                  right: 32,
                  child: Icon(LineAwesomeIcons.medal_solid,
                      size: 50,
                      color: chapter.status!.materialDone &&
                              chapter.status!.assessmentDone
                          ? Colors.tealAccent
                          : Colors.white54))
              : listChapter[index].isCheckpoint == 2
                  ? Positioned(
                      top: 32, // Offset to be outside the card
                      right: 32,
                      child: Icon(LineAwesomeIcons.medal_solid,
                          size: 50,
                          color: chapter.status!.materialDone &&
                                  chapter.status!.assessmentDone
                              ? Colors.blueAccent
                              : Colors.white54))
                  : listChapter[index].isCheckpoint == 3
                      ? Positioned(
                          top: 32,
                          right: 32,
                          child: Icon(LineAwesomeIcons.medal_solid,
                              size: 50,
                              color: chapter.status!.materialDone &&
                                      chapter.status!.assessmentDone
                                  ? Colors.redAccent
                                  : Colors.white54))
                      : SizedBox(),
          Positioned(
            top: -25,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade900,
                      spreadRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${chapter.level}',
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          fontFamily: 'Modak',
                          shadows: [
                            Shadow(
                              color: Colors.green.shade900
                                  .withOpacity(0.7),
                              blurRadius: 0,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItemLocked(int index) {
    final chapter = listChapter[index];

    return Padding(
      padding: index == listChapter.length - 1
          ? EdgeInsets.only(top: 32, bottom: 16)
          : EdgeInsets.only(top: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: AppColors.lightGrey,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 16, left: 16, right: 16, bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 40,
                      ),
                      Icon(Icons.lock, size: 50, color: AppColors.darkGrey),
                      SizedBox(height: 10),
                      Text(
                        "Selesaikan dahulu level sebelumnya!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            color: AppColors.darkGrey,
                            fontFamily: 'DIN_Next_Rounded'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: -25,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade900.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: Offset(
                          0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${chapter.level}',
                    style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontFamily: 'Modak',
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isDone, IconData icon) {
    return Icon(
      icon,
      size: 24,
      color: isDone ? Colors.yellow : Colors.white54,
    );
  }
}
