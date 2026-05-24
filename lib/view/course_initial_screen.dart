import 'dart:convert';
import 'dart:async';

import 'package:app/service/badge_service.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/badge.dart';
import '../model/chapter.dart';
import '../model/course.dart';
import '../service/course_service.dart';

class CourseInitialScreen extends StatefulWidget {
  final int id;

  const CourseInitialScreen({super.key, required this.id});

  @override
  State<CourseInitialScreen> createState() => _CourseInitialScreenState();
}

class _CourseInitialScreenState extends State<CourseInitialScreen> {
  static final Map<int, Course> _courseCache = {};
  static final Map<int, List<Chapter>> _chapterCache = {};
  static final Map<int, List<BadgeModel>> _badgeCache = {};
  static final Map<int, DateTime> _courseFetchedAt = {};
  static final Map<int, DateTime> _chapterFetchedAt = {};
  static final Map<int, DateTime> _badgeFetchedAt = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  Course? courseDetail;
  int progress = 0;
  List<Chapter> listChapter = [];
  List<BadgeModel> listBadge = [];
  bool _isLoadingCourse = true;
  bool _isFetchingCourse = false;
  bool _isFetchingBadges = false;
  bool _isFetchingChapters = false;

  @override
  void initState() {
    super.initState();
    _hydrateInstantCache();
    _refreshIfNeeded();
    _primeCachesAndRefresh();
  }

  Future<void> _primeCachesAndRefresh() async {
    unawaited(_hydrateDiskCache());
    _refreshIfNeeded();
  }

