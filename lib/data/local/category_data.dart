import 'package:flutter/material.dart';

import '../../domain/model/category_model.dart';

class CategoryData {
  static const Map<String, String> _legacyNameMap = {
    'An u?ng': '\u0102n u\u1ed1ng',
    'An s?ng': '\u0102n s\u00e1ng',
    'An trua': '\u0102n tr\u01b0a',
    'An t?i': '\u0102n t\u1ed1i',
    'Di ch?/Sieu th?': '\u0110i ch\u1ee3/Si\u00eau th\u1ecb',
    'D?ch v? sinh ho?t': 'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
    'Nu?c': 'N\u01b0\u1edbc',
    'Xang xe': 'X\u0103ng xe',
    'B?o hi?m xe': 'B\u1ea3o hi\u1ec3m xe',
    'G?i xe': 'G\u1eedi xe',
    'R?a xe': 'R\u1eeda xe',
    'S?a ch?a xe': 'S\u1eeda ch\u1eefa xe',
    'Trang ph?c': 'Trang ph\u1ee5c',
    'Gi?y d?p': 'Gi\u00e0y d\u00e9p',
    'Hu?ng th?': 'H\u01b0\u1edfng th\u1ee5',
    'Du l?ch': 'Du l\u1ecbch',
    'Con c?i': 'Con c\u00e1i',
    'H?c ph?': 'H\u1ecdc ph\u00ed',
    'S?c kh?e': 'S\u1ee9c kh\u1ecfe',
    'Thu?c men': 'Thu\u1ed1c men',
    'Th? thao': 'Th\u1ec3 thao',
    'Kh?c': 'Kh\u00e1c',
    'Luong': 'L\u01b0\u01a1ng',
    'L?i ti?t ki?m': 'L\u00e3i ti\u1ebft ki\u1ec7m',
    'Thu?ng': 'Th\u01b0\u1edfng',
    'Ti?n l?i': 'Ti\u1ec1n l\u00e3i',
    'Ti?n v?o': 'Ti\u1ec1n v\u00e0o',
    'Thu nh?p ch?nh': 'Thu nh\u1eadp ch\u00ednh',
    'Thu nh?p ph?': 'Thu nh\u1eadp ph\u1ee5',
    '?u tu': '\u0110\u1ea7u t\u01b0',
  };

