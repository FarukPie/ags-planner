/// 135 -> "2 sa 15 dk", 40 -> "40 dk".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m dk';
  return m == 0 ? '$h sa' : '$h sa $m dk';
}
