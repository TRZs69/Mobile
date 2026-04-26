import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/global_var.dart';
import 'package:app/utils/colors.dart';
import 'package:app/view/chat_session_api.dart';

class ChatMessage {
  final String content;
  final bool isUser;

  ChatMessage({required this.content, required this.isUser});
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
    'Levely lagi mikir sebentar…',
    'Sebentar ya, aku susun jawabannya dulu.',
    'Tunggu bentar, aku lagi nyari contoh terbaik.',
    'Give me a sec, lagi loading ide.',
    'Hmm... biar aku mikir dikit biar jawabannya mantap.',
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

  String get _sessionPrefsKey {
    final chapterId = widget.chapterId;
    if (chapterId != null && chapterId > 0) {
      return '${_sessionPrefsKeyPrefix}_$chapterId';
    }
    return _sessionPrefsKeyPrefix;
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt('userId');

    if (!mounted) {
      return;
    }

    setState(() {
      _userId = storedUserId;
    });

    if (widget.startFresh) {
      setState(() {
        _sessionId = null;
        _messages.clear();
        _history.clear();
      });
      return;
    }

    final storedSessionId = prefs.getString(_sessionPrefsKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionId = (storedSessionId != null && storedSessionId.isNotEmpty)
        ? storedSessionId
        : null;
    });
 
    if (widget.inheritSession) {
      return;
    }

