import 'package:flutter/material.dart';

class OCRService {
  Future<Map<String, dynamic>?> scanReceiptPath(String path) async {
    debugPrint('OCR is not available on this platform.');
    return null;
  }

  void dispose() {}
}