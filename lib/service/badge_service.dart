import 'dart:convert';
import 'package:app/model/badge.dart';
import 'package:app/model/user_badge.dart';
import 'api_cache_service.dart';

import '../global_var.dart';

class BadgeService {

  static Future<List<BadgeModel>> getBadgeListCourseByCourseId(int courseId) async {
    try {
      final response = await ApiCacheService.get(Uri.parse('${GlobalVar.baseUrl}/badge/course/$courseId'));
      final result = jsonDecode(response.body);

      return List<BadgeModel>.from(result.map((item) => BadgeModel.fromJson(item)));
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  static Future<List<UserBadge>> getUserBadgeListByUserId(
    int userId, {
    void Function(List<UserBadge> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user/$userId/badges');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) return;
          final freshResult = jsonDecode(freshResponse.body);
          final freshBadges = List<UserBadge>.from(
            freshResult.map((q) => UserBadge.fromJson(q)),
          );
          onRevalidated(freshBadges);
        },
      );
      final result = jsonDecode(response.body);
      return List<UserBadge>.from(result.map((q) => UserBadge.fromJson(q)));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<List<UserBadge>> getUserBadgeListWithStatusByUserId(
    int userId, {
    void Function(List<UserBadge> freshData)? onRevalidated,
  }) async {
    try {
      final uri = Uri.parse('${GlobalVar.baseUrl}/user/$userId/badges');
      final response = await ApiCacheService.getSWR(
        uri,
        onRevalidated: (freshResponse) {
          if (onRevalidated == null) return;
          final freshResult = jsonDecode(freshResponse.body);
          final freshBadges = List<UserBadge>.from(
            freshResult.map((q) => UserBadge.fromJson(q)),
          );
          onRevalidated(freshBadges);
        },
      );
      final result = jsonDecode(response.body);
      return List<UserBadge>.from(result.map((q) => UserBadge.fromJson(q)));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<void> createUserBadge(int userId, int badgeId) async{
      try {
        await ApiCacheService.post(Uri.parse('${GlobalVar.baseUrl}/userbadge'), body: {
          'userId': userId,
          'badgeId': badgeId
        });
      } catch(e){
        throw Exception(e.toString());
      }
  }

  static Future<void> createUserBadgeByChapterId(int userId, int badgeId) async{
    try {
      await ApiCacheService.post(Uri.parse('${GlobalVar.baseUrl}/userbadge'), body: {
        'userId': userId,
        'badgeId': badgeId
      });
    } catch(e){
      throw Exception(e.toString());
    }
  }

  static Future<void> updateUserBadgeStatus(int badgeId, bool status) async {
    try {
      await ApiCacheService.put(Uri.parse('${GlobalVar.baseUrl}/userbadge/$badgeId'), body: {
        'isPurchased': status,
      });
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
