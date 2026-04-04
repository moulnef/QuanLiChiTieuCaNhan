import 'package:flutter/material.dart';
import '../../domain/model/category_model.dart';

class CategoryData {
  // 1. DANH SÁCH CHI TIÊU (EXPENSE) - ĐẦY ĐỦ THEO YÊU CẦU
  static List<CategoryModel> getExpenseCategories() {
    return [
      // --- Nhóm: Ăn uống ---
      _cat('e1', 'Cafe', Icons.coffee, Colors.brown, 'Ăn uống'),
      _cat('e2', 'Ăn sáng', Icons.wb_sunny_outlined, Colors.orange, 'Ăn uống'),
      _cat('e3', 'Ăn tiệm', Icons.restaurant, Colors.red, 'Ăn uống'),
      _cat('e4', 'Đi chợ/Siêu thị', Icons.shopping_basket_outlined, Colors.green, 'Ăn uống'),
      _cat('e5', 'Ăn trưa', Icons.lunch_dining, Colors.amber, 'Ăn uống'),
      _cat('e6', 'Ăn tối', Icons.dinner_dining, Colors.deepOrange, 'Ăn uống'),

      // --- Nhóm: Dịch vụ sinh hoạt ---
      _cat('e7', 'Internet', Icons.wifi, Colors.blue, 'Dịch vụ sinh hoạt'),
      _cat('e8', 'Điện', Icons.electric_bolt, Colors.yellow.shade700, 'Dịch vụ sinh hoạt'),
      _cat('e9', 'Nước', Icons.water_drop, Colors.lightBlue, 'Dịch vụ sinh hoạt'),
      _cat('e10', 'Điện thoại', Icons.phone_android, Colors.blueGrey, 'Dịch vụ sinh hoạt'),
      _cat('e11', 'Gas', Icons.gas_meter_outlined, Colors.deepPurple, 'Dịch vụ sinh hoạt'),
      _cat('e12', 'Thuê người giúp việc', Icons.cleaning_services, Colors.teal, 'Dịch vụ sinh hoạt'),
      _cat('e13', 'Truyền hình', Icons.tv, Colors.indigo, 'Dịch vụ sinh hoạt'),

      // --- Nhóm: Đi lại ---
      _cat('e14', 'Xăng xe', Icons.local_gas_station, Colors.blueGrey, 'Đi lại'),
      _cat('e15', 'Bảo hiểm xe', Icons.verified_user_outlined, Colors.green.shade700, 'Đi lại'),
      _cat('e16', 'Gửi xe', Icons.local_parking, Colors.blue, 'Đi lại'),
      _cat('e17', 'Rửa xe', Icons.local_drink_outlined, Colors.cyan, 'Đi lại'),
      _cat('e18', 'Sửa chữa xe', Icons.build_circle_outlined, Colors.orange, 'Đi lại'),
      _cat('e19', 'Taxi/Thuê xe', Icons.local_taxi, Colors.yellow.shade800, 'Đi lại'),

      // --- Nhóm: Ngân hàng ---
      _cat('e20', 'Phí chuyển khoản', Icons.currency_exchange, Colors.indigoAccent, 'Ngân hàng'),

      // --- Nhóm: Trang phục ---
      _cat('e21', 'Quần áo', Icons.checkroom, Colors.pink, 'Trang phục'),
      _cat('e22', 'Giày dép', Icons.ice_skating_outlined, Colors.brown.shade400, 'Trang phục'),
      _cat('e23', 'Phụ kiện khác', Icons.watch, Colors.blueGrey, 'Trang phục'),

      // --- Nhóm: Hưởng thụ ---
      _cat('e24', 'Vui chơi giải trí', Icons.sports_esports_outlined, Colors.purple, 'Hưởng thụ'),
      _cat('e25', 'Du lịch', Icons.flight_takeoff, Colors.teal, 'Hưởng thụ'),
      _cat('e26', 'Làm đẹp', Icons.face_retouching_natural, Colors.pinkAccent, 'Hưởng thụ'),
      _cat('e27', 'Mỹ phẩm', Icons.auto_fix_high, Colors.deepPurpleAccent, 'Hưởng thụ'),
      _cat('e28', 'Phim ảnh', Icons.movie_outlined, Colors.redAccent, 'Hưởng thụ'),

      // --- Nhóm: Con cái ---
      _cat('e29', 'Học phí', Icons.school_outlined, Colors.blue, 'Con cái'),
      _cat('e30', 'Sách vở', Icons.menu_book, Colors.green, 'Con cái'),
      _cat('e31', 'Sữa', Icons.child_care, Colors.lightBlueAccent, 'Con cái'),
      _cat('e32', 'Tiền tiêu vặt', Icons.savings_outlined, Colors.orange, 'Con cái'),
      _cat('e33', 'Đồ chơi', Icons.toys_outlined, Colors.deepOrange, 'Con cái'),

      // --- Nhóm: Hiếu hỉ ---
      _cat('e34', 'Biếu tặng', Icons.card_giftcard, Colors.red, 'Hiếu hỉ'),
      _cat('e35', 'Cưới xin', Icons.favorite_border, Colors.pink, 'Hiếu hỉ'),
      _cat('e36', 'Ma chay', Icons.church_outlined, Colors.grey, 'Hiếu hỉ'),
      _cat('e37', 'Thăm hỏi', Icons.home_repair_service_outlined, Colors.blueGrey, 'Hiếu hỉ'),

      // --- Nhóm: Nhà cửa ---
      _cat('e38', 'Mua sắm đồ đạc', Icons.chair_outlined, Colors.brown, 'Nhà cửa'),
      _cat('e39', 'Sửa chữa nhà', Icons.home_repair_service, Colors.blueGrey, 'Nhà cửa'),
      _cat('e40', 'Thuê nhà', Icons.home_work_outlined, Colors.indigo, 'Nhà cửa'),

      // --- Nhóm: Phát triển bản thân ---
      _cat('e41', 'Giao lưu', Icons.groups_outlined, Colors.teal, 'Phát triển bản thân'),
      _cat('e42', 'Học hành', Icons.history_edu, Colors.blue, 'Phát triển bản thân'),

      // --- Nhóm: Sức khỏe ---
      _cat('e43', 'Khám chữa bệnh', Icons.medical_services_outlined, Colors.red, 'Sức khỏe'),
      _cat('e44', 'Thuốc men', Icons.medication, Colors.green, 'Sức khỏe'),
      _cat('e45', 'Thể thao', Icons.fitness_center, Colors.orange, 'Sức khỏe'),

      // --- Nhóm khác ---
      _cat('e46', 'Tiền ra', Icons.outbox_outlined, Colors.redAccent, 'Khác'),
      // Nhóm tài chính bổ sung để đồng bộ transaction với module tài chính
      _cat('e47', 'Nạp tiết kiệm', Icons.savings_outlined, Colors.teal, 'Tài chính'),
      _cat('e48', 'Thanh toán trả góp', Icons.credit_card, Colors.blue, 'Tài chính'),
      _cat('e49', 'Trả nợ', Icons.account_balance_wallet_outlined, Colors.deepOrange, 'Tài chính'),
    ];
  }

// 2. DANH SÁCH THU NHẬP (INCOME) - ĐẦY ĐỦ THEO YÊU CẦU
  static List<CategoryModel> getIncomeCategories() {
    return [
      _cat('i1', 'Lương', Icons.payments_outlined, Colors.green, 'Thu nhập chính'),
      _cat('i2', 'Lãi tiết kiệm', Icons.account_balance_outlined, Colors.blue, 'Đầu tư'),
      _cat('i3', 'Thưởng', Icons.card_giftcard, Colors.amber, 'Thu nhập phụ'),
      _cat('i4', 'Tiền lãi', Icons.trending_up, Colors.orange, 'Đầu tư'),
      _cat('i5', 'Tiền vào', Icons.input_rounded, Colors.teal, 'Khác'),
      _cat('i6', 'Được cho/tặng', Icons.volunteer_activism_outlined, Colors.pink, 'Thu nhập phụ'),
      _cat('i7', 'Khác', Icons.more_horiz, Colors.grey, 'Khác'),
      _cat('i8', 'Rút tiết kiệm', Icons.savings_outlined, Colors.teal, 'Tài chính'),
    ];
  }

  // 3. HÀM TIỆN ÍCH GỘP TẤT CẢ
  static List<CategoryModel> getAllCategories() {
    return [...getExpenseCategories(), ...getIncomeCategories()];
  }
  static CategoryModel? findById(String value) {
    for (final item in getAllCategories()) {
      if (item.id == value || item.name == value) {
        return item;
      }
    }
    return null;
  }

  // Hàm helper để viết code ngắn gọn hơn
  static CategoryModel _cat(String id, String name, IconData icon, Color color, String group) {
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