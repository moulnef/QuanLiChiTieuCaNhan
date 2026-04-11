import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<Map<String, dynamic>?> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final fullText = recognizedText.text;
      final amount = _extractTotalAmount(fullText);

      return <String, dynamic>{
        'text': fullText,
        'amount': amount,
      };
    } catch (e) {
      debugPrint('Lỗi OCR: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> scanReceiptPath(String path) {
    return scanReceipt(File(path));
  }

  double? _extractTotalAmount(String text) {
    final amountRegExp = RegExp(
      r'\b\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?\b|\b\d{4,8}\b',
    );

    final amounts = <double>[];
    for (final match in amountRegExp.allMatches(text)) {
      final cleanStr = match.group(0)!.replaceAll('.', '').replaceAll(',', '');
      final value = double.tryParse(cleanStr);
      if (value != null) {
        amounts.add(value);
      }
    }

    if (amounts.isEmpty) return null;

    amounts.sort();
    return amounts.last;
  }

  void dispose() {
    _textRecognizer.close();
  }
}