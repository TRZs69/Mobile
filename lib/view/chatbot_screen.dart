import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:fetch_client/fetch_client.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:cronet_http/cronet_http.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:app/global_var.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/chat_session_api.dart';

class ChatMessage {
  String? id;
  final ValueNotifier<String> contentNotifier;
  final bool isUser;

  ChatMessage({this.id, required String content, required this.isUser})
      : contentNotifier = ValueNotifier(content);
      
  String get content => contentNotifier.value;
  set content(String val) => contentNotifier.value = val;
}

class ChatbotScreen extends StatefulWidget {
  final bool startFresh;
  final bool inheritSession;
  final int? materialId;
  final int? chapterId;
  const ChatbotScreen({
    super.key,
    this.startFresh = false,
    this.inheritSession = false,
    this.materialId,
    this.chapterId,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _sessionPrefsKeyPrefix = 'levely_chat_session_id';
  static const _fallbackAssistantReply = 'Maaf, aku belum bisa menjawab.';
  static const List<String> _thinkingPlaceholders = [
    '🤔 Konsultasi dulu sama sel otak...',
    '🤔 Mikir keras nih (atau setidaknya pura-pura)...',
    '🤔 Lagi ngerakit kata-kata biar berguna...',
    '🤔 Lagi tak saring pakai filter jenius...',
    '⚡ Siap, meluncur kayak roket!',
    '⚡ Ngolah data secepat kilat!',
    '⚡ Neuron lagi pada kerja, standby ya...',
    '⚡ Kecepatan penuh, jangan berkedip!',
    '😄 Lagi ngajarin monyet ngetik jawabanmu...',
    '😄 Lagi Googling... eh bercanda, lagi mikir kok!',
    '😄 Lagi nyogok sel otak biar jawabannya oke...',
    '😄 Lagi debat sama diri sendiri demi kamu...',
    '😄 Lagi ngurai benang kusut di kepala nih...',
    '🌌 Menyelam ke samudra pengetahuan...',
    '🌌 Menjelajahi palung ilmu...',
    '🌌 Menembus kabut data...',
    '🌌 Menghubungkan titik-titik kosmik...',
    '🤖 Inisialisasi protokol berpikir...',
    '🤖 Menjalankan subrutin kecerdasan...',
    '🤖 Mengakses matriks pengetahuan...',
    '🤖 Menyusun jawaban dari angka 1 dan 0...',
    '🤖 Overclock mesin penjawab...',
    '🎲 Bangunin hamster di roda putar dulu...',
    '🎲 Tanya alam semesta dulu, bentar...',
    '🎲 Memanggil kebijaksanaan dari kehampaan...',
    '🎲 Menginterogasi data sampai dia ngaku...',
  ];

  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  final TextEditingController _controller = TextEditingController();

  bool _isSending = false;
  bool _isLoadingHistory = false;
  bool _isLoadingSessions = false;
  int? _userId;
  String? _sessionId;
  int? _activeStreamIndex;
  bool _streamHasProducedContent = false;
  final Random _random = Random();
  String? _currentPlaceholder;
  List<ChatSession> _sessions = [];
  Timer? _placeholderTimer;

  String get _sessionPrefsKey {
    final chapterId = widget.chapterId;
    return chapterId != null && chapterId > 0 ? '${_sessionPrefsKeyPrefix}_$chapterId' : _sessionPrefsKeyPrefix;
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _restoreSession();
    await _fetchSessions();
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _controller.dispose();
    for (var msg in _messages) {
      msg.contentNotifier.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt('userId');
    if (!mounted) return;
    setState(() => _userId = storedUserId);

    if (widget.startFresh) {
      setState(() { _sessionId = null; _messages.clear(); _history.clear(); });
      return;
    }

    final storedSessionId = prefs.getString(_sessionPrefsKey);
    if (!mounted) return;
    setState(() {
      _sessionId = (storedSessionId != null && storedSessionId.isNotEmpty) ? storedSessionId : null;
    });
 
    if (widget.inheritSession) return;
    if (storedSessionId != null && storedSessionId.isNotEmpty) {
      await _fetchHistory(storedSessionId);
    } else if (storedUserId != null) {
      await _fetchHistoryByUser(storedUserId);
    }
  }

  Future<void> _fetchHistory(String sessionId) async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      final response = await http.get(Uri.parse('${GlobalVar.baseUrl}/chat/history/$sessionId'));
      if (response.statusCode != 200) {
        if (response.statusCode == 400 || response.statusCode == 404) await _clearPersistedSession();
        return;
      }
      String bodyStr = response.body.trim();
      if (bodyStr.startsWith('\uFEFF')) bodyStr = bodyStr.substring(1).trim();
      if (bodyStr.isEmpty || !bodyStr.startsWith('{')) return;
      try {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        await _applyHistoryResponse(body, fallbackSessionId: sessionId);
      } catch (e) {
        debugPrint('Error decoding history JSON: $e');
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _fetchHistoryByUser(int userId) async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      final response = await http.get(
        Uri.parse('${GlobalVar.baseUrl}/chat/history/user/$userId').replace(
          queryParameters: { if (widget.chapterId != null && widget.chapterId! > 0) 'chapterId': widget.chapterId.toString() },
        ),
      );
      if (response.statusCode != 200) return;
      String bodyStr = response.body.trim();
      // Strip UTF-8 BOM if present
      if (bodyStr.startsWith('\uFEFF')) bodyStr = bodyStr.substring(1);
      if (bodyStr.isEmpty) return;
      try {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        await _applyHistoryResponse(body);
      } catch (e) {
        debugPrint('Error decoding user history JSON: $e | body: $bodyStr');
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _applyHistoryResponse(Map<String, dynamic> body, {String? fallbackSessionId}) async {
    final rawSession = body['sessionId'];
    final sessionCandidate = rawSession != null ? rawSession.toString().trim() : (fallbackSessionId ?? '').trim();
    final payload = body['messages'] as List<dynamic>? ?? [];
    
    final loadedMessages = payload.map((raw) {
      final map = (raw as Map<String, dynamic>? ?? {});
      final content = (map['content'] ?? '').toString().trim();
      final id = map['id']?.toString();
      if (content.isEmpty) return null;
      return ChatMessage(id: id, content: content, isUser: (map['role'] ?? 'user') == 'user');
    }).whereType<ChatMessage>().toList();

    if (!mounted) return;
    setState(() {
      _messages..clear()..addAll(loadedMessages);
      _syncHistoryFromMessages(_messages);
    });
    await _persistSessionId(sessionCandidate);
  }

  Future<void> _persistSessionId(String? value, {bool skipFetch = false}) async {
    final next = value?.trim();
    if (next == null || next.isEmpty || next.toLowerCase() == 'null' || next == _sessionId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, next);
    if (!mounted) return;
    setState(() {
      _sessionId = next;
      if (skipFetch && !_sessions.any((s) => s.id == next)) {
        _sessions.insert(0, ChatSession(id: next, title: ''));
      }
    });
    if (!skipFetch) await _fetchSessions();
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
    if (!mounted) return;
    setState(() { _sessionId = null; _history.clear(); });
  }

  void _addToHistory({required bool isUser, required String content}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _history.add({'role': isUser ? 'user' : 'assistant', 'content': trimmed});
    if (_history.length > 20) _history.removeRange(0, _history.length - 20);
  }

  void _syncHistoryFromMessages(List<ChatMessage> messages) {
    _history..clear()..addAll(messages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content}));
    if (_history.length > 20) _history.removeRange(0, _history.length - 20);
  }

  void _startPlaceholderCycling(int index) {
    _placeholderTimer?.cancel();
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isSending || _streamHasProducedContent || _activeStreamIndex != index) {
        timer.cancel();
        return;
      }
      // Pick a different one each time
      final currentText = _messages[index].content;
      String nextText = _thinkingPlaceholders[_random.nextInt(_thinkingPlaceholders.length)];
      while (nextText == currentText) {
        nextText = _thinkingPlaceholders[_random.nextInt(_thinkingPlaceholders.length)];
      }
      
      _currentPlaceholder = nextText;
      _messages[index].content = nextText;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    late final int assistantIndex;
    final placeholder = _thinkingPlaceholders[_random.nextInt(_thinkingPlaceholders.length)];

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _addToHistory(isUser: true, content: text);
      _controller.clear();
      _isSending = true;
      _messages.add(ChatMessage(content: placeholder, isUser: false));
      assistantIndex = _messages.length - 1;
      _activeStreamIndex = assistantIndex;
      _streamHasProducedContent = false;
      _currentPlaceholder = placeholder;
    });

    _startPlaceholderCycling(assistantIndex);

    try {
      final reply = await _streamAssistantReply(prompt: text, assistantIndex: assistantIndex);
      if (!mounted) return;

      final finalReply = reply.trim().isEmpty ? _fallbackAssistantReply : reply.trim();
      
      // Note: assistantIndex is already synced in _streamAssistantReply via _updateAssistantMessage
      // and IDs are synced via _persistMessageIds
      
      setState(() {
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _isSending = false;
        _placeholderTimer?.cancel();
      });
      _fetchSessions();
    } catch (error) {
      if (!mounted) return;
      String errMsg = error is _PartialStreamResult ? (error.partial.isEmpty ? _fallbackAssistantReply : error.partial) : 'Error: $error';
      
      if (assistantIndex >= 0 && assistantIndex < _messages.length) {
        _messages[assistantIndex].content = errMsg;
      }
      
      setState(() {
        _isSending = false;
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _placeholderTimer?.cancel();
      });
    }
  }