  static List<CategoryModel> getExpenseCategories() {
    return [
      _cat('e1', 'Cafe', Icons.coffee, Colors.brown, '\u0102n u\u1ed1ng'),
      _cat(
        'e2',
        '\u0102n s\u00e1ng',
        Icons.wb_sunny_outlined,
        Colors.orange,
        '\u0102n u\u1ed1ng',
      ),
      _cat(
        'e4',
        '\u0110i ch\u1ee3/Si\u00eau th\u1ecb',
        Icons.shopping_basket_outlined,
        Colors.green,
        '\u0102n u\u1ed1ng',
      ),
      _cat(
        'e5',
        '\u0102n tr\u01b0a',
        Icons.lunch_dining,
        Colors.amber,
        '\u0102n u\u1ed1ng',
      ),
      _cat(
        'e6',
        '\u0102n t\u1ed1i',
        Icons.dinner_dining,
        Colors.deepOrange,
        '\u0102n u\u1ed1ng',
      ),
      _cat(
        'e7',
        'Internet',
        Icons.wifi,
        Colors.blue,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e8',
        '\u0110i\u1ec7n',
        Icons.electric_bolt,
        Colors.yellow.shade700,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e9',
        'N\u01b0\u1edbc',
        Icons.water_drop,
        Colors.lightBlue,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e10',
        '\u0110i\u1ec7n tho\u1ea1i',
        Icons.phone_android,
        Colors.blueGrey,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e11',
        'Gas',
        Icons.gas_meter_outlined,
        Colors.deepPurple,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e12',
        'Thu\u00ea ng\u01b0\u1eddi gi\u00fap vi\u1ec7c',
        Icons.cleaning_services,
        Colors.teal,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e13',
        'Truy\u1ec1n h\u00ecnh',
        Icons.tv,
        Colors.indigo,
        'D\u1ecbch v\u1ee5 sinh ho\u1ea1t',
      ),
      _cat(
        'e14',
        'X\u0103ng xe',
        Icons.local_gas_station,
        Colors.blueGrey,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e15',
        'B\u1ea3o hi\u1ec3m xe',
        Icons.verified_user_outlined,
        Colors.green.shade700,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e16',
        'G\u1eedi xe',
        Icons.local_parking,
        Colors.blue,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e17',
        'R\u1eeda xe',
        Icons.local_drink_outlined,
        Colors.cyan,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e18',
        'S\u1eeda ch\u1eefa xe',
        Icons.build_circle_outlined,
        Colors.orange,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e19',
        'Taxi/Thu\u00ea xe',
        Icons.local_taxi,
        Colors.yellow.shade800,
        '\u0110i l\u1ea1i',
      ),
      _cat(
        'e20',
        'Ph\u00ed chuy\u1ec3n kho\u1ea3n',
        Icons.currency_exchange,
        Colors.indigoAccent,
        'Ng\u00e2n h\u00e0ng',
      ),
      _cat(
        'e21',
        'Qu\u1ea7n \u00e1o',
        Icons.checkroom,
        Colors.pink,
        'Trang ph\u1ee5c',
      ),
      _cat(
        'e22',
        'Gi\u00e0y d\u00e9p',
        Icons.ice_skating_outlined,
        Colors.brown.shade400,
        'Trang ph\u1ee5c',
      ),
      _cat(
        'e23',
        'Ph\u1ee5 ki\u1ec7n kh\u00e1c',
        Icons.watch,
        Colors.blueGrey,
        'Trang ph\u1ee5c',
      ),
      _cat(
        'e24',
        'Vui ch\u01a1i gi\u1ea3i tr\u00ed',
        Icons.sports_esports_outlined,
        Colors.purple,
        'H\u01b0\u1edfng th\u1ee5',
      ),
      _cat(
        'e25',
        'Du l\u1ecbch',
        Icons.flight_takeoff,
        Colors.teal,
        'H\u01b0\u1edfng th\u1ee5',
      ),
      _cat(
        'e26',
        'L\u00e0m \u0111\u1eb9p',
        Icons.face_retouching_natural,
        Colors.pinkAccent,
        'H\u01b0\u1edfng th\u1ee5',
      ),
      _cat(
        'e27',
        'M\u1ef9 ph\u1ea9m',
        Icons.auto_fix_high,
        Colors.deepPurpleAccent,
        'H\u01b0\u1edfng th\u1ee5',
      ),
      _cat(
        'e28',
        'Phim \u1ea3nh',
        Icons.movie_outlined,
        Colors.redAccent,
        'H\u01b0\u1edfng th\u1ee5',
      ),
      _cat(
        'e29',
        'H\u1ecdc ph\u00ed',
        Icons.school_outlined,
        Colors.blue,
        'Con c\u00e1i',
      ),
      _cat(
        'e30',
        'S\u00e1ch v\u1edf',
        Icons.menu_book,
        Colors.green,
        'Con c\u00e1i',
      ),
      _cat(
        'e31',
        'S\u1eefa',
        Icons.child_care,
        Colors.lightBlueAccent,
        'Con c\u00e1i',
      ),
      _cat(
        'e32',
        'Ti\u1ec1n ti\u00eau v\u1eb7t',
        Icons.savings_outlined,
        Colors.orange,
        'Con c\u00e1i',
      ),
      _cat(
        '\u0065\u0033\u0033',
        '\u0110\u1ed3 ch\u01a1i',
        Icons.toys_outlined,
        Colors.deepOrange,
        'Con c\u00e1i',
      ),
      _cat(
        'e34',
        'Bi\u1ebfu t\u1eb7ng',
        Icons.card_giftcard,
        Colors.red,
        'Hi\u1ebfu h\u1ef7',
      ),
      _cat(
        'e35',
        'C\u01b0\u1edbi xin',
        Icons.favorite_border,
        Colors.pink,
        'Hi\u1ebfu h\u1ef7',
      ),
      _cat(
        'e36',
        'Ma chay',
        Icons.church_outlined,
        Colors.grey,
        'Hi\u1ebfu h\u1ef7',
      ),
      _cat(
        'e37',
        'Th\u0103m h\u1ecfi',
        Icons.home_repair_service_outlined,
        Colors.blueGrey,
        'Hi\u1ebfu h\u1ef7',
      ),
      _cat(
        'e38',
        'Mua s\u1eafm \u0111\u1ed3 \u0111\u1ea1c',
        Icons.chair_outlined,
        Colors.brown,
        'Nh\u00e0 c\u1eeda',
      ),
      _cat(
        'e39',
        'S\u1eeda ch\u1eefa nh\u00e0',
        Icons.home_repair_service,
        Colors.blueGrey,
        'Nh\u00e0 c\u1eeda',
      ),
      _cat(
        'e40',
        'Thu\u00ea nh\u00e0',
        Icons.home_work_outlined,
        Colors.indigo,
        'Nh\u00e0 c\u1eeda',
      ),
      _cat(
        'e41',
        'Giao l\u01b0u',
        Icons.groups_outlined,
        Colors.teal,
        'Ph\u00e1t tri\u1ec3n b\u1ea3n th\u00e2n',
      ),
      _cat(
        'e42',
        'H\u1ecdc h\u00e0nh',
        Icons.history_edu,
        Colors.blue,
        'Ph\u00e1t tri\u1ec3n b\u1ea3n th\u00e2n',
      ),
      _cat(
        'e43',
        'Kh\u00e1m ch\u1eefa b\u1ec7nh',
        Icons.medical_services_outlined,
        Colors.red,
        'S\u1ee9c kh\u1ecfe',
      ),
      _cat(
        'e44',
        'Thu\u1ed1c men',
        Icons.medication,
        Colors.green,
        'S\u1ee9c kh\u1ecfe',
      ),
      _cat(
        'e45',
        'Th\u1ec3 thao',
        Icons.fitness_center,
        Colors.orange,
        'S\u1ee9c kh\u1ecfe',
      ),
      _cat(
        'e47',
        'Vay online',
        Icons.phonelink_ring_outlined,
        Colors.blueAccent,
        'Vay',
      ),
      _cat(
        'e48',
        'Vay offline',
        Icons.handshake_outlined,
        Colors.deepOrangeAccent,
        'Vay',
      ),
      _cat(
        'e46',
        'Ti\u1ec1n ra',
        Icons.outbox_outlined,
        Colors.redAccent,
        'Kh\u00e1c',
      ),
    ];
  }

