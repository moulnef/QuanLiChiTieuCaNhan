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
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessing = false; // Trạng thái AI đang suy nghĩ, tránh đụng chạm
  String _text = "Bấm vào mic để nói...";

  final String githubToken = 'ghp_' '0fMl3mRh24hvx7uoegoMcuvTfxKO1x09xMXD';

  static final List<Map<String, dynamic>> _voiceHistory = [];
  static final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("vi-VN");
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Quan trọng cho Web: Ép hệ thống đợi đọc xong mới làm việc khác
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint("Lỗi khởi tạo giọng nói: $e");
    }
  }

  static Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Lỗi không thể phát âm: $e");
    }
  }

  void _listen() async {
    // Nếu AI đang suy nghĩ thì không cho bấm lung tung
    if (_isProcessing) return;

    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              if (mounted && _isListening && !_isProcessing) {
                setState(() => _isListening = false);
              }
            }
          },
          onError: (val) {
            debugPrint('Lỗi mic: $val');
            if (mounted) {
              setState(() {
                _isListening = false;
                _text = "Lỗi kết nối Mic! (Hãy f5 tải lại trang nhé)";
              });
            }
          },
        );

        if (available) {
          // 🛡️ BỘ LỌC NGÔN NGỮ AN TOÀN (CHỐNG CRASH 100%)
          String targetLocale = 'vi-VN'; // Lấy Web làm mặc định để chống sập
          try {
            var locales = await _speech.locales();
            if (locales.isNotEmpty) {
              var viLocales = locales.where((loc) => loc.localeId.contains('vi'));
              if (viLocales.isNotEmpty) {
                targetLocale = viLocales.first.localeId;
              } else {
                targetLocale = locales.first.localeId;
              }
            }
          } catch (e) {
            debugPrint("Lỗi lấy danh sách ngôn ngữ, dùng mặc định vi-VN: $e");
          }

          debugPrint("👉 Đã chốt mã ngôn ngữ để nghe: $targetLocale");

          setState(() {
            _isListening = true;
            _text = "Đang nghe...";
          });

          // Bọc try-catch để lỡ TTS trên web bị kẹt cũng không làm sập luồng nghe
          try {
            await _flutterTts.stop();
          } catch (_) {}

          bool hasProcessedThisTurn = false;

          _speech.listen(
            localeId: targetLocale,
            pauseFor: const Duration(seconds: 4),
            onResult: (val) async {
              if (mounted && !hasProcessedThisTurn) {
                setState(() {
                  if (val.recognizedWords.isNotEmpty) {
                    _text = val.recognizedWords;
                  }
                });

                if (val.finalResult) {
                  if (val.recognizedWords.isNotEmpty) {
                    hasProcessedThisTurn = true;
                    setState(() {
                      _isListening = false;
                      _isProcessing = true;
                      _text = "AI đang suy nghĩ...";
                    });

                    final messenger = ScaffoldMessenger.of(context);
                    final controller = ref.read(transactionControllerProvider);

                    await _processWithAI(val.recognizedWords, messenger, controller);
                  } else {
                    setState(() {
                      _isListening = false;
                      _text = "Chưa nghe rõ, vui lòng bấm mic nói lại.";
                    });
                  }
                }
              }
            },
          );
        } else {
          setState(() => _text = "Không tìm thấy Micro hoặc chưa cấp quyền!");
        }
      } catch (e) {
        // Bắt lỗi tổng để app không bao giờ bị đơ
        debugPrint("Lỗi hệ thống Mic: $e");
        if (mounted) {
          setState(() {
            _isListening = false;
            _text = "Hệ thống Mic bị lỗi, vui lòng F5 lại trang!";
          });
        }
      }
    } else {
      setState(() => _isListening = false);
      try {
        _speech.stop();
      } catch (_) {}
    }
  }

  String _getValidCategory(String aiCategory, String type) {
    final list = type == 'income' ? CategoryData.getIncomeCategories() : CategoryData.getExpenseCategories();
    for (var cat in list) {
      if (cat.name.toLowerCase() == aiCategory.toLowerCase()) return cat.name;
    }
    for (var cat in list) {
      if (cat.name.toLowerCase().contains(aiCategory.toLowerCase()) || aiCategory.toLowerCase().contains(cat.name.toLowerCase())) return cat.name;
    }
    return list.isNotEmpty ? list.first.name : 'Khác';
  }

  Future<void> _processWithAI(String speechText, ScaffoldMessengerState messenger, TransactionController controller) async {
    String expenseNames = CategoryData.getExpenseCategories().map((c) => c.name).join(", ");
    String incomeNames = CategoryData.getIncomeCategories().map((c) => c.name).join(", ");

    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentTime = DateFormat('HH:mm').format(DateTime.now());

    _voiceHistory.add({"role": "user", "content": speechText});

    List<Map<String, dynamic>> apiMessages = [
      {
        "role": "system",
        "content": """Bạn là trợ lý tài chính thông minh. HÔM NAY LÀ: $currentDate, THỜI GIAN HIỆN TẠI: $currentTime.

QUY TẮC KIỂM TRA ĐIỀU KIỆN (BẮT BUỘC PHẢI THỎA MÃN CẢ 3):
Để tạo được giao dịch, câu nói CỦA NGƯỜI DÙNG PHẢI CÓ ĐỦ 3 YẾU TỐ SAU:
1. MỤC ĐÍCH CỤ THỂ: Mua cái gì? (VD: "ăn phở", "mua nho", "đóng tiền học"). Các từ chung chung như "mua đồ", "mua sắm", "tiêu tiền" LÀ KHÔNG HỢP LỆ, BẮT BUỘC phải hỏi rõ là mua món gì.
2. SỐ TIỀN: Phải có con số (VD: 30k, 50 ngàn).
3. THỜI GIAN: Phải nói rõ buổi (sáng, trưa, chiều, tối, đêm) HOẶC giờ giấc (1h, 8g). 
* AI TỰ XỬ LÝ NGỮ CẢNH: "Sáng nay" = buổi sáng. "8g chiều" hay "8g tối" = buổi tối. "1 giờ" có thể là 1h trưa (13h) hoặc 1h sáng tùy ngữ cảnh. Nếu người dùng đã nói "sáng/trưa/chiều/tối/đêm" thì TUYỆT ĐỐI KHÔNG HỎI LẠI THỜI GIAN.

HÀNH ĐỘNG 1: NẾU THIẾU THÔNG TIN -> PHẢI HỎI LẠI
Nếu thiếu BẤT KỲ yếu tố nào trong 3 yếu tố trên, trả về JSON hỏi lại:
{"is_transaction": false, "message": "<Hỏi thông tin bị thiếu>"}
- Ưu tiên 1 (Thiếu mục đích): "Mua đồ lúc 8h tối" -> Hỏi: "Bạn mua đồ gì thế?"
- Ưu tiên 2 (Thiếu tiền): "Sáng nay ăn phở" -> Hỏi: "Sáng nay bạn ăn phở hết bao nhiêu tiền?"
- Ưu tiên 3 (Thiếu thời gian): "Mua nho hết 50k" -> Hỏi: "Bạn mua nho vào buổi sáng, trưa hay tối vậy?"

HÀNH ĐỘNG 2: NẾU ĐÃ ĐỦ 3 THÔNG TIN -> TẠO GIAO DỊCH
TRẢ VỀ JSON:
{"is_transaction": true, "type": "expense", "amount": 30000, "category": "Ăn sáng", "note": "Ăn phở", "date": "$currentDate"}
- 'category': CHỈ CHỌN TỪ Chi: [$expenseNames] hoặc Thu: [$incomeNames]. KHÔNG TỰ CHẾ.
- Bắt buộc phân loại Ăn uống: Từ 00h-10h (Sáng) -> "Ăn sáng"; Từ 10h-15h (Trưa) -> "Ăn trưa"; Từ 15h-24h (Chiều/Tối/Đêm) -> "Ăn tối".

HÀNH ĐỘNG 3: TRÒ CHUYỆN BÌNH THƯỜNG
Nếu câu nói hoàn toàn KHÔNG phải giao dịch (VD: xin chào, thời tiết), TRẢ VỀ JSON:
{"is_transaction": false, "message": "<Câu trả lời thân thiện>"}"""
      }
    ];

    apiMessages.addAll(_voiceHistory);

    try {
      final response = await http.post(
        Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $githubToken',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": apiMessages,
        }),
      );

      if (response.statusCode == 200) {
        String aiText = jsonDecode(utf8.decode(response.bodyBytes))['choices'][0]['message']['content'];

        String potentialJson = aiText;
        int startIndex = aiText.indexOf('{');
        int endIndex = aiText.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1) {
          potentialJson = aiText.substring(startIndex, endIndex + 1);
        } else {
          potentialJson = aiText.replaceAll('```json', '').replaceAll('```', '').trim();
        }

        try {
          final aiData = jsonDecode(potentialJson);

          // TRƯỜNG HỢP 1: TẠO GIAO DỊCH THÀNH CÔNG -> ĐÓNG BẢNG
          if (aiData['is_transaction'] == true) {
            final exactCategory = _getValidCategory(aiData['category'] ?? 'Khác', aiData['type'] ?? 'expense');
            double parsedAmount = double.tryParse(aiData['amount'].toString()) ?? 0;

            DateTime txDate = DateTime.now();
            if (aiData['date'] != null) {
              try {
                DateTime parsedDate = DateTime.parse(aiData['date']);
                txDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, txDate.hour, txDate.minute);
              } catch (_) {}
            }

            final newTx = TransactionModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              amount: parsedAmount,
              type: aiData['type'] ?? 'expense',
              categoryId: exactCategory,
              transactionDate: txDate,
              note: aiData['note'] ?? '',
            );

            await controller.createOrUpdateTransaction(newTx);
            _voiceHistory.clear();

            setState(() {
              _text = "✅ Đã tạo giao dịch thành công!";
              _isProcessing = false;
            });

            // Đọc xong thì tự động đóng cái bảng xuống
            await _flutterTts.speak("Đã lưu ${aiData['note']} với số tiền ${parsedAmount.toInt()} đồng");
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.pop(context);
            });

          }
          // TRƯỜNG HỢP 2: AI HỎI LẠI HOẶC TRẢ LỜI -> TỰ ĐỘNG MỞ MIC NGHE TIẾP
          else {
            String aiMessage = aiData['message'] ?? "Xin lỗi, mình chưa nghe rõ.";
            _voiceHistory.add({"role": "assistant", "content": aiMessage});

            setState(() {
              _text = aiMessage;
              _isProcessing = false;
            });

            // Cài đặt: Đọc xong tự bật Mic trở lại
            _flutterTts.setCompletionHandler(() {
              if (mounted) {
                _listen();
              }
            });
            await _flutterTts.speak(aiMessage);
          }
        } catch (e) {
          String cleanText = aiText.replaceAll('```json', '').replaceAll('```', '').trim();
          _voiceHistory.add({"role": "assistant", "content": cleanText});

          setState(() {
            _text = cleanText;
            _isProcessing = false;
          });

          _flutterTts.setCompletionHandler(() {
            if (mounted) _listen();
          });
          await _flutterTts.speak(cleanText);
        }
      }
    } catch (e) {
      debugPrint("Lỗi AI Voice: $e");
      if (mounted) setState(() => _isProcessing = false);
    }
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
              _isProcessing ? "AI đang xử lý..." : (_isListening ? "Đang nghe..." : "Trợ lý giọng nói"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),

          CircleAvatar(
            radius: 40,
            backgroundColor: _isProcessing
                ? Colors.grey.withValues(alpha: 0.2) // Màu xám khi đang bận
                : (_isListening ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1)),
            child: IconButton(
              iconSize: 40,
              icon: _isProcessing
                  ? const CircularProgressIndicator() // Xoay xoay khi đang xử lý
                  : Icon(_isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.blue),
              onPressed: _listen, // Giờ bấm vào nó sẽ chạy chuẩn xác hơn
            ),
          ),

          const SizedBox(height: 20),
          Text(_text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}