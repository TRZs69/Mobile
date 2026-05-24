class Assignment {
  final int id;
  final int chapterId;
  final String instruction;
  String? fileUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment(
      {required this.id,
      required this.chapterId,
      required this.instruction,
      this.fileUrl,
      required this.updatedAt,
      required this.createdAt});

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      chapterId: json['chapterId'],
      instruction: json['instruction'],
      fileUrl: json['fileUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
