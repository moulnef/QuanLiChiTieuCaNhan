import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/local/category_data.dart';
import '../../domain/model/category_model.dart';
import '../../domain/model/transaction_model.dart';
import '../transaction/transaction_controller.dart';

class VoiceAssistant extends ConsumerStatefulWidget {
  const VoiceAssistant({super.key});

  @override
  ConsumerState<VoiceAssistant> createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends ConsumerState<VoiceAssistant> {
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitializingSpeech = false;
  bool _isSpeechReady = false;
  bool _relistenAfterSpeech = false;
  String _text = 'Bam vao mic de noi...';
  _PendingDraft? _pendingDraft;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareSpeech();
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) {
          return;
        }
        final shouldRelisten = _relistenAfterSpeech;
        _relistenAfterSpeech = false;
        if (shouldRelisten) {
          _listen();
        }
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String message, {bool relisten = false}) async {
    _relistenAfterSpeech = relisten;
    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _relistenAfterSpeech = false;
    }
  }

  Future<void> _prepareSpeech() async {
    if (_isInitializingSpeech || _isSpeechReady) {
      return;
    }

    setState(() {
      _isInitializingSpeech = true;
      _text = 'Dang chuan bi micro...';
    });

    final hasPermission = await _ensureMicrophonePermission();
    if (!mounted) {
      return;
    }

    if (!hasPermission) {
      setState(() {
        _isInitializingSpeech = false;
        _text =
            'Ban chua cap quyen micro. Hay cho phep micro de su dung tro ly giong noi.';
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          if ((status == 'done' || status == 'notListening') &&
              !_isProcessing) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (!mounted) {
            return;
          }
          setState(() {
            _isListening = false;
            _isProcessing = false;
            _isSpeechReady = false;
            _text = 'Khong the su dung micro. Hay kiem tra quyen truy cap.';
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingSpeech = false;
        _isSpeechReady = available;
        _text = available
            ? 'Bam vao mic de noi...'
            : 'Khong tim thay dich vu nhan dien giong noi tren thiet bi.';
      });
    } catch (e) {
      debugPrint('Speech init error: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializingSpeech = false;
        _isSpeechReady = false;
        _text = 'Khoi tao micro that bai. Hay thu lai.';
      });
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final requested = await Permission.microphone.request();
    if (requested.isGranted) {
      return true;
    }

    if (requested.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  Future<void> _listen() async {
    if (_isProcessing) {
      return;
    }

    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    try {
      final hasPermission = await _ensureMicrophonePermission();
      if (!mounted) {
        return;
      }

      if (!hasPermission) {
        setState(() {
          _text =
              'Ban chua cap quyen micro. Hay cho phep micro trong cai dat ung dung.';
        });
        return;
      }

      if (!_isSpeechReady) {
        await _prepareSpeech();
        if (!mounted || !_isSpeechReady) {
          return;
        }
      }

      var localeId = 'vi-VN';
      try {
        final locales = await _speech.locales();
        final vietnamese = locales.where(
          (item) => item.localeId.contains('vi'),
        );
        if (vietnamese.isNotEmpty) {
          localeId = vietnamese.first.localeId;
        } else if (locales.isNotEmpty) {
          localeId = locales.first.localeId;
        }
      } catch (e) {
        debugPrint('Locale lookup error: $e');
      }

      await _tts.stop();
      setState(() {
        _isListening = true;
        _text = 'Dang nghe...';
      });

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) async {
          if (!mounted) {
            return;
          }

          if (result.recognizedWords.isNotEmpty) {
            setState(() {
              _text = result.recognizedWords;
            });
          }

          if (!result.finalResult) {
            return;
          }

          setState(() {
            _isListening = false;
            _isProcessing = true;
          });

          await _handleRecognizedText(result.recognizedWords);
        },
      );
    } catch (e) {
      debugPrint('Listen error: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _isProcessing = false;
        _text = 'Micro gap loi. Hay thu lai.';
      });
    }
  }

  Future<void> _handleRecognizedText(String speechText) async {
    final parsed = _parseVoiceCommand(speechText);

    if (!parsed.canSave) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _text = parsed.message;
      });
      await _speak(parsed.message, relisten: parsed.relisten);
      return;
    }

    final controller = ref.read(transactionControllerProvider);
    final category =
        CategoryData.findByName(parsed.categoryName) ??
        CategoryData.getAllCategories()
            .where((item) => item.type == parsed.type)
            .firstOrNull;

    try {
      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: parsed.amount!,
        type: parsed.type,
        categoryId: category?.id ?? parsed.categoryName,
        categoryName: category?.name ?? parsed.categoryName,
        transactionDate: DateTime.now(),
        note: parsed.note,
      );

      await controller.createOrUpdateTransaction(transaction);
      _pendingDraft = null;

      if (!mounted) {
        return;
      }

      final amountText = parsed.amount!.toStringAsFixed(0);
      final success =
          'Da luu ${parsed.note} - $amountText dong vao muc ${parsed.categoryName}.';
      setState(() {
        _isProcessing = false;
        _text = success;
      });
      await _speak(success);

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      debugPrint('Save voice transaction error: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _text = 'Khong the luu giao dich. Hay thu lai.';
      });
      await _speak('Khong the luu giao dich. Hay thu lai.');
    }
  }

  _ParsedVoiceCommand _parseVoiceCommand(String rawText) {
    final original = rawText.trim();
    final normalized = _normalize(original);

    if (normalized.isEmpty) {
      return const _ParsedVoiceCommand.message(
        'Minh chua nghe ro. Hay noi lai giao dich cua ban.',
        relisten: true,
      );
    }

    if (_containsAny(normalized, const ['huy', 'thoat', 'dung lai'])) {
      _pendingDraft = null;
      return const _ParsedVoiceCommand.message('Da huy lenh hien tai.');
    }

    if (_pendingDraft != null) {
      final amount = _extractAmount(normalized);
      if (amount == null || amount <= 0) {
        return const _ParsedVoiceCommand.message(
          'Minh van chua nghe ro so tien. Ban hay noi vi du 50 nghin hoac 2 trieu.',
          relisten: true,
        );
      }

      final draft = _pendingDraft!;
      return _ParsedVoiceCommand.save(
        amount: amount,
        type: draft.type,
        categoryName: draft.categoryName,
        note: draft.note,
        message: 'Dang luu giao dich...',
      );
    }

    if (_containsAny(normalized, const [
      'xin chao',
      'hello',
      'hi',
      'ban la ai',
    ])) {
      return const _ParsedVoiceCommand.message(
        'Minh co the ghi giao dich cho ban. Hay noi vi du an sang 50 nghin.',
        relisten: true,
      );
    }

    final type = _detectTransactionType(normalized);
    final amount = _extractAmount(normalized);
    final category = _detectCategory(normalized, type);
    final note = _buildNote(original, category?.name);

    if (amount == null || amount <= 0) {
      if (category == null) {
        return const _ParsedVoiceCommand.message(
          'Hay noi day du hon, vi du an trua 50 nghin, do xang 100 nghin, hoac nhan luong 10 trieu.',
          relisten: true,
        );
      }

      _pendingDraft = _PendingDraft(
        type: type,
        categoryName: category.name,
        note: note,
      );
      return _ParsedVoiceCommand.message(
        'Minh da hieu giao dich ${category.name}. Ban cho minh biet so tien nhe.',
        relisten: true,
      );
    }

    final resolvedCategory =
        category?.name ?? (type == 'income' ? 'Tien vao' : 'Tien ra');

    return _ParsedVoiceCommand.save(
      amount: amount,
      type: type,
      categoryName: resolvedCategory,
      note: note,
      message: 'Dang luu giao dich...',
    );
  }

  String _detectTransactionType(String normalized) {
    const incomeKeywords = [
      'nhan luong',
      'luong',
      'thuong',
      'thu nhap',
      'ban duoc',
      'ban hang',
      'duoc tang',
      'duoc cho',
      'lai ngan hang',
      'lai tiet kiem',
      'tien vao',
      'thu duoc',
    ];

    return _containsAny(normalized, incomeKeywords) ? 'income' : 'expense';
  }

  CategoryModel? _detectCategory(String normalized, String type) {
    final categories = type == 'income'
        ? CategoryData.getIncomeCategories()
        : CategoryData.getExpenseCategories();

    String? targetName;
    final mealCategory = _detectMealCategory(normalized);
    if (mealCategory != null) {
      targetName = mealCategory;
    } else if (_containsAny(normalized, const ['ca phe', 'cafe', 'tra sua'])) {
      targetName = 'Cafe';
    } else if (_containsAny(normalized, const [
      'cho',
      'sieu thi',
      'rau',
      'thuc pham',
    ])) {
      targetName = 'Đi chợ/Siêu thị';
    } else if (_containsAny(normalized, const ['xang', 'do xang'])) {
      targetName = 'Xăng xe';
    } else if (_containsAny(normalized, const [
      'grab',
      'taxi',
      'xe om',
      'thue xe',
    ])) {
      targetName = 'Taxi/Thuê xe';
    } else if (_containsAny(normalized, const ['gui xe'])) {
      targetName = 'Gửi xe';
    } else if (_containsAny(normalized, const ['dien nuoc', 'tien dien'])) {
      targetName = 'Điện';
    } else if (_containsAny(normalized, const [
      'nuoc sinh hoat',
      'tien nuoc',
    ])) {
      targetName = 'Nước';
    } else if (_containsAny(normalized, const ['internet', 'wifi'])) {
      targetName = 'Internet';
    } else if (_containsAny(normalized, const ['dien thoai', 'nap the'])) {
      targetName = 'Điện thoại';
    } else if (_containsAny(normalized, const ['quan ao', 'ao quan'])) {
      targetName = 'Quần áo';
    } else if (_containsAny(normalized, const ['giay', 'dep'])) {
      targetName = 'Giày dép';
    } else if (_containsAny(normalized, const ['xem phim', 'phim'])) {
      targetName = 'Phim ảnh';
    } else if (_containsAny(normalized, const [
      'giai tri',
      'vui choi',
      'karaoke',
    ])) {
      targetName = 'Vui chơi giải trí';
    } else if (_containsAny(normalized, const ['thue nha'])) {
      targetName = 'Thuê nhà';
    } else if (_containsAny(normalized, const ['hoc phi'])) {
      targetName = 'Học phí';
    } else if (_containsAny(normalized, const ['sach vo', 'mua sach'])) {
      targetName = 'Sách vở';
    } else if (_containsAny(normalized, const ['kham benh', 'bac si'])) {
      targetName = 'Khám chữa bệnh';
    } else if (_containsAny(normalized, const ['thuoc', 'mua thuoc'])) {
      targetName = 'Thuốc men';
    } else if (_containsAny(normalized, const ['the thao', 'gym'])) {
      targetName = 'Thể thao';
    } else if (type == 'income' && _containsAny(normalized, const ['luong'])) {
      targetName = 'Lương';
    } else if (type == 'income' && _containsAny(normalized, const ['thuong'])) {
      targetName = 'Thưởng';
    } else if (type == 'income' &&
        _containsAny(normalized, const ['lai tiet kiem', 'lai ngan hang'])) {
      targetName = 'Lãi tiết kiệm';
    } else if (type == 'income' && _containsAny(normalized, const ['lai'])) {
      targetName = 'Tiền lãi';
    } else if (type == 'income' &&
        _containsAny(normalized, const ['duoc tang', 'duoc cho'])) {
      targetName = 'Được cho/tặng';
    }

    if (targetName != null) {
      return categories.where((item) => item.name == targetName).firstOrNull;
    }

    return null;
  }

  String? _detectMealCategory(String normalized) {
    if (!_containsAny(normalized, const [
      'an',
      'pho',
      'com',
      'bun',
      'mi tom',
      'banh mi',
      'do an',
      'an sang',
      'an trua',
      'an toi',
      'uong',
    ])) {
      return null;
    }

    if (_containsAny(normalized, const ['ca phe', 'cafe', 'tra sua'])) {
      return null;
    }

    if (_containsAny(normalized, const ['sang', 'an sang', 'buoi sang'])) {
      return 'Ăn sáng';
    }
    if (_containsAny(normalized, const ['trua', 'an trua', 'buoi trua'])) {
      return 'Ăn trưa';
    }
    if (_containsAny(normalized, const [
      'toi',
      'dem',
      'chieu',
      'an toi',
      'buoi toi',
    ])) {
      return 'Ăn tối';
    }

    final hour = DateTime.now().hour;
    if (hour < 10) {
      return 'Ăn sáng';
    }
    if (hour < 15) {
      return 'Ăn trưa';
    }
    return 'Ăn tối';
  }

  double? _extractAmount(String normalized) {
    final matches = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(ty|trieu|tr|cu|k|nghin|ngan|dong|vnd)?',
    ).allMatches(normalized).toList();

    if (matches.isEmpty) {
      return null;
    }

    RegExpMatch? selected;
    for (final match in matches) {
      final unit = match.group(2) ?? '';
      if (unit.isNotEmpty) {
        selected = match;
      }
    }
    selected ??= matches.last;

    final rawNumber = selected.group(1);
    if (rawNumber == null) {
      return null;
    }

    final baseValue = double.tryParse(rawNumber.replaceAll(',', '.'));
    if (baseValue == null || baseValue <= 0) {
      return null;
    }

    final unit = selected.group(2) ?? '';
    var multiplier = 1.0;
    if (unit == 'k' || unit == 'nghin' || unit == 'ngan') {
      multiplier = 1000;
    } else if (unit == 'tr' || unit == 'trieu' || unit == 'cu') {
      multiplier = 1000000;
    } else if (unit == 'ty') {
      multiplier = 1000000000;
    }

    return (baseValue * multiplier).roundToDouble();
  }

  String _buildNote(String original, String? categoryName) {
    final cleaned = original.trim();
    if (cleaned.isEmpty) {
      return categoryName ?? 'Giao dich bang giong noi';
    }
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _normalize(String input) {
    final lower = input.toLowerCase().trim();
    final map = <String, String>{
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(map[char] ?? char);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _containsAny(String input, List<String> keywords) {
    for (final keyword in keywords) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isProcessing
                ? 'Dang xu ly...'
                : (_isInitializingSpeech
                      ? 'Dang khoi tao micro...'
                      : (_isListening ? 'Dang nghe...' : 'Tro ly giong noi')),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: _isProcessing
                ? Colors.grey.withValues(alpha: 0.2)
                : (_isListening
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.1)),
            child: IconButton(
              iconSize: 40,
              icon: (_isProcessing || _isInitializingSpeech)
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.blue,
                    ),
              onPressed: (_isProcessing || _isInitializingSpeech)
                  ? null
                  : _listen,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (_pendingDraft != null) ...[
            const SizedBox(height: 12),
            Text(
              'Dang cho so tien cho muc ${_pendingDraft!.categoryName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingDraft {
  const _PendingDraft({
    required this.type,
    required this.categoryName,
    required this.note,
  });

  final String type;
  final String categoryName;
  final String note;
}

class _ParsedVoiceCommand {
  const _ParsedVoiceCommand._({
    required this.canSave,
    required this.message,
    this.amount,
    this.type = 'expense',
    this.categoryName = '',
    this.note = '',
    this.relisten = false,
  });

  const _ParsedVoiceCommand.message(String message, {bool relisten = false})
    : this._(canSave: false, message: message, relisten: relisten);

  const _ParsedVoiceCommand.save({
    required double amount,
    required String type,
    required String categoryName,
    required String note,
    required String message,
  }) : this._(
         canSave: true,
         amount: amount,
         type: type,
         categoryName: categoryName,
         note: note,
         message: message,
       );

  final bool canSave;
  final double? amount;
  final String type;
  final String categoryName;
  final String note;
  final String message;
  final bool relisten;
}
