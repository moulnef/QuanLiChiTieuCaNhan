import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AppLocalizer {
  AppLocalizer._();

  static String text(BuildContext context, String viText) {
    if (context.locale.languageCode != 'en') {
      return viText;
    }
    return _viToEn[viText] ?? viText;
  }

  static String category(BuildContext context, String value) {
    if (context.locale.languageCode != 'en') {
      return value;
    }
    return _categoryViToEn[value] ?? _viToEn[value] ?? value;
  }

  static String weekdayLabel(BuildContext context, DateTime date) {
    const viWeekdays = [
      'Chủ Nhật',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
    ];
    const enWeekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    final index = date.weekday == 7 ? 0 : date.weekday;
    return context.locale.languageCode == 'en'
        ? enWeekdays[index]
        : viWeekdays[index];
  }

  static final Map<String, String> _viToEn = {
    'Giao dịch': 'Transactions',
    'Tìm kiếm...': 'Search...',
    'Thu nhập': 'Income',
    'Chi tiêu': 'Expense',
    'Tổng': 'Total',
    'Không có giao dịch nào.': 'No transactions found.',
    'Tất cả': 'All',
    'Đặt lại': 'Reset',
    'Lọc & Sắp xếp': 'Filter & Sort',
    'Sắp xếp': 'Sort',
    'Mới nhất': 'Newest',
    'Số tiền giảm dần': 'Amount: High to Low',
    'Số tiền tăng dần': 'Amount: Low to High',
    'Danh mục': 'Category',
    'Theo nhóm danh mục của tab hiện tại':
        'By category group of the current tab',
    'Thời gian': 'Date',
    'Hôm nay': 'Today',
    'Tuần này': 'This week',
    'Tháng này': 'This month',
    'Năm này': 'This year',
    'Chọn khoảng thời gian': 'Select date range',
    'Chọn khoảng tùy chỉnh': 'Pick custom range',
    'Xóa lọc thời gian': 'Clear date filter',
    'Hủy': 'Cancel',
    'Áp dụng': 'Apply',
    'Tất cả thời gian': 'All time',
    'Cao nhất': 'Highest',
    'Thấp nhất': 'Lowest',
    'Ngày gần nhất': 'Most recent',
    'Lọc theo hạng mục': 'Filter by category',
    'Tất cả hạng mục': 'All categories',
    'Tìm kiếm theo tên hạng mục...': 'Search category name...',
    'Tiền nhiều nhất': 'Highest amount',
    'Tiền ít nhất': 'Lowest amount',
    'Ngôn ngữ': 'Language',
    'Tài khoản': 'Account',
    'Thông báo': 'Notifications',
    'Dữ liệu': 'Data',
    'Quản trị': 'Admin',
    'Thông tin cá nhân': 'Personal information',
    'Họ tên, ngày sinh': 'Full name, date of birth',
    'Đổi mật khẩu': 'Change password',
    'Cập nhật mật khẩu': 'Update password',
    'Nhắc nhở thanh toán': 'Payment reminder',
    'Thông báo trước 3 ngày': 'Remind 3 days before',
    'Đồng bộ đám mây': 'Cloud sync',
    'Lần cuối: vừa xong': 'Last sync: just now',
    'Sao lưu dữ liệu': 'Backup data',
    'Sao lưu / Khôi phục': 'Backup / Restore',
    'Vui lòng nhập đầy đủ email và mật khẩu':
        'Please enter both email and password',
    'Không tìm thấy tài khoản này.': 'Account not found.',
    'Mật khẩu không chính xác.': 'Incorrect password.',
    'Quên mật khẩu?': 'Forgot password?',
    'Chào mừng\ntrở lại': 'Welcome\nback',
    'Đăng nhập để quản lý tài chính của bạn': 'Sign in to manage your finances',
    'ĐĂNG NHẬP': 'LOGIN',
    'hoặc tiếp tục với': 'or continue with',
    'Chưa có tài khoản? ': 'Don\'t have an account? ',
    'Đăng ký ngay': 'Sign up now',
    'Đăng ký': 'Sign up',
    'Đã có lỗi xảy ra': 'An error occurred',
    'Cập nhật thành công!': 'Updated successfully!',
    'Lưu giao dịch thành công!': 'Transaction saved successfully!',
    'Xóa giao dịch này?': 'Delete this transaction?',
    'Dữ liệu bị xóa sẽ không thể khôi phục lại được. Bạn có chắc chắn muốn tiếp tục?':
        'Deleted data cannot be restored. Are you sure you want to continue?',
    'Xóa': 'Delete',
    'Đã xóa giao dịch': 'Transaction deleted',
    'Chi tiết giao dịch': 'Transaction details',
    'Thêm giao dịch': 'Add transaction',
    'Số tiền': 'Amount',
    'Chọn hạng mục': 'Select category',
    'Hạng mục thường dùng': 'Frequent categories',
    'Ghi chú thêm...': 'Add note...',
    'LƯU GIAO DỊCH': 'SAVE TRANSACTION',
    'XÓA': 'DELETE',
    'LƯU LẠI': 'SAVE',
  };

  static final Map<String, String> _categoryViToEn = {
    'Ăn uống': 'Food & Drinks',
    'Dịch vụ sinh hoạt': 'Utilities',
    'Đi lại': 'Transport',
    'Ngân hàng': 'Banking',
    'Trang phục': 'Clothing',
    'Hưởng thụ': 'Leisure',
    'Con cái': 'Children',
    'Hiếu hỉ': 'Ceremony',
    'Nhà cửa': 'Home',
    'Phát triển bản thân': 'Self development',
    'Sức khỏe': 'Health',
    'Vay': 'Loan',
    'Khác': 'Other',
    'Thu nhập chính': 'Primary income',
    'Đầu tư': 'Investment',
    'Thu nhập phụ': 'Side income',
    'Cafe': 'Coffee',
    'Ăn sáng': 'Breakfast',
    'Đi chợ/Siêu thị': 'Grocery/Supermarket',
    'Ăn trưa': 'Lunch',
    'Ăn tối': 'Dinner',
    'Internet': 'Internet',
    'Điện': 'Electricity',
    'Nước': 'Water',
    'Điện thoại': 'Phone',
    'Gas': 'Gas',
    'Thuê người giúp việc': 'Housekeeper',
    'Truyền hình': 'Television',
    'Xăng xe': 'Fuel',
    'Bảo hiểm xe': 'Vehicle insurance',
    'Gửi xe': 'Parking',
    'Rửa xe': 'Car wash',
    'Sửa chữa xe': 'Vehicle repair',
    'Taxi/Thuê xe': 'Taxi/Rental',
    'Phí chuyển khoản': 'Transfer fee',
    'Quần áo': 'Clothes',
    'Giày dép': 'Shoes',
    'Phụ kiện khác': 'Accessories',
    'Vui chơi giải trí': 'Entertainment',
    'Du lịch': 'Travel',
    'Làm đẹp': 'Beauty',
    'Mỹ phẩm': 'Cosmetics',
    'Phim ảnh': 'Movies',
    'Học phí': 'Tuition',
    'Sách vở': 'Books',
    'Sữa': 'Milk',
    'Tiền tiêu vặt': 'Pocket money',
    'Đồ chơi': 'Toys',
    'Biếu tặng': 'Gifts',
    'Cưới xin': 'Wedding',
    'Ma chay': 'Funeral',
    'Thăm hỏi': 'Visits',
    'Mua sắm đồ đạc': 'Furniture shopping',
    'Sửa chữa nhà': 'Home repair',
    'Thuê nhà': 'Rent',
    'Giao lưu': 'Networking',
    'Học hành': 'Study',
    'Khám chữa bệnh': 'Medical checkup',
    'Thuốc men': 'Medicine',
    'Thể thao': 'Sports',
    'Vay online': 'Online loan',
    'Vay offline': 'Offline loan',
    'Tiền ra': 'Money out',
    'Lương': 'Salary',
    'Lãi tiết kiệm': 'Savings interest',
    'Thưởng': 'Bonus',
    'Tiền lãi': 'Interest',
    'Tiền vào': 'Money in',
    'Được cho/tặng': 'Given/Gifted',
  };
}

extension AppLocalizerStringX on String {
  String xtr(BuildContext context) => AppLocalizer.text(context, this);

  String xtrCategory(BuildContext context) =>
      AppLocalizer.category(context, this);
}
