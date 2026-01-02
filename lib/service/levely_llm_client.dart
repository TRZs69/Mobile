import 'dart:convert';

import 'package:http/http.dart' as http;

class LevelyLlmClient {
  Future<String> complete({
    required String system,
    required String context,
    required List<({String role, String content})> messages,
  }) async {
    throw UnimplementedError();
  }
}

class OpenAiChatCompletionsClient extends LevelyLlmClient {
  final String apiKey;
  final String model;
  final String baseUrl;

  OpenAiChatCompletionsClient({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1/chat/completions',
  });

  @override
  Future<String> complete({
    required String system,
    required String context,
    required List<({String role, String content})> messages,
  }) async {
    final uri = Uri.parse(baseUrl);
    final payload = {
      'model': model,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'system', 'content': context},
        ...messages.map((m) => {'role': m.role, 'content': m.content}),
      ],
    };

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('LLM error ${res.statusCode}: ${res.body}');
    }

    final json = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final choices = (json['choices'] as List).cast<dynamic>();
    final msg = (choices.first as Map).cast<String, dynamic>()['message'] as Map;
    return (msg['content'] as String?)?.trim() ?? '';
  }
}
