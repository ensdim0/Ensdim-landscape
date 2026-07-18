import 'package:intl/intl.dart';

String formatTime(DateTime dateTime) {
  return DateFormat('h:mm a', 'en').format(dateTime.toLocal());
}

String formatDate(DateTime dateTime) {
  return DateFormat('yyyy/MM/dd', 'en').format(dateTime.toLocal());
}

String formatDateTime(DateTime dateTime) {
  return '${formatDate(dateTime)} ${formatTime(dateTime)}';
}