  Future<String> _streamAssistantReply({required String prompt, required int assistantIndex}) async {
    final body = {
      'message': prompt,
      'history': _history,
      'sessionId': _sessionId,
      'userId': _userId,
      if (widget.materialId != null) 'materialId': widget.materialId,
      if (widget.chapterId != null) 'chapterId': widget.chapterId,
    };

    String replyBuffer = '';
    final streamUri = Uri.parse('${GlobalVar.baseUrl}/chat/stream');
    
    http.Client client;
    if (kIsWeb) {
      client = FetchClient(mode: RequestMode.cors);
    } else if (Platform.isIOS || Platform.isMacOS) {
      client = CupertinoClient.defaultSessionConfiguration();
    } else if (Platform.isAndroid) {
      client = CronetClient.defaultCronetEngine();
    } else {
      client = http.Client();
    }
    
    try {
      final request = http.Request('POST', streamUri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(body);

      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('Server error: ${response.statusCode}');

      final rawStream = response.stream.transform(utf8.decoder);
      String sseBuffer = '';

      await for (final chunk in rawStream) {
        sseBuffer += chunk;
        while (sseBuffer.contains('\n')) {
          int newlineIndex = sseBuffer.indexOf('\n');
          String line = sseBuffer.substring(0, newlineIndex).trim();
          sseBuffer = sseBuffer.substring(newlineIndex + 1);

          if (line.startsWith('data:')) {
            String dataStr = line.substring(5).trim();
            if (dataStr.startsWith('\uFEFF')) dataStr = dataStr.substring(1).trim();
            if (dataStr.isEmpty) continue;
            if (dataStr == '[DONE]') break;

            final startIdx = dataStr.indexOf('{');
            final endIdx = dataStr.lastIndexOf('}');
            if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
              dataStr = dataStr.substring(startIdx, endIdx + 1);
            } else {
              continue;
            }

            try {
              final payload = jsonDecode(dataStr) as Map<String, dynamic>;
              if (payload['error'] != null) throw Exception(payload['error']);
              final sessionValue = payload['sessionId']?.toString();
              if (sessionValue != null && sessionValue.isNotEmpty) _persistSessionId(sessionValue, skipFetch: true);

              final delta = payload['delta']?.toString();
              if (delta != null && delta.isNotEmpty) {
                replyBuffer += delta;
                _updateAssistantMessage(assistantIndex, replyBuffer);
                // CRITICAL: Dart buffers HTTP/2 responses. We force a highly visible 40ms typewriter delay 
                // so even if chunks arrive all at once at the end, it still visually streams for the user.
                await Future.delayed(const Duration(milliseconds: 40));
              }

              final replyValue = payload['reply']?.toString();
              if (replyValue != null && replyValue.isNotEmpty) {
                replyBuffer = replyValue;
                _updateAssistantMessage(assistantIndex, replyBuffer);
              }

              if (payload['userMessageId'] != null || payload['assistantMessageId'] != null) {
                _persistMessageIds(
                  userIndex: assistantIndex - 1,
                  assistantIndex: assistantIndex,
                  userId: payload['userMessageId']?.toString(),
                  assistantId: payload['assistantMessageId']?.toString(),
                );
              }

              if (payload['titleDelta'] != null) _updateSessionTitleStream(payload['titleDelta']);
              if (payload['title'] != null) _updateSessionTitleFinal(payload['title']);
            } catch (e) {
              debugPrint('Error parsing stream SSE data: $e | data: $dataStr');
            }
          }
        }
      }
      return replyBuffer;
    } finally { client.close(); }
  }

