import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/model/chat_message.dart';
import 'package:app/utils/colors.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final bool showIndicator;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final List<String> thinkingPlaceholders;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isStreaming,
    required this.showIndicator,
    this.onLongPress,
    this.onRetry,
    required this.thinkingPlaceholders,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    Widget bubbleContent = Container(
      padding: const EdgeInsets.all(12),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.primaryColor
            : AppColors.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<String>(
            valueListenable: message.contentNotifier,
            builder: (context, content, _) {
              return isUser
                  ? Text(content,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'DIN_Next_Rounded',
                          fontSize: 16,
                          height: 1.4))
                  : (isStreaming
                      ? Text(content,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontFamily: 'DIN_Next_Rounded',
                              fontSize: 16,
                              height: 1.4))
                      : MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                                color: Colors.black87,
                                fontFamily: 'DIN_Next_Rounded',
                                fontSize: 16,
                                height: 1.4),
                            code: const TextStyle(
                                backgroundColor: Colors.black12,
                                fontFamily: 'monospace'),
                          ),
                        ));
            },
          ),
          if (showIndicator)
            const Padding(
                padding: EdgeInsets.only(top: 6), child: TypingIndicator()),
        ],
      ),
    );

    if (!isUser) {
      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            contextMenuBuilder: (context, selectableRegionState) {
              final List<ContextMenuButtonItem> buttonItems =
                  selectableRegionState.contextMenuButtonItems;
              final List<ContextMenuButtonItem> priority = [];
              final List<ContextMenuButtonItem> others = [];

              final types = [
                ContextMenuButtonType.copy,
                ContextMenuButtonType.share,
                ContextMenuButtonType.selectAll,
              ];

              for (final type in types) {
                final index =
                    buttonItems.indexWhere((item) => item.type == type);
                if (index != -1) {
                  priority.add(buttonItems.removeAt(index));
                }
              }
              others.addAll(buttonItems);

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: [...priority, ...others],
              );
            },
            child: bubbleContent,
          ),
          if (!showIndicator && !isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pesan disalin ke clipboard'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.copy_rounded,
                              size: 14, color: Colors.black45),
                          SizedBox(width: 4),
                          Text(
                            'Salin',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontFamily: 'DIN_Next_Rounded',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.refresh_rounded,
                                size: 14, color: Colors.black45),
                            SizedBox(width: 4),
                            Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontFamily: 'DIN_Next_Rounded',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              ValueListenableBuilder<String>(
                valueListenable: message.contentNotifier,
                builder: (context, content, _) => _buildAvatar(content),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: bubbleContent),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String content) {
    String asset = 'lib/assets/vectors/levely_smile.svg';
    if (showIndicator) {
      asset = 'lib/assets/vectors/levely_thinking.svg';
    } else if (content.startsWith('Error:') ||
        content.contains('Maaf, aku belum bisa menjawab.')) {
      asset = 'lib/assets/vectors/levely_error.svg';
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accentColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(6),
      child: SvgPicture.asset(asset),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
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
        final dots = 1 + ((_controller.value * 3).floor() % 3);
        return Text(List.filled(dots, '•').join(' '),
            style: const TextStyle(
                fontSize: 14, color: Colors.black54, letterSpacing: 2));
      },
    );
  }
}
