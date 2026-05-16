import 'package:flutter/foundation.dart';

class ChatMessage {
  String? id;
  final ValueNotifier<String> contentNotifier;
  final bool isUser;

  ChatMessage({this.id, required String content, required this.isUser})
      : contentNotifier = ValueNotifier(content);
      
  String get content => contentNotifier.value;
  set content(String val) => contentNotifier.value = val;
  
  void dispose() {
    contentNotifier.dispose();
  }
}
