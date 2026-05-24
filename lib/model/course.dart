const url =
    'https://www.globalcareercounsellor.com/blog/wp-content/uploads/2018/05/Online-Career-Counselling-course.jpg';

class Course {
  final int id;
  final String codeCourse;
  final String courseName;
  final String image;
  String? description;
  int? progress = 0;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course(
      {required this.id,
      required this.codeCourse,
      required this.courseName,
      required this.image,
      this.description,
      this.progress,
      required this.createdAt,
      required this.updatedAt});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
        id: json['course']['id'],
        codeCourse: json['course']['code'],
        courseName: json['course']['name'],
        image: json['course']['image'] ?? '',
        description: json['course']['description'],
        createdAt: DateTime.parse(json['course']['createdAt']),
        updatedAt: DateTime.parse(json['course']['updatedAt']),
        progress: json['progress']);
  }

  int? getProgress() {
    return progress;
  }

  void setProgress(int progress) {
    this.progress = progress;
  }
}