  static List<CategoryModel> getIncomeCategories() {
    return [
      _cat(
        'i1',
        'L\u01b0\u01a1ng',
        Icons.payments_outlined,
        Colors.green,
        'Thu nh\u1eadp ch\u00ednh',
      ),
      _cat(
        'i2',
        'L\u00e3i ti\u1ebft ki\u1ec7m',
        Icons.account_balance_outlined,
        Colors.blue,
        '\u0110\u1ea7u t\u01b0',
      ),
      _cat(
        'i3',
        'Th\u01b0\u1edfng',
        Icons.card_giftcard,
        Colors.amber,
        'Thu nh\u1eadp ph\u1ee5',
      ),
      _cat(
        'i4',
        'Ti\u1ec1n l\u00e3i',
        Icons.trending_up,
        Colors.orange,
        '\u0110\u1ea7u t\u01b0',
      ),
      _cat(
        'i5',
        'Ti\u1ec1n v\u00e0o',
        Icons.input_rounded,
        Colors.teal,
        'Kh\u00e1c',
      ),
      _cat(
        'i6',
        '\u0110\u01b0\u1ee3c cho/t\u1eb7ng',
        Icons.volunteer_activism_outlined,
        Colors.pink,
        'Thu nh\u1eadp ph\u1ee5',
      ),
      _cat('i7', 'Kh\u00e1c', Icons.more_horiz, Colors.grey, 'Kh\u00e1c'),
    ];
  }

  static List<CategoryModel> getAllCategories() {
    return [...getExpenseCategories(), ...getIncomeCategories()];
  }

  static CategoryModel? findById(String id) {
    if (id.trim().isEmpty) return null;
    for (final category in getAllCategories()) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  static CategoryModel? findByName(String name) {
    final normalized = normalizeLabel(name).trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final category in getAllCategories()) {
      if (category.name.trim().toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }

  static CategoryModel? findByIdOrName(String value) {
    return findById(value) ?? findByName(value);
  }

  static String resolveDisplayName(String categoryId, [String? fallbackName]) {
    final resolved =
        findByIdOrName(categoryId) ?? findByIdOrName(fallbackName ?? '');
    return resolved?.name ?? normalizeLabel(fallbackName ?? categoryId);
  }

  static String normalizeLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return _legacyNameMap[trimmed] ?? trimmed;
  }

  static CategoryModel _cat(
    String id,
    String name,
    IconData icon,
    Color color,
    String group,
  ) {
    return CategoryModel(
      id: id,
      name: name,
      iconData: icon,
      color: color,
      type: id.startsWith('e') ? 'expense' : 'income',
      group: group,
    );
  }
}
