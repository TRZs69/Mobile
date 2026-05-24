import "package:flutter/foundation.dart";
import 'package:app/model/user_badge.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../global_var.dart';

class UserBadgeService {
  static Future<UserBadge> updateUserBadgeStatus(
      int userBadgeId, bool status) async {
    try {
      Map<String, dynamic> request = {
        "isPurchased": status,
      };
      final response = await http.put(
          Uri.parse('${GlobalVar.baseUrl}/userbadge/$userBadgeId'),
          headers: {
            'Content-type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(request));

      final body = response.body;
      debugPrint(body);
      final result = jsonDecode(body);
      debugPrint(result);
      UserBadge userbadge = UserBadge.fromJson(result['UserBadge']);
      return userbadge;
    } catch (e) {
      debugPrint(e.toString());
      throw Exception(e.toString());
    }
  }
}
