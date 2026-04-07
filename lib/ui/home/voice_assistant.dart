import 'package:flutter/foundation.dart' show kIsWeb;
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
  String _text = "Sẵn sàng lắng nghe và trò chuyện...";

  //final String githubToken = 'MA_GIT';

  static final List<Map<String, dynamic>> _voiceHistory = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    Future.delayed(const Duration(milliseconds: 500), () => _listen());
  }

  Future<void> _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && !_isProcessing) setState(() => _isListening = false);
        }
      },
      onError: (error) => debugPrint('Lỗi Mic: $error'),
    );
    setState(() {});
  }

  Future<void> _initTts() async {
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.android) {
      await _flutterTts.setEngine("com.google.android.tts");
    }

    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    if (!kIsWeb) {
      await _flutterTts.awaitSpeakCompletion(true);
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _listen() async {
    if (_isProcessing) return;

    if (!_isListening) {
      if (!_speechInitialized) await _initSpeech();

      if (_speechInitialized) {
        setState(() {
          _isListening = true;
          _text = "Đang nghe bạn nói...";
        });

        await _flutterTts.stop();

        _speech.listen(
          localeId: 'vi-VN',
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 6),
          onResult: (val) {
            setState(() {
              if (val.recognizedWords.isNotEmpty) _text = val.recognizedWords;
            });

            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              final messenger = ScaffoldMessenger.of(context);
              final controller = ref.read(transactionControllerProvider.notifier);

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

  Future<void> _processWithAI(String speechText, ScaffoldMessengerState messenger, dynamic controller) async {
    setState(() {
      _isProcessing = true;
      _isListening = false;
      _text = "AI đang suy nghĩ...";
    });

    String expenseNames = CategoryData.getExpenseCategories().map((c) => c.name).join(", ");
    String incomeNames = CategoryData.getIncomeCategories().map((c) => c.name).join(", ");

    // THÊM NGÀY HIỆN TẠI VÀO PROMPT
    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _voiceHistory.add({"role": "user", "content": speechText});

    if (_voiceHistory.length > 12) {
      _voiceHistory.removeRange(0, _voiceHistory.length - 12);
    }

    // ĐỒNG BỘ PROMPT TỪ CHATBOT SANG VOICE
    List<Map<String, dynamic>> apiMessages = [
      {
        "role": "system",
        "content": """Bạn là một trợ lý ảo thông minh, thân thiện và thích trò chuyện về tài chính. HÔM NAY LÀ: $currentDate, THỜI GIAN: $currentTime.
TUYỆT ĐỐI LUÔN TRẢ VỀ ĐỊNH DẠNG JSON HỢP LỆ.

1. BÓC TÁCH GIAO DỊCH (KHI CÓ ĐỦ SỐ TIỀN VÀ MỤC ĐÍCH RÕ RÀNG):
TRẢ VỀ DUY NHẤT JSON:
{"is_transaction": true, "type": "expense" hoặc "income", "amount": 50000, "category": "Ăn sáng", "note": "Ăn phở", "date": "$currentDate", "message": "Đã lưu giao dịch"}
- 'category': CHỈ CHỌN TỪ Chi: [$expenseNames] hoặc Thu: [$incomeNames]. TUYỆT ĐỐI HẠN CHẾ DÙNG 'Khác'.

2. QUY TẮC CHỌN DANH MỤC:
- Ăn uống chung (VD: 'ăn phở'): Nhìn đồng hồ ($currentTime) -> 04:00-10:30 là 'Ăn sáng', 10:31-15:00 là 'Ăn trưa', 15:01-23:59 là 'Ăn tối'.
- Đóng học: Cho bản thân -> 'Học hành', cho con -> 'Học phí'.

3. THIẾU THÔNG TIN (HÃY HỎI LẠI TRONG JSON):
Nếu người dùng nói thiếu 1 trong 2 yếu tố (Số tiền HOẶC Mục đích), KHÔNG TẠO GIAO DỊCH, hãy trả về JSON:
{"is_transaction": false, "message": "<Câu hỏi của bạn>"}
- VD thiếu mục đích: "Nhận 30 triệu" -> Hỏi: "Khoản 30 triệu này là tiền lương, thưởng hay từ đâu vậy bạn?"
- VD thiếu số tiền: "Sáng nay ăn phở" -> Hỏi: "Bạn ăn phở hết bao nhiêu tiền thế?"

4. TRÒ CHUYỆN BÌNH THƯỜNG:
Nếu KHÔNG phải giao dịch, TRẢ VỀ JSON:
{"is_transaction": false, "message": "Câu trả lời của bạn. Tự nhiên, chi tiết, đầy đủ, thân thiện và có thể dài tuỳ ý giống hệt ChatGPT."}"""
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

        String cleanJson = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        int startIndex = cleanJson.indexOf('{');
        int endIndex = cleanJson.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1) {
          final tx = jsonDecode(cleanJson.substring(startIndex, endIndex + 1));

          if (tx['is_transaction'] == true) {
            final exactCategory = _getValidCategory(tx['category'] ?? 'Khác', tx['type'] ?? 'expense');
            double parsedAmount = double.tryParse(tx['amount'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

            // XỬ LÝ NGÀY THÁNG DO AI TRẢ VỀ (VD: "Hôm qua ăn phở" -> AI tự lùi ngày)
            DateTime parsedDate = DateTime.now();
            if (tx['date'] != null) {
              try {
                parsedDate = DateTime.parse(tx['date']);
              } catch (e) {
                parsedDate = DateTime.now(); // Trở về mặc định nếu lỗi parse
              }
            }

            final newTx = TransactionModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              amount: parsedAmount,
              type: tx['type'] ?? 'expense',
              categoryId: exactCategory,
              transactionDate: parsedDate, // DÙNG NGÀY AI PHÂN TÍCH ĐƯỢC
              note: tx['note'] ?? '',
            );

            try {
              await controller.createOrUpdateTransaction(newTx);
            } catch (dbError) {
              String errorMsg = "LỖI LƯU DB: $dbError";
              setState(() => _text = errorMsg);
              messenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
              return;
            }

            _voiceHistory.clear();

            String confirmMsg = tx['message'] ?? "Đã ghi nhận ${tx['note']}";
            setState(() => _text = confirmMsg);
            await _speak(confirmMsg);

            if (kIsWeb) await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.pop(context);

          } else {
            // XỬ LÝ TRÒ CHUYỆN & HỎI LẠI KHI THIẾU THÔNG TIN
            String aiMessage = tx['message'] ?? "Xin lỗi, mình chưa hiểu ý bạn.";
            _voiceHistory.add({"role": "assistant", "content": aiMessage});

            setState(() => _text = aiMessage);
            await _speak(aiMessage);

            // Tính thời gian đợi AI đọc xong (khoảng 75ms / ký tự)
            if (kIsWeb) await Future.delayed(Duration(milliseconds: (aiMessage.length * 75).toInt()));

            if (mounted) {
              setState(() => _isProcessing = false);
              _listen(); // Tự động mở mic lên để nghe người dùng trả lời
            }
          }
        }
      } else {
        setState(() => _text = "Lỗi kết nối API: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _text = "Lỗi xử lý: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getValidCategory(String aiCategory, String type) {
    final list = type == 'income' ? CategoryData.getIncomeCategories() : CategoryData.getExpenseCategories();
    for (var cat in list) {
      if (cat.name.toLowerCase().contains(aiCategory.toLowerCase())) return cat.name;
    }
    return list.isNotEmpty ? list.first.name : "Khác";
  }

  @override
  Widget build(BuildContext context) {
    // Lấy chiều cao màn hình để giới hạn chiều cao hiển thị khung chat
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.8, // Tránh khung chat đẩy lên quá cao
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Text(
            _isProcessing ? "AI đang suy nghĩ..." : (_isListening ? "Đang nghe..." : "Trợ lý Chatbot"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _listen,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  const SizedBox(width: 90, height: 90, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue)),
                CircleAvatar(
                  radius: 35,
                  backgroundColor: _isListening ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  child: Icon(
                    _isProcessing ? Icons.forum : (_isListening ? Icons.mic : Icons.mic_none),
                    size: 35,
                    color: _isProcessing ? Colors.purple : (_isListening ? Colors.red : Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ĐÃ THÊM: Flexible + SingleChildScrollView để chữ có thể dài xuống mà không bị lỗi giao diện
          Flexible(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
              child: SingleChildScrollView(
                child: Text(
                  _text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isListening ? Colors.black : Colors.black87,
                    fontWeight: _isListening ? FontWeight.normal : FontWeight.w500,
                    height: 1.4, // Tạo khoảng cách dòng dễ đọc hơn
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}