  bool _isFresh(DateTime? fetchedAt) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < _cacheTtl;
  }

  void _refreshIfNeeded() {
    if (courseDetail == null || !_isFresh(_courseFetchedAt[widget.id])) {
      unawaited(getCourseDetail());
    }

    if (listBadge.isEmpty || !_isFresh(_badgeFetchedAt[widget.id])) {
      unawaited(getBadges());
    }

    if (listChapter.isEmpty || !_isFresh(_chapterFetchedAt[widget.id])) {
      unawaited(getChapters());
    }
  }

  void _hydrateInstantCache() {
    final cachedCourse = _courseCache[widget.id];
    final cachedChapters = _chapterCache[widget.id];
    final cachedBadges = _badgeCache[widget.id];

    if (cachedCourse != null) {
      courseDetail = cachedCourse;
      _isLoadingCourse = false;
    }

    if (cachedChapters != null) {
      listChapter = List<Chapter>.from(cachedChapters);
    }

    if (cachedBadges != null) {
      listBadge = List<BadgeModel>.from(cachedBadges);
    }
  }

  Future<void> _hydrateDiskCache() async {
    final prefs = await SharedPreferences.getInstance();
    final courseKey = 'course_initial_course_${widget.id}';
    final chaptersKey = 'course_initial_chapters_${widget.id}';
    final badgesKey = 'course_initial_badges_${widget.id}';

    bool changed = false;

    final courseJson = prefs.getString(courseKey);
    if (courseJson != null && courseDetail == null) {
      try {
        final decoded = jsonDecode(courseJson) as Map<String, dynamic>;
        courseDetail = Course(
          id: decoded['id'],
          codeCourse: decoded['codeCourse'],
          courseName: decoded['courseName'],
          image: decoded['image'] ?? '',
          description: decoded['description'],
          progress: decoded['progress'] ?? 0,
          createdAt: DateTime.parse(decoded['createdAt']),
          updatedAt: DateTime.parse(decoded['updatedAt']),
        );
        _courseCache[widget.id] = courseDetail!;
        changed = true;
      } catch (_) {}
    }

    final chaptersJson = prefs.getString(chaptersKey);
    if (chaptersJson != null && listChapter.isEmpty) {
      try {
        final decoded = jsonDecode(chaptersJson) as List<dynamic>;
        listChapter = decoded
            .map((item) => Chapter(
                  id: item['id'],
                  name: item['name'],
                  description: item['description'],
                  level: item['level'],
                  courseId: item['courseId'],
                  isCheckpoint: item['isCheckpoint'],
                  createdAt: DateTime.parse(item['createdAt']),
                  updatedAt: DateTime.parse(item['updatedAt']),
                ))
            .toList();
        _chapterCache[widget.id] = List<Chapter>.from(listChapter);
        changed = true;
      } catch (_) {}
    }

    final badgesJson = prefs.getString(badgesKey);
    if (badgesJson != null && listBadge.isEmpty) {
      try {
        final decoded = jsonDecode(badgesJson) as List<dynamic>;
        listBadge = decoded
            .map((item) => BadgeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _badgeCache[widget.id] = List<BadgeModel>.from(listBadge);
        changed = true;
      } catch (_) {}
    }

    if (!mounted) return;
    if (changed) {
      setState(() {
        _isLoadingCourse = courseDetail == null;
      });
    }
  }

  Future<void> getCourseDetail() async {
    if (_isFetchingCourse) {
      return;
    }

    _isFetchingCourse = true;
    try {
      final result = await CourseService.getCourse(widget.id);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        courseDetail = result;
        _courseCache[widget.id] = result;
        _courseFetchedAt[widget.id] = DateTime.now();
        _isLoadingCourse = false;
      });
      unawaited(prefs.setString(
        'course_initial_course_${widget.id}',
        jsonEncode({
          'id': result.id,
          'codeCourse': result.codeCourse,
          'courseName': result.courseName,
          'image': result.image,
          'description': result.description,
          'progress': result.progress ?? 0,
          'createdAt': result.createdAt.toIso8601String(),
          'updatedAt': result.updatedAt.toIso8601String(),
        }),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCourse = false;
      });
    } finally {
      _isFetchingCourse = false;
    }
  }

  Future<void> getBadges() async {
    if (_isFetchingBadges) {
      return;
    }

    _isFetchingBadges = true;
    try {
      final result = await BadgeService.getBadgeListCourseByCourseId(widget.id);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        listBadge = result;
        _badgeCache[widget.id] = List<BadgeModel>.from(result);
        _badgeFetchedAt[widget.id] = DateTime.now();
      });
      unawaited(prefs.setString(
        'course_initial_badges_${widget.id}',
        jsonEncode(
          result
              .map((b) => {
                    'id': b.id,
                    'name': b.name,
                    'type': b.type,
                    'image': b.image,
                    'courseId': b.courseId,
                    'chapterId': b.chapterId,
                  })
              .toList(),
        ),
      ));
    } catch (_) {
    } finally {
      _isFetchingBadges = false;
    }
  }

  Future<void> getChapters() async {
    if (_isFetchingChapters) {
      return;
    }

    _isFetchingChapters = true;
    try {
      final result = await CourseService.getChapterByCourse(widget.id);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        listChapter = result;
        _chapterCache[widget.id] = List<Chapter>.from(result);
        _chapterFetchedAt[widget.id] = DateTime.now();
      });
      unawaited(prefs.setString(
        'course_initial_chapters_${widget.id}',
        jsonEncode(
          result
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'description': c.description,
                    'level': c.level,
                    'courseId': c.courseId,
                    'isCheckpoint': c.isCheckpoint,
                    'createdAt': c.createdAt.toIso8601String(),
                    'updatedAt': c.updatedAt.toIso8601String(),
                  })
              .toList(),
        ),
      ));
    } catch (_) {
    } finally {
      _isFetchingChapters = false;
    }
  }

  Widget _badgeIcon(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return Image.asset('lib/assets/empty.png', width: 50, height: 50);
    }

    return Image.network(
      rawUrl,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
            child: CircularProgressIndicator(
          strokeWidth: 2,
        ));
      },
      errorBuilder: (_, __, ___) {
        return Image.asset('lib/assets/empty.png', width: 50, height: 50);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoadingCourse && courseDetail == null
        ? const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : courseDetail == null
            ? Scaffold(
                body: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'lib/assets/pictures/background-pattern.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Mulai Course untuk mengaktifkan halaman ini',
                            style: TextStyle(fontFamily: 'DIN_Next_Rounded'),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : Scaffold(
                appBar: AppBar(
                  centerTitle: true,
                  title: Text("Course Overview"),
                  backgroundColor: AppColors.primaryColor,
                  leading: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        LineAwesomeIcons.angle_left_solid,
                        color: Colors.white,
                      )),
                  titleTextStyle: TextStyle(
                      fontFamily: 'DIN_Next_Rounded',
                      fontSize: 24,
                      color: Colors.white),
                  iconTheme: IconThemeData(
                    color: Colors.white,
                  ),
                ),
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          Image.asset(
                            'lib/assets/pictures/imk-picture.jpg',
                            width: double.infinity,
                            height: 320,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  courseDetail!.courseName,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'DIN_Next_Rounded',
                                      color: AppColors.primaryColor),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Deskripsi',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'DIN_Next_Rounded',
                                      color: AppColors.primaryColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  courseDetail!.description ?? '-',
                                  style:
                                      TextStyle(fontFamily: 'DIN_Next_Rounded'),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Daftar Chapter',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'DIN_Next_Rounded',
                                      color: AppColors.primaryColor),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: listChapter.length,
                                  itemBuilder: (context, index) {
                                    return Card(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Colors.grey, width: 1.0),
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                      ),
                                      child: ListTile(
                                        minTileHeight: 72,
                                        leading: Text(
                                          '${index + 1}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontFamily: 'DIN_Next_Rounded',
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryColor),
                                        ),
                                        title: Text(listChapter[index].name,
                                            style: TextStyle(
                                                fontFamily:
                                                    'DIN_Next_Rounded')),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CourseDetailScreen(id: widget.id),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Kerjakan Course',
                                  style: TextStyle(
                                      fontFamily: 'DIN_Next_Rounded',
                                      color: Colors.white),
                                )),
                          ),
                        ))
                  ],
                ),
              );
  }
}
