import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:translator/translator.dart';

class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  static const Duration _requestTimeout = Duration(seconds: 6);
  static const Duration _cacheTtl = Duration(days: 30);
  static const int _maxCacheEntries = 2000;
  static const String _cacheFileName = 'translation_cache_v1.json';

  final GoogleTranslator _translator = GoogleTranslator();
  final Map<String, _CacheEntry> _cache = {};

  Future<void>? _cacheLoadFuture;
  Future<void> _persistQueue = Future.value();

  Future<String> translate({
    required String sourceText,
    required String targetLanguageCode,
  }) async {
    final normalizedSource = sourceText.trim();
    if (_shouldSkipTranslation(normalizedSource, targetLanguageCode)) {
      return sourceText;
    }

    await _ensureCacheLoaded();

    final cacheKey = _buildCacheKey(targetLanguageCode, normalizedSource);
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.text;
    }

    try {
      final translated = await _translator
          .translate(normalizedSource, to: targetLanguageCode)
          .timeout(_requestTimeout);

      final text = translated.text.trim();
      if (text.isEmpty) {
        return sourceText;
      }

      _cache[cacheKey] = _CacheEntry(text: text, updatedAtMs: _nowMs());
      _pruneCacheIfNeeded();
      _schedulePersist();

      return text;
    } catch (_) {
      // Never block UX on translation failures; show original text.
      return sourceText;
    }
  }

  Future<List<String>> translateMany({
    required List<String> sourceTexts,
    required String targetLanguageCode,
  }) async {
    if (sourceTexts.isEmpty) {
      return const [];
    }

    final unique = <String>{};
    for (final text in sourceTexts) {
      final normalized = text.trim();
      if (normalized.isNotEmpty) {
        unique.add(normalized);
      }
    }

    final translatedMap = <String, String>{};
    for (final source in unique) {
      translatedMap[source] = await translate(
        sourceText: source,
        targetLanguageCode: targetLanguageCode,
      );
    }

    return sourceTexts
        .map((raw) {
          final normalized = raw.trim();
          return translatedMap[normalized] ?? raw;
        })
        .toList(growable: false);
  }

  Future<void> clearCache() async {
    _cache.clear();
    _persistQueue = _persistQueue.then((_) async {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    });
    await _persistQueue;
  }

  Future<void> _ensureCacheLoaded() async {
    _cacheLoadFuture ??= _loadCacheFromDisk();
    await _cacheLoadFuture;
  }

  Future<void> _loadCacheFromDisk() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return;
      }

      final jsonValue = jsonDecode(content);
      if (jsonValue is! Map<String, dynamic>) {
        return;
      }

      for (final entry in jsonValue.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final cacheEntry = _CacheEntry.fromJson(value);
          if (!cacheEntry.isExpired(_cacheTtl)) {
            _cache[entry.key] = cacheEntry;
          }
        }
      }
      _pruneCacheIfNeeded();
    } catch (_) {
      // Ignore corrupt cache, service will rebuild it naturally.
    }
  }

  void _schedulePersist() {
    _persistQueue = _persistQueue.then((_) => _persistCacheToDisk());
  }

  Future<void> _persistCacheToDisk() async {
    try {
      final file = await _cacheFile();
      final payload = <String, dynamic>{
        for (final item in _cache.entries) item.key: item.value.toJson(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Ignore IO errors; in-memory cache is still available.
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  bool _shouldSkipTranslation(String sourceText, String targetLanguageCode) {
    if (sourceText.isEmpty) {
      return true;
    }

    if (targetLanguageCode.toLowerCase() == 'vi') {
      return true;
    }

    // Skip pure numeric/date-like values to save network requests.
    final numericLike = RegExp(r'^[0-9\s.,:/%+\-]+$');
    return numericLike.hasMatch(sourceText);
  }

  String _buildCacheKey(String targetLanguageCode, String sourceText) {
    return '${targetLanguageCode.toLowerCase()}::${sourceText.toLowerCase()}';
  }

  void _pruneCacheIfNeeded() {
    if (_cache.length <= _maxCacheEntries) {
      return;
    }

    final sortedEntries = _cache.entries.toList()
      ..sort((a, b) => a.value.updatedAtMs.compareTo(b.value.updatedAtMs));

    final toRemove = _cache.length - _maxCacheEntries;
    for (var i = 0; i < toRemove; i++) {
      _cache.remove(sortedEntries[i].key);
    }
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class _CacheEntry {
  const _CacheEntry({required this.text, required this.updatedAtMs});

  final String text;
  final int updatedAtMs;

  bool isExpired(Duration ttl) {
    final age = DateTime.now().millisecondsSinceEpoch - updatedAtMs;
    return age > ttl.inMilliseconds;
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'updatedAtMs': updatedAtMs};
  }

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      text: json['text']?.toString() ?? '',
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
