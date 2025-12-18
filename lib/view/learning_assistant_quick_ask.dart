import 'package:app/utils/colors.dart';
import 'package:app/model/levely_models.dart';
import 'package:flutter/material.dart';

Future<List<LevelyChatMessage>?> showLearningAssistantQuickAsk(
  BuildContext context, {
  int? courseId,
  int? level,
  String? chapterName,
}) {
  return showModalBottomSheet<List<LevelyChatMessage>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _LearningAssistantQuickAskSheet(
        courseId: courseId,
        level: level,
        chapterName: chapterName,
      );
    },
  );
}

class _LearningAssistantQuickAskSheet extends StatefulWidget {
  final int? courseId;
  final int? level;
  final String? chapterName;

  const _LearningAssistantQuickAskSheet({
    this.courseId,
    this.level,
    this.chapterName,
  });

  @override
  State<_LearningAssistantQuickAskSheet> createState() => _LearningAssistantQuickAskSheetState();
}

class _LearningAssistantQuickAskSheetState extends State<_LearningAssistantQuickAskSheet> {
  final TextEditingController _composer = TextEditingController();
  final List<LevelyChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _messages.insert(
      0,
      LevelyChatMessage.assistant(
        "Aku Levely. Quick Ask dulu ya—kalau perlu chat panjang klik Expand.",
      ),
    );

    final summary = _contextSummary();
    if (summary.isNotEmpty) {
      _messages.insert(0, LevelyChatMessage.assistant(summary));
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  String _contextSummary() {
    final parts = <String>[];
    if (widget.courseId != null) parts.add("Course ${widget.courseId}");
    if (widget.level != null) parts.add("Level ${widget.level}");
    if (widget.chapterName != null && widget.chapterName!.trim().isNotEmpty) {
      parts.add(widget.chapterName!.trim());
    }
    return parts.isEmpty ? "" : "Konteks: ${parts.join(" • ")}";
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, LevelyChatMessage.user(text));
      _messages.insert(0, LevelyChatMessage.assistant(_stubReply(text)));
    });

    _composer.clear();
    FocusScope.of(context).unfocus();
  }

  String _stubReply(String prompt) {
    final p = prompt.toLowerCase();
    if (p.contains("ringkas") || p.contains("summary")) {
      return "Bisa. Bagian mana yang mau diringkas?";
    }
    if (p.contains("contoh") || p.contains("example")) {
      return "Oke. Sebutkan topiknya ya, nanti aku buatkan contoh singkat.";
    }
    if (p.contains("quiz") || p.contains("latihan")) {
      return "Siap. Mau 5 soal atau 10 soal?";
    }
    return "Sip. Kalau mau lebih detail, klik Expand biar enak bacanya.";
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Levely",
                        style: TextStyle(
                          fontFamily: 'DIN_Next_Rounded',
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, _messages),
                      icon: Icon(Icons.open_in_full, size: 20),
                      tooltip: "Expand",
                      color: AppColors.primaryColor,
                    ),
                    IconButton(
                      tooltip: "Tutup",
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 360),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBubbleWidth = constraints.maxWidth * 0.9;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: _messages[i],
                        maxBubbleWidth: maxBubbleWidth,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AnimatedBuilder(
                  animation: _composer,
                  builder: (context, _) {
                    final canSend = _composer.text.trim().isNotEmpty;
                    return TextField(
                      controller: _composer,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: "Tanya cepat…",
                        hintStyle: TextStyle(color: Colors.grey, fontFamily: 'DIN_Next_Rounded'),
                        filled: true,
                        fillColor: Color(0xFFF3EDF7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            onPressed: canSend ? _send : null,
                            icon: Icon(Icons.send_rounded),
                            color: AppColors.primaryColor,
                            disabledColor: AppColors.primaryColor.withValues(alpha: 0.35),
                            tooltip: "Kirim",
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
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
}

class _Bubble extends StatelessWidget {
  final LevelyChatMessage message;
  final double maxBubbleWidth;

  const _Bubble({required this.message, required this.maxBubbleWidth});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.fromUser ? AppColors.primaryColor : Color(0xFFF3EDF7);
    final textColor = message.fromUser ? Colors.white : Colors.black87;
    final radius = message.fromUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(14),
          );

    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
          ),
          child: Text(
            message.text,
            textAlign: message.fromUser ? TextAlign.right : TextAlign.left,
            textWidthBasis: TextWidthBasis.longestLine,
            style: TextStyle(
              color: textColor,
              fontFamily: 'DIN_Next_Rounded',
              fontSize: 14,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
