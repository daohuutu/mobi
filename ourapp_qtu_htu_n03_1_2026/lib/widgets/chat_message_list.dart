import 'package:flutter/material.dart';
import 'package:privatechat/models/chat_message.dart';
import 'package:privatechat/utils/message_date_utils.dart';
import 'package:privatechat/widgets/chat_date_separator.dart';
import 'package:privatechat/widgets/message_bubble.dart';

class _ChatListItem {
  const _ChatListItem._({this.date, this.message});

  const _ChatListItem.separator(DateTime date)
      : this._(date: date, message: null);

  const _ChatListItem.message(ChatMessage message)
      : this._(date: null, message: message);

  final DateTime? date;
  final ChatMessage? message;

  bool get isSeparator => date != null;
}

List<_ChatListItem> _buildChatListItems(List<ChatMessage> messages) {
  final items = <_ChatListItem>[];
  for (var i = 0; i < messages.length; i++) {
    if (i == 0 ||
        !isSameCalendarDay(
          messages[i - 1].timestamp,
          messages[i].timestamp,
        )) {
      items.add(_ChatListItem.separator(calendarDay(messages[i].timestamp)));
    }
    items.add(_ChatListItem.message(messages[i]));
  }
  return items;
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.me,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final String me;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final items = _buildChatListItems(messages);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item.isSeparator) {
          return ChatDateSeparator(date: item.date!);
        }
        final m = item.message!;
        final mine = m.isFrom(me);
        return MessageBubble(
          message: m,
          isMine: mine,
          header: mine ? null : m.from,
        );
      },
    );
  }
}
