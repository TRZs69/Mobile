class UserTrade {
  final int id;
  final int userId;
  final int tradeId;

  UserTrade({
    required this.id,
    required this.userId,
    required this.tradeId,
  });

  factory UserTrade.fromJson(Map<String, dynamic> json) {
    return UserTrade(
      id: json['id'],
      userId: json['userId'],
      tradeId: json['tradeId'],
    );
  }
}
