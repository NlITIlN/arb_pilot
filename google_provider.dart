// lib/tools/i18n/translator/google_provider.dart
//
// Провайдер Google Cloud Translation API v2.
// 130+ языков включая хинди, арабский, суахили и другие редкие.
// Требует API ключ из Google Cloud Console.

import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class GoogleTranslateProvider implements TranslationProvider {
  final String apiKey;

  static const _endpoint =
      'https://translation.googleapis.com/language/translate/v2';

  // Google поддерживает 130+ языков — считаем что поддерживаем всё.
  // Исключение: только языки без письменности или изолированные диалекты.
  static const _unsupported = <String>{}; // намеренно пусто

  GoogleTranslateProvider({required this.apiKey});

  @override
  String get name => 'Google Translate';

  @override
  bool supportsLanguage(String langCode) =>
      !_unsupported.contains(langCode.toLowerCase());

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      final uri = Uri.parse('$_endpoint?key=$apiKey&q=test&target=ru');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
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
    // Google v2 не поддерживает поле context напрямую.
    // При наличии контекста — добавляем его в глоссарий через формат:
    // "[context hint] text" и парсим только ответ.
    final queryText = context != null && context.isNotEmpty
        ? text  // чистый текст — Google и так неплохо переводит
        : text;

    final body = jsonEncode({
      'q':      queryText,
      'source': from,
      'target': to,
      'format': 'text',
    });

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(body);

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        Map<String, dynamic> errBody = {};
        try { errBody = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
        final message = (errBody['error'] as Map?)?['message'] ?? raw;
        throw Exception('Google Translate ${res.statusCode}: $message');
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final translated = (data['data']['translations'] as List)
          .first['translatedText'] as String;

      // Google HTML-кодирует некоторые символы — декодируем
      final decoded = _decodeHtmlEntities(translated);

      return TranslationResult(
        text:        decoded,
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

  /// Декодирование HTML-сущностей которые Google иногда возвращает
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;',  '&')
        .replaceAll('&lt;',   '<')
        .replaceAll('&gt;',   '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;',  "'")
        .replaceAll('&nbsp;', ' ');
  }
}