    if (storedSessionId != null && storedSessionId.isNotEmpty) {
      await _fetchHistory(storedSessionId);
    } else if (storedUserId != null) {
      await _fetchHistoryByUser(storedUserId);
    }
  }

  Future<void> _fetchHistory(String sessionId) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await http
        .get(Uri.parse('${GlobalVar.baseUrl}/chat/history/$sessionId'));

      if (response.statusCode != 200) {
        if (response.statusCode == 400 || response.statusCode == 404) {
          await _clearPersistedSession();
        }
        _showSnack('Gagal memuat riwayat chat (${response.statusCode})');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await _applyHistoryResponse(body, fallbackSessionId: sessionId);
    } catch (error) {
      _showSnack('Gagal memuat riwayat chat');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _fetchHistoryByUser(int userId) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await http
        .get(
          Uri.parse('${GlobalVar.baseUrl}/chat/history/user/$userId').replace(
            queryParameters: {
              if (widget.chapterId != null && widget.chapterId! > 0)
                'chapterId': widget.chapterId.toString(),
            },
          ),
        );

      if (response.statusCode != 200) {
        _showSnack('Gagal memuat riwayat chat (${response.statusCode})');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await _applyHistoryResponse(body);
    } catch (error) {
      _showSnack('Gagal memuat riwayat chat');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _applyHistoryResponse(Map<String, dynamic> body,
    {String? fallbackSessionId}) async {
    final rawSession = body['sessionId'];
    final sessionCandidate = rawSession != null
      ? rawSession.toString().trim()
      : (fallbackSessionId ?? '').trim();
    final payload = body['messages'] as List<dynamic>? ?? [];
    final loadedMessages = _mapPayloadToMessages(payload);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages
        ..clear()
        ..addAll(loadedMessages);
      _syncHistoryFromMessages(_messages);
    });

    await _persistSessionId(sessionCandidate);
  }

  Future<void> _persistSessionId(String? value, {bool skipFetch = false}) async {
    final next = value?.trim();
    if (next == null || next.isEmpty || next.toLowerCase() == 'null' || next == _sessionId) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, next);

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionId = next;
      if (skipFetch && !_sessions.any((s) => s.id == next)) {
        _sessions.insert(0, ChatSession(id: next, title: ''));
      }
    });

    if (!skipFetch) {
      await _fetchSessions();
    }
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionId = null;
      _history.clear();
    });
  }

  void _addToHistory({required bool isUser, required String content}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _history.add({'role': isUser ? 'user' : 'assistant', 'content': trimmed});
    if (_history.length > 20) {
      _history.removeRange(0, _history.length - 20);
    }
  }

  void _syncHistoryFromMessages(List<ChatMessage> messages) {
    _history
      ..clear()
      ..addAll(messages.map((message) => {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.content,
        }));
    if (_history.length > 20) {
      _history.removeRange(0, _history.length - 20);
    }
  }

  List<ChatMessage> _mapPayloadToMessages(List<dynamic> payload) {
    return payload
      .map((raw) {
        final map = (raw as Map<String, dynamic>? ?? {});
        final content = (map['content'] ?? '').toString().trim();
        if (content.isEmpty) {
          return null;
        }
        final role = (map['role'] ?? 'user').toString();
        return ChatMessage(content: content, isUser: role == 'user');
      })
      .whereType<ChatMessage>()
      .toList();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    late final int assistantIndex;

    final placeholder = _pickThinkingPlaceholder();

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

    try {
      final reply = await _streamAssistantReply(
        prompt: text,
        assistantIndex: assistantIndex,
      );

      if (!mounted) return;

      final normalizedReply = reply.trim().isEmpty
        ? _fallbackAssistantReply
        : reply.trim();

      setState(() {
        _messages[assistantIndex] =
          ChatMessage(content: normalizedReply, isUser: false);
        _addToHistory(isUser: false, content: normalizedReply);
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _currentPlaceholder = null;
      });
    } on _PartialStreamResult catch (result) {
      // Koneksi putus tapi sudah ada sebagian konten — tampilkan apa yang ada
      if (!mounted) return;
      final partial = result.partial.trim();
      final finalReply = partial.isNotEmpty ? partial : _fallbackAssistantReply;
      setState(() {
        _messages[assistantIndex] = ChatMessage(content: finalReply, isUser: false);
        _addToHistory(isUser: false, content: finalReply);
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _currentPlaceholder = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = 'Terjadi kesalahan: ${error.toString()}';
      setState(() {
        _messages[assistantIndex] = ChatMessage(content: message, isUser: false);
        _activeStreamIndex = null;
        _streamHasProducedContent = false;
        _currentPlaceholder = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          if (_activeStreamIndex == assistantIndex) {
            _activeStreamIndex = null;
            _currentPlaceholder = null;
          }
        });
      }
      if (_sessionId != null) {
        _fetchSessions();
      }
    }
  }

  Future<String> _streamAssistantReply({
    required String prompt,
    required int assistantIndex,
  }) async {
    final body = jsonEncode({
      'message': prompt,
      'history': _history,
      'sessionId': _sessionId,
      'userId': _userId,
      if (widget.materialId != null) 'materialId': widget.materialId,
      if (widget.chapterId != null) 'chapterId': widget.chapterId,
    });

    final client = http.Client();
    String replyBuffer = '';

    try {
      final streamUri = Uri.parse('${GlobalVar.baseUrl}/chat/stream');
      final request = http.Request('POST', streamUri)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Gagal menghubungi server (${response.statusCode})');
      }

      final contentType = response.headers['content-type'] ?? '';

      // Jika server kirim response biasa (bukan SSE)
      if (!contentType.toLowerCase().contains('text/event-stream')) {
        final bodyText = await response.stream.bytesToString();
        if (bodyText.isEmpty) return '';
        final parsed = jsonDecode(bodyText) as Map<String, dynamic>;
        final reply = (parsed['reply'] ?? '').toString();
        final sessionValue = parsed['sessionId']?.toString();
        if (sessionValue != null && sessionValue.isNotEmpty) {
          await _persistSessionId(sessionValue, skipFetch: true);
        }
        return reply;
      }

      final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

      try {
        await for (final rawLine in lineStream) {
          final trimmedLine = rawLine.trim();
          if (trimmedLine.isEmpty || !trimmedLine.startsWith('data:')) continue;
          final dataPayload = trimmedLine.substring(5).trim();
          if (dataPayload.isEmpty) continue;
          if (dataPayload == '[DONE]') break;

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(dataPayload) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          final errorPayload = payload['error'];
          if (errorPayload != null) throw Exception(errorPayload.toString());

          final titleDelta = payload['titleDelta']?.toString();
          if (titleDelta != null && titleDelta.isNotEmpty) _updateSessionTitleStream(titleDelta);

          final titleValue = payload['title']?.toString();
          if (titleValue != null && titleValue.isNotEmpty) _updateSessionTitleFinal(titleValue);

          final delta = payload['delta']?.toString();
          if (delta != null && delta.isNotEmpty) {
            replyBuffer += delta;
            _updateAssistantMessage(assistantIndex, replyBuffer);
          }

          final replyValue = payload['reply']?.toString();
          if (replyValue != null && replyValue.isNotEmpty) {
            replyBuffer = replyValue;
            _updateAssistantMessage(assistantIndex, replyBuffer);
          }

          final sessionValue = payload['sessionId']?.toString();
          if (sessionValue != null && sessionValue.isNotEmpty) {
            await _persistSessionId(sessionValue, skipFetch: true);
          }
        }
      } on Exception catch (e) {
        final errMsg = e.toString();
        final isConnectionClosed = errMsg.contains('Connection closed') ||
            errMsg.contains('ClientException') ||
            errMsg.contains('SocketException') ||
            errMsg.contains('Connection reset');

        if (isConnectionClosed) {
          if (replyBuffer.trim().isNotEmpty) {
            throw _PartialStreamResult(replyBuffer);
          }
          return await _fallbackNonStream(prompt: prompt, bodyJson: body);
        }
        rethrow;
      }

      return replyBuffer;
    } on _PartialStreamResult {
      rethrow;
    } on Exception catch (e) {
      final errMsg = e.toString();
      final isConnectionClosed = errMsg.contains('Connection closed') ||
          errMsg.contains('ClientException') ||
          errMsg.contains('SocketException') ||
          errMsg.contains('Connection reset');

      if (isConnectionClosed) {
        if (replyBuffer.trim().isNotEmpty) {
          throw _PartialStreamResult(replyBuffer);
        }
        // Fallback ke non-stream
        return await _fallbackNonStream(prompt: prompt, bodyJson: body);
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Fallback endpoint non-stream: POST /chat (bukan /chat/stream)
  /// Digunakan saat stream SSE gagal sebelum menghasilkan konten apapun.
  Future<String> _fallbackNonStream({
    required String prompt,
    required String bodyJson,
  }) async {
    try {
      final nonStreamUri = Uri.parse('${GlobalVar.baseUrl}/chat');
      final response = await http.post(
        nonStreamUri,
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = (parsed['reply'] ?? '').toString();
        final sessionValue = parsed['sessionId']?.toString();
        if (sessionValue != null && sessionValue.isNotEmpty) {
          await _persistSessionId(sessionValue, skipFetch: true);
        }
        return reply;
      }
    } catch (_) {
      // Jika fallback juga gagal, biarkan jatuh ke pesan error default
    }
    return _fallbackAssistantReply;
  }

  void _updateAssistantMessage(int index, String content) {
    if (!mounted || index < 0 || index >= _messages.length) {
      return;
    }

    setState(() {
      final trimmed = content.trim();
      if (_activeStreamIndex == index &&
          trimmed.isNotEmpty &&
          trimmed != (_currentPlaceholder ?? '')) {
        _streamHasProducedContent = true;
      }
      _messages[index] = ChatMessage(content: content, isUser: false);
    });
  }

  void _updateSessionTitleStream(String delta) {
    if (!mounted || _sessionId == null) return;
    setState(() {
      final index = _sessions.indexWhere((s) => s.id == _sessionId);
      if (index != -1) {
        final currentTitle = _sessions[index].title ?? '';
        _sessions[index] = _sessions[index].copyWith(title: currentTitle + delta);
      } else {
        _sessions.insert(0, ChatSession(id: _sessionId!, title: delta));
      }
    });
  }

  void _updateSessionTitleFinal(String title) {
    if (!mounted || _sessionId == null) return;
    setState(() {
      final index = _sessions.indexWhere((s) => s.id == _sessionId);
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(title: title);
      } else {
        _sessions.insert(0, ChatSession(id: _sessionId!, title: title));
      }
    });
  }

  String _pickThinkingPlaceholder() {
    if (_thinkingPlaceholders.isEmpty) {
      return 'Levely lagi mikir sebentar…';
    }
    final index = _random.nextInt(_thinkingPlaceholders.length);
    return _thinkingPlaceholders[index];
  }

  Future<void> _fetchSessions() async {
    if (_userId == null) return;
    setState(() => _isLoadingSessions = true);
    final sessions = await ChatSessionApi.fetchSessions(_userId!, chapterId: widget.chapterId);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoadingSessions = false;
    });
  }

  Future<void> _createNewSession() async {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _history.clear();
    });
    Navigator.pop(context); // Close the drawer
  }

  void _onSelectSession(ChatSession session) async {
    await _persistSessionId(session.id);
    await _fetchHistory(session.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: AppColors.appBarIconColor),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.appBarIconColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Levely Chat', style: TextStyle(color: AppColors.appBarIconColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.appBarIconColor),
            tooltip: 'Refresh Sessions',
            onPressed: _fetchSessions,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingHistory)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _messages.isEmpty
              ? (_isLoadingHistory ? _buildLoadingState() : _buildEmptyState())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final alignment = message.isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start;
                  final bubbleColor = message.isUser
                    ? AppColors.primaryColor
                    : AppColors.accentColor.withOpacity(0.15);
                  final textColor =
                    message.isUser ? Colors.white : Colors.black87;
                  return Column(
                    crossAxisAlignment: alignment,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: message.isUser
                              ? const Radius.circular(16)
                              : const Radius.circular(0),
                            bottomRight: message.isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: message.isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                          children: [
                            message.isUser
                              ? Text(
                                message.content,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: textColor,
                                  fontFamily: 'DIN_Next_Rounded',
                                  height: 1.4,
                                ),
                              )
                              : _FormattedMessage(
                                text: message.content,
                                color: textColor,
                              ),
                            if (!message.isUser &&
                                index == _activeStreamIndex &&
                                !_streamHasProducedContent)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: _TypingIndicator(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Tanya apa saja...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                      : const Icon(Icons.send),
                    label: const Text('Kirim'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.drawerItemColor),
                title: const Text('Chat Baru', style: TextStyle(color: AppColors.drawerItemColor, fontWeight: FontWeight.bold)),
                onTap: _createNewSession,
              ),
              const Divider(),
              if (_isLoadingSessions)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoadingSessions && _sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada sesi chat.'),
                ),
              if (!_isLoadingSessions)
                Expanded(
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isActive = session.id == _sessionId;
                      return ListTile(
                        title: Text(session.title?.isNotEmpty == true ? session.title! : 'Chat Baru'),
                        selected: isActive,
                        onTap: () {
                          Navigator.of(context).pop();
                          _onSelectSession(session);
                        },
                        onLongPress: () => _showSessionOptions(session),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionOptions(ChatSession session) {
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Chat?'),
          content: const Text('Riwayat chat ini akan dihapus permanen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ChatSessionApi.deleteSession(session.id);
                if (success) {
                  if (session.id == _sessionId) {
                    // If deleted session was active, reset to fresh state
                    setState(() {
                      _sessionId = null;
                      _messages.clear();
                      _history.clear();
                    });
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/pictures/background-pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.black45),
            SizedBox(height: 16),
            Text('Mulai ngobrol dengan Levely!',
              style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _FormattedMessage extends StatelessWidget {
  final String text;
  final Color color;

  const _FormattedMessage({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    final baseStyle =
        TextStyle(color: color, fontFamily: 'DIN_Next_Rounded', height: 1.4);

    if (blocks.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          _buildBlock(blocks[i], baseStyle),
          if (i < blocks.length - 1) const SizedBox(height: 6),
        ]
      ],
    );
  }

  static Widget _buildBlock(_TextBlock block, TextStyle baseStyle) {
    switch (block.type) {
      case _BlockType.heading:
        return Text.rich(
          TextSpan(
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
            children: _buildInlineSpans(
                block.text, baseStyle.copyWith(fontWeight: FontWeight.w700)),
          ),
        );
      case _BlockType.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•', style: baseStyle),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                    style: baseStyle,
                    children: _buildInlineSpans(block.text, baseStyle)),
              ),
            ),
          ],
        );
      case _BlockType.numbered:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.prefix ?? '', style: baseStyle),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                    style: baseStyle,
                    children: _buildInlineSpans(block.text, baseStyle)),
              ),
            ),
          ],
        );
      case _BlockType.paragraph:
      default:
        return Text.rich(
          TextSpan(
              style: baseStyle,
              children: _buildInlineSpans(block.text, baseStyle)),
        );
    }
  }

  static List<_TextBlock> _parseBlocks(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final blocks = <_TextBlock>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) {
        return;
      }
      final paragraph = buffer.toString().trim();
      if (paragraph.isNotEmpty) {
        blocks.add(_TextBlock(_BlockType.paragraph, paragraph));
      }
      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushBuffer();
        continue;
      }

      final bulletMatch = RegExp(r'^[-*+•]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        flushBuffer();
        blocks.add(_TextBlock(_BlockType.bullet, bulletMatch.group(1)!.trim()));
        continue;
      }

      final numberMatch = RegExp(r'^(\d+)[\.)]\s+(.*)$').firstMatch(line);
      if (numberMatch != null) {
        flushBuffer();
        blocks.add(_TextBlock(
          _BlockType.numbered,
          numberMatch.group(2)!.trim(),
          prefix: '${numberMatch.group(1)}.',
        ));
        continue;
      }

      final hashHeading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
      if (hashHeading != null) {
        flushBuffer();
        blocks
            .add(_TextBlock(_BlockType.heading, hashHeading.group(1)!.trim()));
        continue;
      }

      final strongHeading = RegExp(r'^\*\*(.+)\*\*$').firstMatch(line);
      if (strongHeading != null &&
          strongHeading.group(1)!.trim().length <= 120) {
        flushBuffer();
        blocks.add(
            _TextBlock(_BlockType.heading, strongHeading.group(1)!.trim()));
        continue;
      }

      final colonHeading = RegExp(r'^(.+):$').firstMatch(line);
      if (colonHeading != null && colonHeading.group(1)!.trim().length <= 120) {
        flushBuffer();
        blocks
            .add(_TextBlock(_BlockType.heading, colonHeading.group(1)!.trim()));
        continue;
      }

      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(line);
    }

    flushBuffer();
    return blocks;
  }

  static List<TextSpan> _buildInlineSpans(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_)');
    int currentIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }

      final token = match.group(0)!;
      final isBold = token.startsWith('**') || token.startsWith('__');
      final isItalic =
          !isBold && (token.startsWith('*') || token.startsWith('_'));
      final normalized = _stripFormatting(token);

      spans.add(
        TextSpan(
          text: normalized,
          style: baseStyle.copyWith(
            fontWeight: isBold ? FontWeight.w700 : baseStyle.fontWeight,
            fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  static String _stripFormatting(String token) {
    if (token.length >= 4 && token.startsWith('**') && token.endsWith('**')) {
      return token.substring(2, token.length - 2);
    }
    if (token.length >= 4 && token.startsWith('__') && token.endsWith('__')) {
      return token.substring(2, token.length - 2);
    }
    if (token.length >= 2 && token.startsWith('*') && token.endsWith('*')) {
      return token.substring(1, token.length - 1);
    }
    if (token.length >= 2 && token.startsWith('_') && token.endsWith('_')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final activeDots = 1 + ((_controller.value * 3).floor() % 3);
        final text = List.filled(activeDots, '•').join(' ');
        return Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            letterSpacing: 2,
          ),
        );
      },
    );
  }
}

enum _BlockType { heading, paragraph, bullet, numbered }

class _TextBlock {
  final _BlockType type;
  final String text;
  final String? prefix;

  const _TextBlock(this.type, this.text, {this.prefix});
}

/// Exception khusus: koneksi stream putus tapi sudah ada konten sebagian.
/// [partial] berisi teks yang sudah diterima sebelum koneksi terputus.
/// Ini BUKAN error — digunakan untuk menampilkan jawaban parsial daripada pesan error.
class _PartialStreamResult implements Exception {
  final String partial;
  const _PartialStreamResult(this.partial);
}

