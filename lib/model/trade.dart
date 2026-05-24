class TradeModel {
  final int id;
  final String title;
  final String image;
  final String description;
  final String requiredBadgeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool hasTrade = false;

  TradeModel({
    required this.id,
    required this.title,
    required this.image,
    required this.description,
    required this.requiredBadgeType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TradeModel.fromJson(Map<String, dynamic> json) {
    return TradeModel(
        id: json['id'],
        title: json['title'],
        image: json['image'],
        description: json['description'],
        requiredBadgeType: json['requiredBadgeType'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']));
  }
}
