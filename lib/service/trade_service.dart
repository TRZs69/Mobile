import 'dart:convert';

import 'package:app/global_var.dart';
import 'package:app/model/trade.dart';
import 'package:app/model/user_trade.dart';
import 'api_cache_service.dart';

class TradeService {
  static Future<List<TradeModel>> getAllTrades() async {
    try {
      final response =
          await ApiCacheService.get(Uri.parse('${GlobalVar.baseUrl}/trade'));
      final result = jsonDecode(response.body);

      return List<TradeModel>.from(
          result.map((item) => TradeModel.fromJson(item)));
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  static Future<void> createUserTrade(
      int userId, int tradeId, int badgeId) async {
    try {
      await ApiCacheService.post(Uri.parse('${GlobalVar.baseUrl}/usertrade'),
          body: {'userId': userId, 'tradeId': tradeId, 'badgeId': badgeId});
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<List<UserTrade>> getUserTrade(int userId) async {
    List<UserTrade> filteredUserTrade = [];
    try {
      final response = await ApiCacheService.get(
          Uri.parse('${GlobalVar.baseUrl}/usertrade'));
      final result = jsonDecode(response.body);

      List<UserTrade> trades = List<UserTrade>.from(
        result.map((item) => UserTrade.fromJson(item)),
      );
      for (UserTrade ut in trades) {
        if (ut.userId == userId) {
          filteredUserTrade.add(ut);
        }
      }
      return filteredUserTrade;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
