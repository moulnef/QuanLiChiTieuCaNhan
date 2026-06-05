import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../data/local/category_data.dart';
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
  String _text = 'Bấm vào mic để nói...';

  // Quản lý lịch sử hội thoại của Voice tương tự như Chatbot
  final List<Map<String, dynamic>> _voiceMessages = [];
  final String githubToken = '#';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();

    // Khởi tạo lời chào ban đầu giống Chatbot bằng giọng nói
    _voiceMessages.add({
      "role": "ai",
      "text": "Chào bạn! Mình là trợ lý giọng nói. Bạn đã chi tiêu gì chưa?",
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareSpeech();
      // Bạn có thể mở comment dòng dưới nếu muốn mở lên là AI tự chào luôn
      // await _speak(_voiceMessages.first["text"]);
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        final shouldRelisten = _relistenAfterSpeech;
        _relistenAfterSpeech = false;
        if (shouldRelisten) {
          _listen(); // Tự động bật mic để nhận phản hồi tiếp theo
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
    if (_isInitializingSpeech || _isSpeechReady) return;

    setState(() {
      _isInitializingSpeech = true;
      _text = 'Đang chuẩn bị micro...';
    });

    final hasPermission = await _ensureMicrophonePermission();
    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isInitializingSpeech = false;
        _text = 'Chưa cấp quyền micro.';
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'done' || status == 'notListening') &&
              !_isProcessing) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => debugPrint('Speech error: $error'),
      );

      setState(() {
        _isInitializingSpeech = false;
        _isSpeechReady = available;
        _text = available ? 'Bấm vào mic để nói...' : 'Lỗi khởi tạo Speech.';
      });
    } catch (e) {
      setState(() {
        _isInitializingSpeech = false;
        _isSpeechReady = false;
      });
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }

  Future<void> _listen() async {
    if (_isProcessing) return;

    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    if (!_isSpeechReady) {
      await _prepareSpeech();
      if (!_isSpeechReady) return;
    }

    await _tts.stop();
    setState(() {
      _isListening = true;
      _text = 'Đang nghe...';
    });

    await _speech.listen(
      localeId: 'vi-VN',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (!mounted) return;
        if (result.recognizedWords.isNotEmpty) {
          setState(() => _text = result.recognizedWords);
        }

        if (result.finalResult) {
          setState(() {
            _isListening = false;
            _isProcessing = true;
          });
          // Gửi text nhận diện được lên AI xử lý hội thoại
          await _processWithAI(result.recognizedWords);
        }
      },
    );
  }

  // --- TRÁI TIM XỬ LÝ HỘI THOẠI AI ---
  Future<void> _processWithAI(String userText) async {
    if (userText.trim().isEmpty) {
      setState(() => _isProcessing = false);
      return;
    }

    // Thêm câu nói của user vào hội thoại
    _voiceMessages.add({"role": "user", "text": userText});

    String expenseNames = CategoryData.getExpenseCategories()
        .map((c) => c.name)
        .join(", ");
    String incomeNames = CategoryData.getIncomeCategories()
        .map((c) => c.name)
        .join(", ");
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentTime = DateFormat('HH:mm').format(DateTime.now());

    try {
      final response = await http.post(
        Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $githubToken',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  """Bạn là trợ lý tài chính thông minh qua GIỌNG NÓI. HÔM NAY LÀ: $currentDate, THỜI GIAN: $currentTime.

QUY TẮC KIỂM TRA ĐIỀU KIỆN:
Để tạo được giao dịch, câu nói CỦA NGƯỜI DÙNG PHẢI CÓ ĐỦ 3 YẾU TỐ:
1. MỤC ĐÍCH CỤ THỂ: Mua cái gì? (Ví dụ: "ăn phở", "đổ xăng", "mua quần áo"). Không chấp nhận từ chung chung.
2. SỐ TIỀN: Con số cụ thể (30k, 50 nghìn).
3. THỜI GIAN: Phải nói rõ buổi hoặc giờ giấc hoặc ngữ cảnh ngày (hôm nay, sáng nay, tối qua).

HÀNH ĐỘNG 1: THIẾU THÔNG TIN -> PHẢI HỎI LẠI TRỰC TIẾP, NGẮN GỌN (Dùng cho môi trường Giọng nói)
Trả về JSON hỏi lại:
{"is_transaction": false, "message": "<Câu hỏi ngắn gọn để người dùng trả lời bằng giọng nói>"}
Ví dụ: Thiếu tiền -> "Món đó bạn chi hết bao nhiêu tiền thế?"

HÀNH ĐỘNG 2: ĐỦ THÔNG TIN -> TẠO GIAO DỊCH
Trả về JSON:
{"is_transaction": true, "type": "expense", "amount": 30000, "category": "Ăn sáng", "note": "Ăn phở", "date": "$currentDate", "message": "Đã lưu ăn phở ba mươi nghìn đồng."}
- 'category': Chọn từ Chi: [$expenseNames] hoặc Thu: [$incomeNames].

HÀNH ĐỘNG 3: TRÒ CHUYỆN BÌNH THƯỜNG
Trả về JSON:
{"is_transaction": false, "message": "<Câu trả lời ngắn gọn, thân thiện>"}""",
            },
            ..._voiceMessages.map(
              (msg) => {
                "role": msg["role"] == "user" ? "user" : "assistant",
                "content": msg["text"] ?? "",
              },
            ),
          ],
        }),
      );

      if (response.statusCode == 200) {
        String aiText = jsonDecode(
          utf8.decode(response.bodyBytes),
        )['choices'][0]['message']['content'];

        // Trích xuất JSON tương tự ChatbotScreen
        int startIndex = aiText.indexOf('{');
        int endIndex = aiText.lastIndexOf('}');
        String potentialJson = (startIndex != -1 && endIndex != -1)
            ? aiText.substring(startIndex, endIndex + 1)
            : aiText.replaceAll('```json', '').replaceAll('```', '').trim();

        final aiData = jsonDecode(potentialJson);

        if (aiData['is_transaction'] == true) {
          // TRƯỜNG HỢP 1: Đủ thông tin và lưu DB luôn
          final exactCategory = _getValidCategory(
            aiData['category'],
            aiData['type'],
          );
          final amount = double.tryParse(aiData['amount'].toString()) ?? 0.0;

          final transaction = TransactionModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: amount,
            type: aiData['type'],
            categoryId: exactCategory,
            categoryName: exactCategory,
            transactionDate: DateTime.now(),
            note: aiData['note'] ?? '',
          );

          await ref
              .read(transactionControllerProvider)
              .createOrUpdateTransaction(transaction);

          String speechReply =
              aiData['message'] ?? 'Đã lưu giao dịch hoàn tất.';
          _voiceMessages.add({"role": "ai", "text": speechReply});

          setState(() {
            _isProcessing = false;
            _text = speechReply;
          });

          // Nói thông báo thành công và tắt giao diện sau đó
          await _speak(speechReply, relisten: false);
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          // TRƯỜNG HỢP 2 & 3: Thiếu thông tin cần hỏi lại hoặc nói chuyện thông thường
          String speechReply = aiData['message'] ?? 'Mình chưa hiểu ý bạn lắm.';
          _voiceMessages.add({"role": "ai", "text": speechReply});

          setState(() {
            _isProcessing = false;
            _text = speechReply;
          });

          // THẦN CHÚ: relisten: true -> Sau khi TTS đọc xong câu hỏi, Mic sẽ tự bật lại!
          await _speak(speechReply, relisten: true);
        }
      } else {
        throw Exception("API Error");
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _text = 'Kết nối AI gián đoạn. Thử lại nhé!';
      });
      await _speak('Kết nối AI gián đoạn. Thử lại nhé!', relisten: false);
    }
  }

  String _getValidCategory(String aiCategory, String type) {
    final list = type == 'income'
        ? CategoryData.getIncomeCategories()
        : CategoryData.getExpenseCategories();
    for (var cat in list) {
      if (cat.name.toLowerCase() == aiCategory.toLowerCase()) return cat.name;
    }
    return list.isNotEmpty ? list.first.name : 'Khác';
  }

  @override
  Widget build(BuildContext context) {
    // Giữ nguyên giao diện UI đẹp đẽ của bạn
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
                ? 'AI đang suy nghĩ...'
                : (_isListening
                      ? 'Đang nghe bạn nói...'
                      : 'Trợ lý giọng nói AI'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 25),
          CircleAvatar(
            radius: 42,
            backgroundColor: _isProcessing
                ? Colors.grey.withOpacity(0.1)
                : (_isListening
                      ? Colors.red.withOpacity(0.15)
                      : const Color(0xFF8B3DFF).withOpacity(0.1)),
            child: IconButton(
              iconSize: 44,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF8B3DFF),
                      ),
                    )
                  : Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? Colors.red
                          : const Color(0xFF8B3DFF),
                    ),
              onPressed: _isProcessing ? null : _listen,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
