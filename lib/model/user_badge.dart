import 'package:app/model/badge.dart';

class UserBadge {
  final int id;
  final int userId;
  final int badgeId;
  bool isPurchased;
  BadgeModel badge;

  UserBadge(
      {required this.id,
      required this.userId,
      required this.badgeId,
      required this.isPurchased,
      required this.badge});

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
        id: json['id'],
        userId: json['userId'],
        badgeId: json['badgeId'],
        isPurchased: json['isPurchased'],
        badge: BadgeModel.fromJson(json['badge']));
  }

  bool getIsPurchased() {
    return isPurchased;
  }
}
