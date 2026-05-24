class LearningMaterial {
  final int id;
  final int chapterId;
  final String name;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningMaterial(
      {required this.id,
      required this.chapterId,
      required this.name,
      required this.content,
      required this.createdAt,
      required this.updatedAt});

  factory LearningMaterial.fromJson(Map<String, dynamic> json) {
    return LearningMaterial(
      id: json['id'],
      chapterId: json['chapterId'],
      name: json['name'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
