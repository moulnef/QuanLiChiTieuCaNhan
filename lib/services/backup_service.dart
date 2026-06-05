import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> exportToMap(String userId) async {
    final db = await DatabaseHelper.instance.database;

    final tables = [
      'transactions',
      'budgets',
      'savings',
      'installments',
      'debts',
      'wallets',
    ];
    final Map<String, dynamic> backupData = {
      'metadata': <String, dynamic>{
        'userId': userId,
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      },
      'data': <String, dynamic>{},
    };

    for (var table in tables) {
      final rows = await db.query(
        table,
        where: 'COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      backupData['data'][table] = rows;
    }

    return backupData;
  }

  Future<void> importFromMap(
    String userId,
    Map<String, dynamic> dataJson,
  ) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      final tables = [
        'transactions',
        'budgets',
        'savings',
        'installments',
        'debts',
        'wallets',
      ];

      // Delete existing data for this user
      for (var table in tables) {
        await txn.delete(
          table,
          where: 'COALESCE(userId, user_id) = ?',
          whereArgs: [userId],
        );
      }

      // Insert new data
      final data = Map<String, dynamic>.from(dataJson['data'] as Map);
      
      // Lấy oldUserId từ metadata nếu có
      String? oldUserId;
      if (dataJson.containsKey('metadata') && dataJson['metadata'] is Map) {
        oldUserId = dataJson['metadata']['userId']?.toString();
      }

      for (var table in tables) {
        if (data.containsKey(table)) {
          final rows = data[table] as List;
          for (var row in rows) {
            final Map<String, dynamic> newRow = Map<String, dynamic>.from(row);
            
            // Set isSynced = 0 for tables that have it
            if (table != 'wallets') {
              newRow['isSynced'] = 0;
            }

            // Đồng bộ hoá UserId và WalletId của dữ liệu nhập vào với User hiện tại
            if (oldUserId != null && oldUserId.isNotEmpty) {
              if (newRow['userId'] == oldUserId) newRow['userId'] = userId;
              if (newRow['user_id'] == oldUserId) newRow['user_id'] = userId;
              
              if (newRow['id'] == 'wallet_cash_$oldUserId') {
                newRow['id'] = 'wallet_cash_$userId';
              }
              if (newRow['walletId'] == 'wallet_cash_$oldUserId') {
                newRow['walletId'] = 'wallet_cash_$userId';
              }
              if (newRow['wallet_id'] == 'wallet_cash_$oldUserId') {
                newRow['wallet_id'] = 'wallet_cash_$userId';
              }
            } else {
              // Dự phòng: Nếu không tìm thấy oldUserId trong metadata
              if (newRow.containsKey('userId')) newRow['userId'] = userId;
              if (newRow.containsKey('user_id')) newRow['user_id'] = userId;
              
              if (newRow['id'] != null && newRow['id'].toString().startsWith('wallet_cash_')) {
                newRow['id'] = 'wallet_cash_$userId';
              }
              if (newRow['walletId'] != null && newRow['walletId'].toString().startsWith('wallet_cash_')) {
                newRow['walletId'] = 'wallet_cash_$userId';
              }
              if (newRow['wallet_id'] != null && newRow['wallet_id'].toString().startsWith('wallet_cash_')) {
                newRow['wallet_id'] = 'wallet_cash_$userId';
              }
            }

            await txn.insert(
              table,
              newRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });
  }

  Future<void> exportToLocalFile(String userId) async {
    final data = await exportToMap(userId);
    final jsonString = jsonEncode(data);
    final base64String = base64Encode(utf8.encode(jsonString));

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/backup_$userId.json');
    await file.writeAsString(base64String);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Dữ liệu sao lưu từ Quản Lý Chi Tiêu Cá Nhân');
  }

  Future<bool> importFromLocalFile(String userId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = (await file.readAsString()).trim();

      try {
        Map<String, dynamic> data;
        
        // Nhận diện định dạng: xem là JSON thô hay Base64
        if (content.startsWith('{') && content.endsWith('}')) {
          data = jsonDecode(content) as Map<String, dynamic>;
        } else {
          final decodedContent = utf8.decode(base64Decode(content));
          data = jsonDecode(decodedContent) as Map<String, dynamic>;
        }

        // Basic validation
        if (data.containsKey('metadata') && data.containsKey('data')) {
          await importFromMap(userId, data);
          return true;
        }
      } catch (e) {
        print('Lỗi giải mã file hoặc dữ liệu không hợp lệ: $e');
      }
    }
    return false;
  }

  Future<void> createCloudBackupPoint(String userId, String label) async {
    final dataMap = await exportToMap(userId);
    final jsonString = jsonEncode(dataMap);

    final recordsCount = <String, int>{};
    final data = Map<String, dynamic>.from(dataMap['data'] as Map);
    data.forEach((key, value) {
      recordsCount[key] = (value as List).length;
    });

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('manual_backups')
        .add({
          'label': label,
          'createdAt': FieldValue.serverTimestamp(),
          'recordsCount': recordsCount,
          'dataJson': jsonString,
        });
  }

  Stream<QuerySnapshot> streamCloudBackupPoints(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('manual_backups')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> restoreFromCloudBackup(String userId, String dataJson) async {
    final data = jsonDecode(dataJson) as Map<String, dynamic>;
    await importFromMap(userId, data);
  }

  Future<void> deleteCloudBackupPoint(String userId, String backupId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('manual_backups')
        .doc(backupId)
        .delete();
  }
}
