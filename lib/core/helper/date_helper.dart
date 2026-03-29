import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateHelper {
  // 1. ĐỊNH DẠNG: DateTime -> string (E, dd/MM/yyyy -> Thứ Hai, 23/03/2026)
  static String formatHeaderDate(DateTime date) {
    // Đổi tiếng Anh sang tiếng Việt thủ công cho gọn
    String weekday = DateFormat('EEEE', 'en_US').format(date);
    switch (weekday) {
      case 'Monday': weekday = 'Thứ Hai'; break;
      case 'Tuesday': weekday = 'Thứ Ba'; break;
      case 'Wednesday': weekday = 'Thứ Tư'; break;
      case 'Thursday': weekday = 'Thứ Năm'; break;
      case 'Friday': weekday = 'Thứ Sáu'; break;
      case 'Saturday': weekday = 'Thứ Bảy'; break;
      case 'Sunday': weekday = 'Chủ Nhật'; break;
    }
    String dayMonth = DateFormat('dd/MM/yyyy', 'en_US').format(date);
    return "$weekday, $dayMonth";
  }

  // 2. ĐỊNH DẠNG SỐ TIỀN CÓ CHẤM (+21.000.000đ)
  static String formatAmount(double amount) {
    String number = NumberFormat('#,###', 'en_US').format(amount).replaceAll(',', '.');
    return "$number đ";
  }

  // 3. LOGIC LẤY KHOẢNG THỜI GIAN (START, END)

  // -- Theo Ngày --
  static DateTimeRange todayRange() {
    final now = DateTime.now();
    return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
  }

  static DateTimeRange yesterdayRange() {
    final date = DateTime.now().subtract(const Duration(days: 1));
    return DateTimeRange(start: _startOfDay(date), end: _endOfDay(date));
  }

  // -- Theo Tuần --
  static DateTimeRange thisWeekRange() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(start: _startOfDay(start), end: _endOfDay(now));
  }

  static DateTimeRange lastWeekRange() {
    final now = DateTime.now();
    final startThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startLastWeek = startThisWeek.subtract(const Duration(days: 7));
    final endLastWeek = startLastWeek.add(const Duration(days: 6));
    return DateTimeRange(start: _startOfDay(startLastWeek), end: _endOfDay(endLastWeek));
  }

  // -- Theo Tháng --
  static DateTimeRange thisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: start, end: _endOfDay(now));
  }

  static DateTimeRange lastMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 0); // Ngày cuối cùng tháng trước
    return DateTimeRange(start: start, end: _endOfDay(end));
  }

  // -- Theo Quý --
  static DateTimeRange quarterRange(int quarterNum) {
    final year = DateTime.now().year;
    switch (quarterNum) {
      case 1: return DateTimeRange(start: DateTime(year, 1, 1), end: _endOfDay(DateTime(year, 3, 31)));
      case 2: return DateTimeRange(start: DateTime(year, 4, 1), end: _endOfDay(DateTime(year, 6, 30)));
      case 3: return DateTimeRange(start: DateTime(year, 7, 1), end: _endOfDay(DateTime(year, 9, 30)));
      case 4: return DateTimeRange(start: DateTime(year, 10, 1), end: _endOfDay(DateTime(year, 12, 31)));
      default: return DateTimeRange(start: DateTime.now(), end: DateTime.now());
    }
  }

  // Tiện ích phụ: Đặt giờ về 00:00:00 và 23:59:59
  static DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 0, 0, 0);
  static DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);
}