import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/global_var.dart';
import 'package:app/utils/colors.dart';

class ChatbotResponseRating extends StatefulWidget {
  const ChatbotResponseRating({super.key});

  @override
  State<ChatbotResponseRating> createState() => _ChatbotResponseRatingState();
}

class _ChatbotResponseRatingState extends State<ChatbotResponseRating> {
  int _rating = 0;
  String _userRequest = "Memuat...";
  String _botResponse = "Memuat...";
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
    _fetchData();
  }

  void _onCommentChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await _fetchLatestChat();
    setState(() => _isLoading = false);
  }

  bool _isLimitReached = false;

  Future<void> _fetchLatestChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) {
        setState(() => _error = "User ID tidak ditemukan.");
        return;
      }

      final response = await http.get(
        Uri.parse('${GlobalVar.baseUrl}/chat/unrated/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['found'] == true) {
          setState(() {
            _userRequest = data['userRequest'];
            _botResponse = data['botResponse'];
            _isLimitReached = false;
          });
        } else if (data['limitReached'] == true || data['allRated'] == true) {
          setState(() {
            _error = data['message'];
            _isLimitReached = true;
          });
        } else {
          setState(() => _error =
              data['message'] ?? "Belum ada riwayat chat untuk dinilai.");
        }
      } else {
        setState(() => _error = "Gagal memuat riwayat chat.");
      }
    } catch (e) {
      setState(() => _error = "Terjadi kesalahan: $e");
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      final response = await http.post(
        Uri.parse('${GlobalVar.baseUrl}/chat/rating'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'userRequest': _userRequest,
          'botResponse': _botResponse,
          'rating': _rating,
          'comment': _commentController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rating berhasil dikirim!")),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Rating Levely!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DIN_Next_Rounded',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_isLimitReached)
                Column(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? "Terima kasih sudah merating Levely! 😊",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (_error != null)
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red))
              else ...[
                _buildChatPair(),
                const SizedBox(height: 24),
                _buildRatingStars(),
                const SizedBox(height: 16),
                const Text("Mengapa kamu memberikan rating ini?",
                    style: TextStyle(
                        fontFamily: 'DIN_Next_Rounded',
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  enabled: _rating > 0,
                  decoration: InputDecoration(
                    hintText: _rating == 0
                        ? "Berikan rating terlebih dahulu..."
                        : "Tulis alasanmu di sini...",
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPair() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Permintaanmu:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Text(
              _userRequest,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'DIN_Next_Rounded',
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Respon Levely:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: _FormattedMessage(
              text: _botResponse,
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingStars() {
    return Column(
      children: [
        const Text("Berikan penilaian Anda:",
            style: TextStyle(fontFamily: 'DIN_Next_Rounded')),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              onPressed: () => setState(() => _rating = index + 1),
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isLimitReached) {
      return ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Tutup",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    final bool canSubmit = !_isLoading &&
        _error == null &&
        !_isSubmitting &&
        _rating > 0 &&
        _commentController.text.trim().isNotEmpty;

    return ElevatedButton(
      onPressed: canSubmit ? _submitRating : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Text("Kirim Rating",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _FormattedMessage extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const _FormattedMessage({
    required this.text,
    required this.color,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    final baseStyle = TextStyle(
      color: color,
      fontFamily: 'DIN_Next_Rounded',
      height: 1.4,
      fontSize: fontSize,
    );

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
      // ignore: unreachable_switch_default
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

enum _BlockType { heading, paragraph, bullet, numbered }

class _TextBlock {
  final _BlockType type;
  final String text;
  final String? prefix;

  const _TextBlock(this.type, this.text, {this.prefix});
}
