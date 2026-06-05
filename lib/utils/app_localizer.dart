import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/translation_service.dart';

class AppLocalizer {
  AppLocalizer._();

  static String text(BuildContext context, String viText) {
    if (context.locale.languageCode != 'en') {
      return viText;
    }
    return _viToEn[viText] ??
        TranslationService.instance.translateCachedOrQueue(
          sourceText: viText,
          targetLanguageCode: 'en',
        );
  }

  static String category(BuildContext context, String value) {
    if (context.locale.languageCode != 'en') {
      return value;
    }
    return _categoryViToEn[value] ??
        _viToEn[value] ??
        TranslationService.instance.translateCachedOrQueue(
          sourceText: value,
          targetLanguageCode: 'en',
        );
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

    // Header statistics
    'Tổng ví': 'Total balance',
    'Tham gia': 'Joined',

    // Status and buttons
    'Đã xác minh': 'Verified',
    'Đăng xuất': 'Logout',
    'Bảng điều khiển quản trị': 'Admin Dashboard',
    'Mở trang dashboard dành cho admin': 'Open the admin dashboard',

    // Cloud sync UI
    'Đang đồng bộ...': 'Syncing...',
    'Đã đồng bộ': 'Synced',
    'Lỗi đồng bộ': 'Sync error',
    'Không có kết nối mạng': 'No internet connection',
    'bản ghi chờ đồng bộ': 'records pending sync',
    'Chưa đồng bộ lần nào': 'Never synchronized',
    'Lần cuối: ': 'Last sync: ',
    'Tự động đồng bộ khi có kết nối': 'Auto sync when connected',
    'Thử lại': 'Retry',
    'bản ghi thành công!': 'records successfully!',
    'Đồng bộ thất bại: ': 'Sync failed: ',
    'Đã bật thông báo thành công!': 'Notifications enabled successfully!',
    'Vui lòng bật quyền thông báo trong cài đặt thiết bị.':
        'Please enable notification permissions in device settings.',
    'Đã tắt thông báo.': 'Notifications disabled.',

    // Personal Information Page
    'Họ và tên': 'Full name',
    'Nhập họ và tên': 'Enter your full name',
    'Số điện thoại': 'Phone number',
    'Chưa cập nhật': 'Not updated yet',
    'Ngày sinh': 'Date of birth',
    'Lưu thay đổi': 'Save changes',
    'Cập nhật hồ sơ thành công': 'Profile updated successfully',
    'Lỗi cập nhật hồ sơ: ': 'Error updating profile: ',

    // Password Change Page
    'Mật khẩu mới của bạn phải khác với mật khẩu đã sử dụng trước đó.':
        'Your new password must be different from your previously used password.',
    'Mật khẩu hiện tại': 'Current password',
    'Vui lòng nhập mật khẩu hiện tại': 'Please enter your current password',
    'Mật khẩu mới': 'New password',
    'Vui lòng nhập mật khẩu mới': 'Please enter your new password',
    'Mật khẩu phải có ít nhất 6 ký tự':
        'Password must be at least 6 characters',
    'Xác nhận mật khẩu': 'Confirm password',
    'Mật khẩu xác nhận không khớp': 'Confirm password does not match',
    'Đổi mật khẩu thành công!': 'Password changed successfully!',
    'Mật khẩu hiện tại không chính xác.': 'Current password is incorrect.',
    'Mật khẩu mới quá yếu.': 'New password is too weak.',
    'Lỗi: ': 'Error: ',

    // Home Screen
    'Xin chào,': 'Hello,',
    'Bạn': 'You',
    'Số dư khả dụng': 'Available balance',
    'Thu - Chi 6 tháng': '6-Month Cash Flow',
    'Thu': 'Income',
    'Chi': 'Expense',
    'Gợi ý tối ưu chi tiêu của bạn hôm nay':
        'Tips to optimize your spending today',
    'Ngân sách tháng này': 'This month\'s budget',
    'Xem tất cả': 'See all',
    'Bạn chưa thiết lập ngân sách.': 'You haven\'t set up any budget.',
    'Giao dịch gần đây': 'Recent transactions',
    'Bạn chưa có giao dịch nào.': 'You have no transactions yet.',

    // Financial Overview / Tabs & General
    'Tổng Quan Tài Chính': 'Financial Overview',
    'Tháng ': 'Month ',
    'Tổng thu': 'Total income',
    'Tổng chi': 'Total expense',
    'Số dư': 'Balance',
    'Trang Chủ': 'Home',
    'Tài Chính': 'Finance',
    'Ngân Sách': 'Budget',
    'Tiết kiệm': 'Savings',
    'Trả góp': 'Installment',
    'Vay nợ': 'Debt/Loan',
    'Đang tiết kiệm': 'Saving',
    'Còn trả góp': 'Remaining installment',
    'Còn vay': 'Remaining loan',
    'Chưa có mục tiêu tiết kiệm': 'No savings goals yet',
    'Còn ': 'Remaining ',
    ' ngày': ' days',
    'Đã quá hạn ': 'Overdue by ',
    'Đã trả ': 'Paid ',
    ' kỳ': ' periods',
    'Gốc + Lãi': 'Principal + Interest',
    'Còn nợ': 'Remaining debt',
    'Kỳ tiếp theo: ': 'Next period: ',
    'Kỳ tiếp: ': 'Next period: ',
    '+  Tạo mục tiêu mới': '+ Create new goal',
    'Chưa có kế hoạch trả góp': 'No installment plans yet',
    '+  Thêm kế hoạch trả góp': '+ Add installment plan',
    'Chưa có khoản vay nợ': 'No loans yet',
    'Tổng vay': 'Total loan',
    'Còn lại': 'Remaining',
    '+  Thêm khoản vay': '+ Add loan',
    '+ Nạp tiền': '+ Deposit',
    'Rút tiền': 'Withdraw',

    // Bottom Sheets & Inputs
    'Mục tiêu tiết kiệm mới': 'New savings goal',
    'Tên mục tiêu': 'Goal name',
    'Số tiền cần tiết kiệm': 'Amount to save',
    'Ngày dự kiến hoàn thành': 'Target completion date',
    'Tạo mục tiêu': 'Create goal',
    'Kế hoạch trả góp mới': 'New installment plan',
    'Tên khoản trả góp': 'Installment name',
    'Tổng số tiền': 'Total amount',
    'Số kỳ': 'Periods',
    'Mỗi kỳ': 'Each period',
    'Lưu kế hoạch': 'Save plan',
    'Khoản vay mới': 'New loan',
    'Tên khoản vay': 'Loan name',
    'Nguồn vay / Người cho vay': 'Lender / Source',
    'Trả mỗi tháng': 'Monthly payment',
    'Lãi suất': 'Interest rate',
    'Ngày đến hạn tiếp theo': 'Next due date',
    'Chọn ngày': 'Select date',
    'Lưu khoản vay': 'Save loan',
    '+  Thêm ngân sách mới': '+ Add new budget',
    'Đã thêm ngân sách ': 'Added budget ',
    'Bạn đã chi quá ': 'You spent over ',
    ' ngân sách ăn uống': ' of food & drink budget',
    'Không thể tải giao dịch': 'Unable to load transactions',
    'Chưa có giao dịch nào.\nHãy thêm giao dịch đầu tiên!':
        'No transactions yet.\nAdd your first transaction!',
    'Không tên': 'Unnamed',
    'Lưu mục tiêu tiết kiệm thất bại: ': 'Saving goal creation failed: ',
    'Xem thêm ': 'See ',
    ' ngân sách...': ' more budgets...',

    // Form Edit & Other Budget Strings
    'Chỉnh sửa ngân sách': 'Edit budget',
    'Hạn mức (VNĐ)': 'Limit (VND)',
    'Ví dụ: 3000000': 'Example: 3000000',
    'Vui lòng nhập hạn mức': 'Please enter limit',
    'Hạn mức phải là số nguyên dương': 'Limit must be a positive integer',
    'Tháng': 'Month',
    'Năm': 'Year',
    'Lưu ngân sách': 'Save budget',
    'Vui lòng chọn danh mục': 'Please select category',
    'Hạn mức phải lớn hơn 0': 'Limit must be greater than 0',
    'Chọn danh mục': 'Select category',
    'Không tìm thấy danh mục chi tiêu nào trong tài khoản. Hãy tạo danh mục trước.':
        'No spending categories found in this account. Please create categories first.',
    'Tổng ngân sách tháng 3': 'Total Budget',
    'Đã dùng: ': 'Spent: ',
    'Giới hạn: ': 'Limit: ',
    'Đã chi: ': 'Spent: ',
    'Còn lại: ': 'Remaining: ',
    'Ngân sách vs Thực tế': 'Budget vs Actual',
    'Ngân sách': 'Budget',
    'Thực tế': 'Actual',
    'đã dùng': 'used',
    'Đã vượt ngân sách!': 'Over budget!',
    'Sắp vượt ngân sách!': 'Almost over budget!',
    'Trả mỗi tháng ': 'Monthly payment ',
    'Chưa cập nhật lãi suất': 'No interest rate updated',
    'Lãi suất ': 'Interest ',
    'Ngày': 'Day',
    'Tuần': 'Week',
    'Thống Kê & Báo Cáo': 'Statistics & Reports',
    'Phân bố chi tiêu': 'Expense Distribution',
    'Tổng: ': 'Total: ',
    'Chưa có dữ liệu chi tiêu': 'No expense data yet',
    'Thu - Chi theo tháng': 'Monthly Cash Flow',
    'Chi tiêu trong tuần': 'Weekly Expenses',
    'Top danh mục chi tiêu': 'Top Expense Categories',
    'Chưa có dữ liệu': 'No data available',
    'Di chuyển': 'Transportation',
    'Mua sắm': 'Shopping',
    'Giải trí': 'Entertainment',
    'Giáo dục': 'Education',
    'Hóa đơn': 'Bills',
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
