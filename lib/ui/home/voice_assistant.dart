import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/transaction_controller.dart';
import '../../data/local/category_data.dart';

class VoiceAssistant extends ConsumerStatefulWidget {
  const VoiceAssistant({super.key});

  @override
  ConsumerState<VoiceAssistant> createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends ConsumerState<VoiceAssistant> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechInitialized = false;
  String _text = "Bấm để nói (VD: Ăn phở 45k)";

  // Nên đưa vào file .env hoặc cấu hình bảo mật hơn ghp_...
  final String githubToken = 'MA_GIT';

  static final List<Map<String, dynamic>> _voiceHistory = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  // Khởi tạo Speech ngay khi mở Widget để tránh lag lần đầu
  Future<void> _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Trạng thái Mic: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) => debugPrint('Lỗi Mic: $error'),
    );
    setState(() {});
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setSpeechRate(0.9); // Chậm lại một chút cho tự nhiên
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _listen() async {
    if (_isProcessing) return;

    if (!_isListening) {
      if (!_speechInitialized) {
        await _initSpeech();
      }

      if (_speechInitialized) {
        setState(() {
          _isListening = true;
          _text = "Đang nghe...";
        });

        await _flutterTts.stop();

        _speech.listen(
          localeId: 'vi_VN', // Cố định tiếng Việt
          listenMode: stt.ListenMode.confirmation, // Tối ưu cho ra lệnh
          pauseFor: const Duration(seconds: 3),
          onResult: (val) {
            setState(() {
              if (val.recognizedWords.isNotEmpty) {
                _text = val.recognizedWords;
              }
            });

            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              final messenger = ScaffoldMessenger.of(context);
              final controller = ref.read(transactionControllerProvider);
              _processWithAI(val.recognizedWords, messenger, controller);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // Logic AI xử lý
  Future<void> _processWithAI(String speechText, ScaffoldMessengerState messenger, TransactionController controller) async {
    setState(() => _isProcessing = true);

    String expenseNames = CategoryData.getExpenseCategories().map((c) => c.name).join(", ");
    String incomeNames = CategoryData.getIncomeCategories().map((c) => c.name).join(", ");
    String currentTime = DateFormat('HH:mm').format(DateTime.now());

    _voiceHistory.add({"role": "user", "content": speechText});

    List<Map<String, dynamic>> apiMessages = [
      {
        "role": "system",
        "content": """Bạn là trợ lý tài chính. GIỜ HIỆN TẠI: $currentTime.
        1. Nếu ĐỦ thông tin (tiền + lý do) -> JSON: {"is_transaction": true, "type": "expense", "amount": 50000, "category": "Ăn sáng", "note": "Ăn phở"}.
        2. Category chỉ chọn từ Chi: [$expenseNames] hoặc Thu: [$incomeNames].
        3. Nếu THIẾU thông tin (không rõ tiền hoặc món) -> JSON: {"is_transaction": false, "message": "Câu hỏi lại ngắn gọn"}.
        4. Trò chuyện khác -> JSON: {"is_transaction": false, "message": "Câu trả lời"}."""
      },
      ..._voiceHistory
    ];

    try {
      final response = await http.post(
        Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $githubToken',
        },
        body: jsonEncode({"model": "gpt-4o-mini", "messages": apiMessages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawContent = data['choices'][0]['message']['content'];

        // Trích xuất JSON
        final match = RegExp(r'\{.*\}', dotAll: true).stringMatch(rawContent);
        if (match != null) {
          final tx = jsonDecode(match);

          if (tx['is_transaction'] == true) {
            // LƯU THÀNH CÔNG -> ĐÓNG
            final exactCategory = _getValidCategory(tx['category'] ?? 'Khác', tx['type'] ?? 'expense');
            final newTx = TransactionModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              amount: double.tryParse(tx['amount'].toString()) ?? 0,
              type: tx['type'] ?? 'expense',
              categoryId: exactCategory,
              transactionDate: DateTime.now(),
              note: tx['note'] ?? '',
            );

            await controller.createOrUpdateTransaction(newTx);
            await _speak("Đã ghi nhận ${tx['note']} ${tx['amount']} đồng.");

            _voiceHistory.clear();
            if (mounted) Navigator.pop(context); // Chỉ đóng khi xong việc
          } else {
            // AI HỎI LẠI -> TIẾP TỤC NGHE
            String aiMessage = tx['message'] ?? "Bạn nói rõ hơn được không?";
            _voiceHistory.add({"role": "assistant", "content": aiMessage});

            setState(() => _text = aiMessage);
            await _speak(aiMessage);

            // Tự động bật lại mic sau khi AI nói xong để người dùng trả lời
            Future.delayed(const Duration(milliseconds: 500), () => _listen());
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi AI: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getValidCategory(String aiCategory, String type) {
    final list = type == 'income' ? CategoryData.getIncomeCategories() : CategoryData.getExpenseCategories();
    for (var cat in list) {
      if (cat.name.toLowerCase().contains(aiCategory.toLowerCase())) return cat.name;
    }
    return list.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(
            _isProcessing ? "AI đang xử lý..." : (_isListening ? "Đang lắng nghe..." : "Trợ lý ảo"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),

          GestureDetector(
            onTap: _listen,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  const SizedBox(width: 100, height: 100, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _isListening ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  child: Icon(
                    _isProcessing ? Icons.sync : (_isListening ? Icons.mic : Icons.mic_none),
                    size: 40,
                    color: _isListening ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _isListening ? Colors.black : Colors.grey[600], fontStyle: _isListening ? FontStyle.normal : FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}