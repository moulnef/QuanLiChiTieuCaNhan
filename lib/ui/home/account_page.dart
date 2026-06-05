import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const String _demoUserId = 'user_001';
  final FinanceRepository _repository = FinanceRepository();
  StreamSubscription? _transactionSub;

  bool _isLoading = true;
  String _name = 'Người dùng';
  String _email = 'Chưa cập nhật';
  double _totalBalance = 0;
  List<Map<String, dynamic>> _wallets = [];

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? _demoUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _transactionSub = _repository.watchTransactions(_currentUserId).listen((_) {
      _loadData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _transactionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      // Ensure user has default wallets before loading
      await _repository.ensureDefaultWalletsForUser(_currentUserId);

      // Small delay to ensure DB transaction completes
      await Future.delayed(const Duration(milliseconds: 100));

      final session = await _repository.getAuthSessionByUserId(_currentUserId);
      final wallets = await _repository.getWalletsByUserId(_currentUserId);
      final totalBalance = await _repository.getTotalWalletBalance(
        _currentUserId,
      );

      if (!mounted) return;
      setState(() {
        _name = session?['displayName']?.toString().isNotEmpty == true
            ? session!['displayName'].toString()
            : (FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng');
        _email = session?['email']?.toString().isNotEmpty == true
            ? session!['email'].toString()
            : (FirebaseAuth.instance.currentUser?.email ?? 'Chưa cập nhật');
        _wallets = wallets;
        _totalBalance = totalBalance;
      });
    } finally {
      if (mounted && !isSilent) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMoney(double amount) {
    return MoneyFormatter.formatVnd(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_email),
                          const SizedBox(height: 12),
                          Text(
                            'Tổng số dư ví: ${_formatMoney(_totalBalance)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Danh sách ví',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_wallets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có ví nào'),
                      ),
                    )
                  else
                    ..._wallets.map((wallet) {
                      final name = wallet['name']?.toString() ?? 'Ví';
                      final balance =
                          (wallet['balance'] as num?)?.toDouble() ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: Text(name),
                          trailing: Text(
                            _formatMoney(balance),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
