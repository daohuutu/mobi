import 'package:intl/intl.dart';

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime calendarDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String formatDateSeparator(DateTime date) {
  final now = DateTime.now();
  final today = calendarDay(now);
  final day = calendarDay(date);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  if (date.year == now.year) {
    return '${date.day} tháng ${date.month}';
  }
  return DateFormat('dd/MM/yyyy').format(date);
}

String formatMessageTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final time = DateFormat.Hm().format(timestamp);

  if (isSameCalendarDay(timestamp, now)) return time;
  if (timestamp.year == now.year) {
    return '${DateFormat('dd/MM').format(timestamp)} $time';
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
}
