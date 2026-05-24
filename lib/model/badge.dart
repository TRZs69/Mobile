class BadgeModel {
  final int id;
  final String name;
  final String type;
  final String? image;
  final int courseId;
  final int chapterId;

  BadgeModel({
    required this.id,
    required this.name,
    required this.type,
    this.image,
    required this.courseId,
    required this.chapterId,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      image: json['image'],
      courseId: json['courseId'],
      chapterId: json['chapterId'],
    );
  }
}