  void _persistMessageIds({required int userIndex, required int assistantIndex, String? userId, String? assistantId}) {
    if (!mounted) return;
    setState(() {
      if (userIndex >= 0 && userIndex < _messages.length && userId != null) {
        _messages[userIndex] = ChatMessage(id: userId, content: _messages[userIndex].content, isUser: true);
      }
      if (assistantIndex >= 0 && assistantIndex < _messages.length && assistantId != null) {
        _messages[assistantIndex] = ChatMessage(id: assistantId, content: _messages[assistantIndex].content, isUser: false);
      }
    });
  }

  void _updateAssistantMessage(int index, String content) {
    if (!mounted || index < 0 || index >= _messages.length) return;
    
    // Check if we need to hide the loading/placeholder state
    if (_activeStreamIndex == index && content.isNotEmpty && !_thinkingPlaceholders.contains(content)) {
      if (!_streamHasProducedContent) {
        setState(() {
          _streamHasProducedContent = true;
          _placeholderTimer?.cancel();
        });
      }
    }
    
    // Targeted update via Notifier (No setState here for performance!)
    _messages[index].content = content;
  }

  void _updateSessionTitleStream(String delta) {
    if (!mounted || _sessionId == null) return;
    setState(() {
      final i = _sessions.indexWhere((s) => s.id == _sessionId);
      if (i != -1 && i < _sessions.length) {
        _sessions[i] = _sessions[i].copyWith(title: (_sessions[i].title ?? '') + delta);
      }
    });
  }

