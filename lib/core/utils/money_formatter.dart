class MoneyFormatter {
  static String format(num amount) {
    final text = amount.round().toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  static String formatVnd(num amount) {
    return '${format(amount)} đ';
  }
}