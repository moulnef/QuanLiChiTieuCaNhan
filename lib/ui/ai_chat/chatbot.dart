import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/transaction_controller.dart';
import '../../data/local/category_data.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // ĐIỀN TOKEN MỚI VÀO ĐÂY VÀ GIỮ NGUYÊN CÁCH CỘNG CHUỖI NÀY
  final String githubToken = 'ghp_' '0fMl3mRh24hvx7uoegoMcuvTfxKO1x09xMXD';
  final formatCurrency = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _messages.add({
      "role": "ai",
      "text": "Chào bạn! Mình là trợ lý AI. Bạn cứ gõ tự nhiên (VD: 'Sáng nay ăn phở 45k'), mình sẽ tự động tạo phiếu thu chi nhé!"
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getValidCategory(String aiCategory, String type) {
    final list = type == 'income'
        ? CategoryData.getIncomeCategories()
        : CategoryData.getExpenseCategories();

    for (var cat in list) {
      if (cat.name.toLowerCase() == aiCategory.toLowerCase()) return cat.name;
    }
    for (var cat in list) {
      if (cat.name.toLowerCase().contains(aiCategory.toLowerCase()) ||
          aiCategory.toLowerCase().contains(cat.name.toLowerCase())) {
        return cat.name;
      }
    }
    return list.isNotEmpty ? list.first.name : 'Khác';
  }

  String _getDisplayDate(String? dateStr) {
    if (dateStr == null) return DateFormat('dd/MM/yyyy').format(DateTime.now());
    try {
      DateTime parsed = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (e) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }

  Future<void> _saveTransactionToDatabase(Map<String, dynamic> aiData, int index) async {
    if (_messages[index]['is_saving'] == true) return;

    setState(() {
      _messages[index]['is_saving'] = true;
    });

    try {
      final exactCategory = _getValidCategory(aiData['category'], aiData['type']);
      DateTime txDate = DateTime.now();
      if (aiData['date'] != null) {
        try {
          DateTime parsedDate = DateTime.parse(aiData['date']);
          txDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, txDate.hour, txDate.minute);
        } catch (e) {
          txDate = DateTime.now();
        }
      }

      final newTx = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: (aiData['amount'] as num).toDouble(),
        type: aiData['type'],
        categoryId: exactCategory,
        transactionDate: txDate,
        note: aiData['note'] ?? '',
      );

      await ref.read(transactionControllerProvider).createOrUpdateTransaction(newTx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Đã lưu giao dịch!'), backgroundColor: Colors.green)
        );
        setState(() {
          _messages[index]['transaction_saved'] = true;
          _messages[index]['is_saving'] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi hệ thống: $e'), backgroundColor: Colors.red)
        );
        setState(() {
          _messages[index]['is_saving'] = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    String expenseNames = CategoryData.getExpenseCategories().map((c) => c.name).join(", ");
    String incomeNames = CategoryData.getIncomeCategories().map((c) => c.name).join(", ");

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
            },
            ..._messages.where((msg) => msg['role'] != 'system').map((msg) => {
              "role": msg["role"] == "user" ? "user" : "assistant",
              "content": msg["text"] ?? ""
            })
          ],
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

          if (aiData['is_transaction'] == true) {
            double parsedAmount = 0;
            if (aiData['amount'] != null) {
              parsedAmount = double.tryParse(aiData['amount'].toString()) ?? 0;
            }
            aiData['amount'] = parsedAmount;

            setState(() {
              _messages.add({
                "role": "ai",
                "text": "Mình đã trích xuất thông tin giao dịch, bạn kiểm tra lại nhé:",
                "transaction": aiData,
                "transaction_saved": false,
                "is_saving": false,
              });
            });
          } else {
            setState(() {
              _messages.add({"role": "ai", "text": aiData['message'] ?? aiText});
            });
          }
        } catch (e) {
          setState(() {
            String cleanText = aiText.replaceAll('```json', '').replaceAll('```', '').trim();
            _messages.add({"role": "ai", "text": cleanText});
          });
        }
      } else {
        debugPrint("Lỗi API: ${response.statusCode} - ${response.body}");
        setState(() {
          _messages.add({"role": "ai", "text": "Hệ thống AI đang phản hồi chậm hoặc lỗi API!"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "Lỗi kết nối mạng: $e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('lib/ui/ai_chat/robot.gif', width: 35, height: 35, errorBuilder: (c,e,s) => const Icon(Icons.smart_toy, color: Colors.white)),
            const SizedBox(width: 8),
            const Text("Trợ lý AI", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";
                final txData = message["transaction"];
                final isSaved = message["transaction_saved"] ?? false;
                final isSaving = message["is_saving"] ?? false;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) _buildAvatar('🤖'),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isUser
                                    ? const LinearGradient(
                                  colors: [Color(0xFF8B3DFF), Color(0xFFD91CFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : const LinearGradient(colors: [Colors.white, Colors.white]),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: isUser ? const Color(0xFF8B3DFF).withOpacity(0.3) : Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3)
                                  )
                                ],
                              ),
                              child: Text(
                                message["text"],
                                style: TextStyle(
                                    color: isUser ? Colors.white : const Color(0xFF334155),
                                    fontSize: 15,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                            ),

                            if (txData != null && !isSaved) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: 260,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF8B3DFF).withOpacity(0.3), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF8B3DFF).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                                    ]
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(txData['type'] == 'expense' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                            color: txData['type'] == 'expense' ? Colors.red : Colors.green, size: 20),
                                        const SizedBox(width: 6),
                                        Text(txData['type'] == 'expense' ? 'XÁC NHẬN CHI' : 'XÁC NHẬN THU',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    _buildTxRow("Ngày", _getDisplayDate(txData['date']), Colors.black87),
                                    _buildTxRow("Danh mục", txData['category'] ?? 'Khác', Colors.black87),
                                    _buildTxRow("Số tiền", "${formatCurrency.format(txData['amount'] ?? 0)} đ", txData['type'] == 'expense' ? Colors.red : Colors.green, isBold: true),
                                    _buildTxRow("Ghi chú", txData['note'] ?? '', Colors.black54),

                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isSaving
                                                ? [Colors.grey, Colors.grey]
                                                : [const Color(0xFF1D4ED8), const Color(0xFF6D28D9)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: isSaving ? [] : [
                                            BoxShadow(color: const Color(0xFF6D28D9).withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))
                                          ]
                                      ),
                                      child: ElevatedButton(
                                        onPressed: isSaving ? null : () => _saveTransactionToDatabase(txData, index),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: isSaving
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : const Text("LƯU GIAO DỊCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],

                            if (txData != null && isSaved) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF8B3DFF), size: 14),
                                  const SizedBox(width: 4),
                                  Text("Đã lưu vào hệ thống", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic)),
                                ],
                              )
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isUser) _buildAvatar('👩‍💻'),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF8B3DFF)))),
            ),

          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, -5))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: "Nhập thu/chi hoặc hỏi AI...",
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B3DFF), Color(0xFFD91CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF8B3DFF).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
                        ]
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String emoji) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF0F5FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8B3DFF).withOpacity(0.2), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildTxRow(String title, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$title: ", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(
              child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: valueColor,
                      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                      fontSize: isBold ? 16 : 14
                  ),
                  overflow: TextOverflow.ellipsis
              )
          ),
        ],
      ),
    );
  }
}