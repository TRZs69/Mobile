class UserCourse {
  int id;
  int userId;
  int courseId;
  int progress;
  int currentChapter;
  bool isCompleted;
  DateTime enrolledAt;
  int elo;

  UserCourse({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.progress,
    required this.currentChapter,
    required this.isCompleted,
    required this.enrolledAt,
    this.elo = 750,
  });

  factory UserCourse.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    DateTime safeDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return UserCourse(
      id: safeInt(json['id']),
      userId: safeInt(json['userId']),
      courseId: safeInt(json['courseId']),
      progress: safeInt(json['progress']),
      currentChapter: safeInt(json['currentChapter'], 1),
      isCompleted: json['isCompleted'] == true,
      enrolledAt: safeDate(json['enrolledAt']),
      elo: safeInt(json['elo'], 750),
    );
  }
}
