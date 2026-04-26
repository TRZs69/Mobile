class Student {
  final int id;
  String username;
  String password;
  String name;
  final String role;
  String? studentId;
  int? points;
  int? elo;
  String? eloTitle;
  int? totalCourses;
  int? badges;
  String? instructorId;
  int? instructorCourses;
  String? image;
  int? rank;
  final DateTime createdAt;
  final DateTime updatedAt;


  Student ({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    this.studentId,
    this.points,
    this.elo,
    this.eloTitle,
    this.totalCourses,
    this.badges,
    this.instructorId,
    this.instructorCourses,
    this.image,
    this.rank,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic v, [String fallback = '']) {
      if (v == null) return fallback;
      return v.toString();
    }

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

    return Student(
      id: safeInt(json['id']),
      username: safeString(json['username']),
      password: safeString(json['password']),
      name: safeString(json['name']),
      role: safeString(json['role']),
      studentId: json['studentId']?.toString(),
      points: json['points'] != null ? safeInt(json['points']) : null,
      elo: json['elo'] != null ? safeInt(json['elo']) : null,
      eloTitle: json['eloTitle']?.toString(),
      totalCourses: json['totalCourses'] != null ? safeInt(json['totalCourses']) : null,
      badges: json['badges'] != null ? safeInt(json['badges']) : null,
      instructorId: json['instructorId']?.toString(),
      instructorCourses: json['instructorCourses'] != null ? safeInt(json['instructorCourses']) : null,
      image: json['image']?.toString(),
      rank: json['rank'] != null ? safeInt(json['rank']) : null,
      createdAt: safeDate(json['createdAt']),
      updatedAt: safeDate(json['updatedAt']),
    );
  }
}