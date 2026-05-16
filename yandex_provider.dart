// lib/tools/i18n/translator/yandex_provider.dart
//
// Провайдер Yandex Cloud Translate API v2.
// Отличное качество для RU и постсоветских языков (KK, UZ, BE, UK...).
// Требует API ключ из Yandex Cloud Console.
// Документация: https://cloud.yandex.ru/docs/translate/

import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class YandexTranslateProvider implements TranslationProvider {
  final String apiKey;

  /// Yandex Cloud Translate endpoint (v2)
  static const _endpoint =
      'https://translate.api.cloud.yandex.net/translate/v2/translate';

  static const _supported = {
    'ru', 'en', 'uk', 'be', 'kk', 'az', 'hy', 'ka', 'uz', 'ky',
    'tg', 'tk', 'mn', 'tt', 'ba', 'cv', 'ce', 'os',
    'de', 'fr', 'es', 'it', 'pt', 'pl', 'nl', 'cs', 'sv',
    'da', 'fi', 'no', 'tr', 'ar', 'he', 'fa',
    'zh', 'ja', 'ko', 'vi', 'id', 'th', 'ms',
    'ro', 'hu', 'bg', 'hr', 'sk', 'sl', 'lt', 'lv', 'et',
    'sr', 'mk', 'sq', 'el', 'mt',
  };

  YandexTranslateProvider({required this.apiKey});

  @override
  String get name => 'Yandex Translate';

  @override
  bool supportsLanguage(String langCode) =>
      _supported.contains(langCode.toLowerCase());

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      final result = await translate('test', from: 'en', to: 'ru');
      return result.text.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
  }) async {
    final body = jsonEncode({
      'texts':              [text],
      'targetLanguageCode': to,
      'sourceLanguageCode': from,
    });

    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.set('Authorization', 'Api-Key $apiKey');
      req.headers.contentType = ContentType.json;
      req.write(body);

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        Map<String, dynamic> errBody = {};
        try { errBody = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
        throw Exception(
          'Yandex ${res.statusCode}: ${errBody['message'] ?? raw}',
        );
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final translated =
          (data['translations'] as List).first['text'] as String;

      return TranslationResult(
        text:        translated,
        provider:    name,
        needsReview: context == null,
        warning: context == null ? 'Переведено без @i18n-context' : null,
      );
    } finally {
      client.close();
    }
  }
}
