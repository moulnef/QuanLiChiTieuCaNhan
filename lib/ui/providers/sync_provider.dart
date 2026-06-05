import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  SyncStatus _status = SyncStatus.idle;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;
  String? _errorMessage;

  SyncStatus get status => _status;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _status != SyncStatus.offline;

  final SyncService _syncService = SyncService();

  SyncProvider() {
    _init();
    _syncService.syncEventStream.listen((event) {
      _status = event.status;
      if (event.error != null) {
        _errorMessage = event.error!.replaceAll('Exception: ', '');
      } else {
        _errorMessage = null;
      }
      loadPendingCount();
      loadLastSyncTime();
      notifyListeners();
    });
  }

  Future<void> _init() async {
    await loadPendingCount();
    await loadLastSyncTime();
    await checkConnectivity();
  }

  Future<void> checkConnectivity() async {
    if (kIsWeb) return;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = _checkHasConnection(results);
      if (!hasConnection) {
        _status = SyncStatus.offline;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadPendingCount() async {
    if (kIsWeb) {
      _pendingCount = 0;
      return;
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    _pendingCount = await _syncService.getPendingCount(currentUid);
    notifyListeners();
  }

  Future<void> loadLastSyncTime() async {
    _lastSyncTime = await _syncService.getLastSyncTime();
    notifyListeners();
  }

  Future<SyncResult?> syncNow(String userId) async {
    if (kIsWeb || userId.isEmpty) return null;

    // Check connectivity first
    final results = await Connectivity().checkConnectivity();
    final hasConnection = _checkHasConnection(results);
    if (!hasConnection) {
      _status = SyncStatus.offline;
      _errorMessage = 'Không có kết nối mạng';
      notifyListeners();
      throw Exception('Không có kết nối mạng');
    }

    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.syncNow(userId);
      _status = SyncStatus.success;
      await loadPendingCount();
      await loadLastSyncTime();
      return result;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  bool _checkHasConnection(dynamic results) {
    if (results is List) {
      return results.any((result) => result != ConnectivityResult.none);
    } else {
      return results != ConnectivityResult.none;
    }
  }
}