  void _updateSessionTitleFinal(String title) {
    if (!mounted || _sessionId == null) return;
    setState(() {
      final i = _sessions.indexWhere((s) => s.id == _sessionId);
      if (i != -1 && i < _sessions.length) {
        _sessions[i] = _sessions[i].copyWith(title: title);
      }
    });
  }

  Future<void> _fetchSessions() async {
    if (_userId == null) return;
    setState(() => _isLoadingSessions = true);
    final sessions = await ChatSessionApi.fetchSessions(_userId!, chapterId: widget.chapterId);
    if (!mounted) return;
    setState(() { _sessions = sessions; _isLoadingSessions = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: AppColors.appBarIconColor),
        title: const Text('Levely', style: TextStyle(color: AppColors.appBarIconColor)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_isLoadingHistory) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _messages.isEmpty
              ? (_isLoadingHistory ? const Center(child: CircularProgressIndicator()) : _buildEmptyState())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  if (index >= _messages.length) return const SizedBox.shrink();
                  final msg = _messages[index];
                  return _ChatBubble(
                    message: msg,
                    isStreaming: index == _activeStreamIndex,
                    showIndicator: index == _activeStreamIndex && !_streamHasProducedContent,
                    onEdit: (msg.isUser && msg.id != null && !_isSending) ? () => _showEditDialog(index) : null,
                  );
                },
              ),
          ),
          _buildInputArea(),
        ],
      ),
      drawer: _buildDrawer(),
    );
  }

  void _showEditDialog(int index) {
    final msg = _messages[index];
    final editController = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Pesan'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: 'Edit pesanmu...'),
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != msg.content) {
                  Navigator.pop(context);
                  _editAndRegenerate(index, newText);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan & Ulang'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editAndRegenerate(int index, String newText) async {
    if (_sessionId == null || _isSending) return;
    final msg = _messages[index];
    if (msg.id == null) return;

    late final int assistantIndex;
    final placeholder = _thinkingPlaceholders[_random.nextInt(_thinkingPlaceholders.length)];

    setState(() {
      _isSending = true;
      // 1. Remove all messages after this one in the local UI
      if (index + 1 < _messages.length) {
        _messages.removeRange(index + 1, _messages.length);
      }
      // 2. Update the message content
      _messages[index].content = newText;
      _syncHistoryFromMessages(_messages);

      // 3. Add placeholder for new response
      _messages.add(ChatMessage(content: placeholder, isUser: false));
      assistantIndex = _messages.length - 1;
      _activeStreamIndex = assistantIndex;
      _streamHasProducedContent = false;
      _currentPlaceholder = placeholder;
    });

    _startPlaceholderCycling(assistantIndex);

    try {
      final reply = await _streamEditAssistantReply(
        messageId: msg.id!,
        newMessage: newText,
        assistantIndex: assistantIndex,
        userIndex: index,
      );
      
      if (!mounted) return;

      setState(() {
        _isSending = false;
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _placeholderTimer?.cancel();
      });
      _fetchSessions();
    } catch (e) {
      if (!mounted) return;
      if (assistantIndex >= 0 && assistantIndex < _messages.length) {
        _messages[assistantIndex].content = 'Error: $e';
      }
      setState(() {
        _isSending = false;
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _placeholderTimer?.cancel();
      });
    }
  }

  Future<String> _streamEditAssistantReply({
    required String messageId,
    required String newMessage,
    required int assistantIndex,
    required int userIndex,
  }) async {
    final body = {
      'messageId': messageId,
      'newMessage': newMessage,
      'sessionId': _sessionId,
      'userId': _userId,
      if (widget.materialId != null) 'materialId': widget.materialId,
      if (widget.chapterId != null) 'chapterId': widget.chapterId,
    };

    String replyBuffer = '';
    final streamUri = ChatSessionApi.getEditStreamUri();
    
    http.Client client;
    if (kIsWeb) {
      client = FetchClient(mode: RequestMode.cors);
    } else if (Platform.isIOS || Platform.isMacOS) {
      client = CupertinoClient.defaultSessionConfiguration();
    } else if (Platform.isAndroid) {
      client = CronetClient.defaultCronetEngine();
    } else {
      client = http.Client();
    }
    
    try {
      final request = http.Request('POST', streamUri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(body);

      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('Server error: ${response.statusCode}');

      final rawStream = response.stream.transform(utf8.decoder);
      String sseBuffer = '';

      await for (final chunk in rawStream) {
        sseBuffer += chunk;
        while (sseBuffer.contains('\n')) {
          int newlineIndex = sseBuffer.indexOf('\n');
          String line = sseBuffer.substring(0, newlineIndex).trim();
          sseBuffer = sseBuffer.substring(newlineIndex + 1);

          if (line.startsWith('data:')) {
            String dataStr = line.substring(5).trim();
            if (dataStr.startsWith('\uFEFF')) dataStr = dataStr.substring(1).trim();
            if (dataStr.isEmpty) continue;
            if (dataStr == '[DONE]') break;

            // Aggressive JSON extraction
            final startIdx = dataStr.indexOf('{');
            final endIdx = dataStr.lastIndexOf('}');
            if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
              dataStr = dataStr.substring(startIdx, endIdx + 1);
            }

            try {
              final payload = jsonDecode(dataStr) as Map<String, dynamic>;
              if (payload['error'] != null) throw Exception(payload['error']);

              final delta = payload['delta']?.toString();
              if (delta != null && delta.isNotEmpty) {
                replyBuffer += delta;
                _updateAssistantMessage(assistantIndex, replyBuffer);
                await Future.delayed(const Duration(milliseconds: 40));
              }

              final replyValue = payload['reply']?.toString();
              if (replyValue != null && replyValue.isNotEmpty) {
                replyBuffer = replyValue;
                _updateAssistantMessage(assistantIndex, replyBuffer);
              }

              if (payload['userMessageId'] != null || payload['assistantMessageId'] != null) {
                _persistMessageIds(
                  userIndex: userIndex,
                  assistantIndex: assistantIndex,
                  userId: payload['userMessageId']?.toString(),
                  assistantId: payload['assistantMessageId']?.toString(),
                );
              }
            } catch (e) {
              debugPrint('Error parsing SSE data in edit stream: $e | data: $dataStr');
            }
          }
        }
      }
      return replyBuffer;
    } finally { client.close(); }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSelectSession(ChatSession session) async {
    if (_isSending || _isLoadingHistory) return;
    await _persistSessionId(session.id);
    await _fetchHistory(session.id);
    setState(() {});
  }

  void _showSessionOptions(ChatSession session) {
    if (_isSending || _isLoadingHistory) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Ubah Nama'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSession(session);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(ChatSession session) {
    final titleController = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Nama Sesi'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: 'Nama baru...'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  Navigator.pop(context);
                  final success = await ChatSessionApi.renameSession(session.id, newTitle);
                  if (success) {
                    _fetchSessions();
                    _showSnack('Berhasil mengubah nama sesi');
                  } else {
                    _showSnack('Gagal mengubah nama sesi');
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSession(ChatSession session) {
    if (_isSending || _isLoadingHistory) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Chat?'),
          content: const Text('Riwayat chat ini akan dihapus permanen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ChatSessionApi.deleteSession(session.id);
                if (success) {
                  if (session.id == _sessionId) {
                    setState(() { _sessionId = null; _messages.clear(); _history.clear(); });
                  }
                  _fetchSessions();
                  _showSnack('Sesi chat dihapus');
                } else {
                  _showSnack('Gagal menghapus sesi');
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoadingHistory,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(hintText: 'Tanya apa saja...', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: (_isSending || _isLoadingHistory) ? null : _sendMessage,
            icon: _isSending 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send, color: AppColors.primaryColor),
          )
        ],
      ),
    ),
  );

  Widget _buildDrawer() => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Chat Baru'),
            enabled: !_isSending && !_isLoadingHistory,
            onTap: () {
              setState(() { _sessionId = null; _messages.clear(); _history.clear(); });
              Navigator.pop(context);
            },
          ),
          const Divider(),
          if (_isLoadingSessions) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                if (i >= _sessions.length) return const SizedBox.shrink();
                return ListTile(
                  title: Text(_sessions[i].title ?? 'Chat Baru'),
                  selected: _sessions[i].id == _sessionId,
                  onTap: () { Navigator.pop(context); _onSelectSession(_sessions[i]); },
                  onLongPress: () => _showSessionOptions(_sessions[i]),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => Container(
    decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('lib/assets/pictures/background-pattern.png'), fit: BoxFit.cover)),
    child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 64, color: Colors.black45), SizedBox(height: 16), Text('Mulai ngobrol dengan Levely!')])),
  );
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final bool showIndicator;
  final VoidCallback? onEdit;
  const _ChatBubble({required this.message, required this.isStreaming, required this.showIndicator, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return GestureDetector(
      onLongPress: onEdit,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primaryColor : AppColors.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: message.contentNotifier,
                builder: (context, content, _) {
                  return isUser 
                    ? Text(content, style: const TextStyle(color: Colors.white, fontFamily: 'DIN_Next_Rounded', height: 1.4))
                    : (isStreaming 
                        ? Text(content, style: const TextStyle(color: Colors.black87, fontFamily: 'DIN_Next_Rounded', height: 1.4))
                        : MarkdownBody(
                            data: content,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: Colors.black87, fontFamily: 'DIN_Next_Rounded', height: 1.4),
                              code: const TextStyle(backgroundColor: Colors.black12, fontFamily: 'monospace'),
                            ),
                          ));
                }
              ),
              if (showIndicator) const Padding(padding: EdgeInsets.only(top: 6), child: _TypingIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final dots = 1 + ((_controller.value * 3).floor() % 3);
        return Text(List.filled(dots, '•').join(' '), style: const TextStyle(fontSize: 14, color: Colors.black54, letterSpacing: 2));
      },
    );
  }
}

class _PartialStreamResult implements Exception {
  final String partial;
  const _PartialStreamResult(this.partial);
}
