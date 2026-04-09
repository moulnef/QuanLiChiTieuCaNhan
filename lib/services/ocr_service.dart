import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, dynamic>?> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text;

      // Lấy số tiền lớn nhất (thường là tổng cộng)
      double? amount = _extractTotalAmount(fullText);

      return {
        'text': fullText,
        'amount': amount,
      };
    } catch (e) {
      debugPrint("Lỗi OCR: $e");
      return null;
    }
  }

  double? _extractTotalAmount(String text) {
    // Regex tìm các con số giống tiền tệ VNĐ (vd: 50.000, 150,000, 50000)
    final RegExp amountRegExp = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?\b|\b\d{4,8}\b');
    final Iterable<RegExpMatch> matches = amountRegExp.allMatches(text);

    List<double> amounts = [];
    for (var match in matches) {
      // Làm sạch chuỗi: loại bỏ dấu phẩy và dấu chấm
      String cleanStr = match.group(0)!.replaceAll('.', '').replaceAll(',', '');
      double? val = double.tryParse(cleanStr);
      if (val != null) {
        amounts.add(val);
      }
    }

    if (amounts.isEmpty) return null;

    // Sắp xếp tăng dần và lấy số lớn nhất
    amounts.sort();
    return amounts.last;
  }

  void dispose() {
    _textRecognizer.close();
  }
}