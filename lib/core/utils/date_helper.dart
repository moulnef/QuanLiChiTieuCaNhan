class DateHelper {
  static bool isInMonth({
    required int timestamp,
    required int month,
    required int year,
  }) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.month == month && date.year == year;
  }
}