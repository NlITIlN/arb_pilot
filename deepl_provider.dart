// lib/tools/i18n/translator/deepl_provider.dart
//
// Провайдер DeepL. Лучшее качество для EU/RU/ZH языков.
// Автоматически определяет Free vs Pro по суффиксу ':fx' в ключе.
// Хинди не поддерживается — chain передаёт его следующему провайдеру.

import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class DeepLProvider implements TranslationProvider {
  final String apiKey;

  bool get _isFree => apiKey.endsWith(':fx');

  String get _baseUrl => _isFree
      ? 'https://api-free.deepl.com'
      : 'https://api.deepl.com';

  // ISO 639-1 → DeepL language codes
  static const _codeMap = {
    'en': 'EN', 'ru': 'RU', 'zh': 'ZH', 'es': 'ES',
    'de': 'DE', 'fr': 'FR', 'it': 'IT', 'ja': 'JA',
    'ko': 'KO', 'pt': 'PT', 'nl': 'NL', 'pl': 'PL',
    'sv': 'SV', 'da': 'DA', 'fi': 'FI', 'cs': 'CS',
    'ro': 'RO', 'hu': 'HU', 'tr': 'TR', 'uk': 'UK',
    'bg': 'BG', 'hr': 'HR', 'sk': 'SK', 'sl': 'SL',
    'lt': 'LT', 'lv': 'LV', 'et': 'ET', 'id': 'ID',
    'nb': 'NB',
  };

  static final _supported = _codeMap.keys.toSet();

  DeepLProvider({required this.apiKey});

  @override
  String get name => 'DeepL ${_isFree ? "Free" : "Pro"}';

  @override
  bool supportsLanguage(String langCode) =>
      _supported.contains(langCode.toLowerCase());

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(Uri.parse('$_baseUrl/v2/usage'));
      req.headers.set('Authorization', 'DeepL-Auth-Key $apiKey');
      final res = await req.close();
      await res.drain<void>();
      client.close();
      return res.statusCode == 200;
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
    final toLang   = _codeMap[to.toLowerCase()]   ?? to.toUpperCase();
    final fromLang = _codeMap[from.toLowerCase()] ?? from.toUpperCase();

    final bodyMap = <String, dynamic>{
      'text':        [text],
      'target_lang': toLang,
      'source_lang': fromLang,
      'tag_handling': 'xml',     // сохраняем XML/HTML теги
      'preserve_formatting': 1,
    };
    if (context != null && context.isNotEmpty) {
      bodyMap['context'] = context;
    }

    final body = jsonEncode(bodyMap);

    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$_baseUrl/v2/translate'),
      );
      req.headers.set('Authorization', 'DeepL-Auth-Key $apiKey');
      req.headers.contentType = ContentType.json;
      req.write(body);

      final res  = await req.close();
      final raw  = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        Map<String, dynamic> errBody = {};
        try { errBody = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
        throw Exception(
          'DeepL ${res.statusCode}: ${errBody['message'] ?? raw}',
        );
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final translated =
          (data['translations'] as List).first['text'] as String;

      return TranslationResult(
        text:        translated,
        provider:    name,
        needsReview: context == null,
        warning: context == null
            ? 'Переведено без @i18n-context'
            : null,
      );
    } finally {
      client.close();
    }
  }
}
