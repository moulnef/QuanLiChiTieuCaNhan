class BankInterest {
  final String name;
  final Map<int, double> rates; // Kỳ hạn (tháng) : Lãi suất (%/năm)

  BankInterest({required this.name, required this.rates});
}

final List<BankInterest> bankData = [
  BankInterest(
    name: 'Ngân hàng ABC',
    rates: {6: 8.5, 12: 9.0, 24: 10.0, 36: 10.5},
  ),
  BankInterest(
    name: 'MB Bank',
    rates: {6: 7.0, 12: 8.2, 24: 9.5, 36: 11.0, 48: 12.0},
  ),
  BankInterest(
    name: 'Vietcombank',
    rates: {6: 6.5, 12: 7.5, 24: 8.5, 60: 10.0},
  ),
];

final List<BankInterest> loanBankData = [
  BankInterest(
    name: 'Vietcombank (Vay tiêu dùng)',
    rates: {12: 10.5, 24: 11.0, 36: 11.5, 60: 12.0},
  ),
  BankInterest(
    name: 'MB Bank (Vay nhanh)',
    rates: {6: 12.0, 12: 13.5, 24: 14.5, 36: 15.0},
  ),
  BankInterest(
    name: 'TPBank (Vay tín chấp)',
    rates: {12: 15.0, 24: 16.0, 36: 17.0},
  ),
];
