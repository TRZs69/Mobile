import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:app/global_var.dart';

class ChatSession {
  final String id;
  final String? title;
  final int? chapterId;

  ChatSession({required this.id, this.title, this.chapterId});

  static int? _parseChapterId(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      final parsed = value.toInt();
      return parsed > 0 ? parsed : null;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
      ? metadataRaw
      : <String, dynamic>{};

    return ChatSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      chapterId: _parseChapterId(metadata['chapterId']),
    );
  }

  ChatSession copyWith({
    String? id,
    String? title,
    int? chapterId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      chapterId: chapterId ?? this.chapterId,
    );
  }
}

class ChatSessionApi {
  static Future<List<ChatSession>> fetchSessions(int userId, {int? chapterId}) async {
    final params = <String, String>{
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    if (chapterId != null && chapterId > 0) {
      params['chapterId'] = chapterId.toString();
    }
    final url = Uri.parse('${GlobalVar.baseUrl}/chat/session/user/$userId').replace(queryParameters: params);
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];
      String bodyStr = response.body.trim();
      if (bodyStr.startsWith('\uFEFF')) bodyStr = bodyStr.substring(1).trim();
      if (bodyStr.isEmpty || !bodyStr.startsWith('{')) return [];
      try {
        final Map<String, dynamic> body = jsonDecode(bodyStr);
        final List<dynamic> data = body['sessions'] ?? [];
        final sessions = data.map((e) => ChatSession.fromJson(e)).toList();
        if (chapterId != null && chapterId > 0) {
          return sessions.where((session) => session.chapterId == chapterId).toList();
        }
        return sessions;
      } catch (e) {
        debugPrint('Error decoding sessions JSON: $e');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return [];
    }
  }

  static Future<ChatSession?> createSession(int userId, {int? chapterId}) async {
    final url = Uri.parse('${GlobalVar.baseUrl}/chat/session');
    final payload = <String, dynamic>{'userId': userId};
    if (chapterId != null && chapterId > 0) {
      payload['chapterId'] = chapterId;
    }
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      String bodyStr = response.body.trim();
      if (bodyStr.startsWith('\uFEFF')) bodyStr = bodyStr.substring(1).trim();
      if (bodyStr.isEmpty || !bodyStr.startsWith('{')) return null;
      try {
        final Map<String, dynamic> data = jsonDecode(bodyStr);
        final session = data['session'];
        if (session == null) return null;
        return ChatSession.fromJson(session);
      } catch (e) {
        debugPrint('Error decoding created session JSON: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating session: $e');
      return null;
    }
  }

  static Future<bool> renameSession(String sessionId, String newTitle) async {
    final url = Uri.parse('${GlobalVar.baseUrl}/chat/session/$sessionId');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': newTitle}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteSession(String sessionId) async {
    final url = Uri.parse('${GlobalVar.baseUrl}/chat/session/$sessionId');
    final response = await http.delete(url);
    return response.statusCode == 200;
  }

  static Uri getEditStreamUri() => Uri.parse('${GlobalVar.baseUrl}/chat/edit');
}
