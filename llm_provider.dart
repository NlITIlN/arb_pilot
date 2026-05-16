// lib/tools/i18n/translator/llm_provider.dart
//
// Провайдер Ollama — локальный LLM, полностью офлайн.
// Поддерживает любую модель: llama3, mistral, gemma2, phi3...
// Не нужен интернет и API ключи.

import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class OllamaProvider implements TranslationProvider {
  final String host;
  final String model;

  OllamaProvider({
    required this.host,
    required this.model,
  });

  @override
  String get name => 'Ollama ($model)';

  @override
  bool supportsLanguage(String langCode) => true; // LLM — универсален

  @override
  Future<bool> isAvailable() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('$host/api/tags'));
      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return false;

      // Проверяем что нужная модель скачана
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final models = (data['models'] as List?) ?? [];
      return models.any((m) {
        final name = (m['name'] as String?) ?? '';
        return name == model ||
            name.startsWith('$model:') ||
            name.startsWith(model);
      });
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
    final langNames = _langName(to);
    final prompt = _buildPrompt(text, from: from, to: to,
        toLang: langNames, context: context);

    final body = jsonEncode({
      'model':  model,
      'prompt': prompt,
      'stream': false,
      'options': {
        'temperature': 0.1,     // минимальная случайность для переводов
        'num_predict': 256,
        'stop': ['\n\n', '---', 'Note:', 'Translation:'],
      },
    });

    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$host/api/generate'),
      );
      req.headers.contentType = ContentType.json;
      req.write(body);

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        throw Exception('Ollama ${res.statusCode}: $raw');
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final translated = _cleanResponse(data['response'] as String? ?? '');

      if (translated.isEmpty) {
        throw Exception('Ollama вернул пустой ответ');
      }

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

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _buildPrompt(
    String text, {
    required String from,
    required String to,
    required String toLang,
    String? context,
  }) {
    final fromLang = _langName(from);
    final buf = StringBuffer();

    buf.writeln('You are a professional UI translator.');
    buf.writeln('Translate the following UI string from $fromLang to $toLang.');
    buf.writeln();

    if (context != null && context.isNotEmpty) {
      buf.writeln('Context: $context');
      buf.writeln();
    }

    buf.writeln('Rules:');
    buf.writeln('- Return ONLY the translated text, nothing else');
    buf.writeln('- Do NOT add quotes, explanations, or notes');
    buf.writeln('- Preserve any {placeholders} exactly as-is');
    buf.writeln('- Preserve ICU plural syntax if present');
    buf.writeln('- Keep the same tone (formal/informal) as the original');
    buf.writeln();
    buf.writeln('Text to translate:');
    buf.writeln(text);

    return buf.toString();
  }

  /// Убираем кавычки, пояснения и лишние пробелы из ответа LLM
  String _cleanResponse(String raw) {
    var result = raw.trim();

    // Убираем markdown-кавычки
    if (result.startsWith('```') && result.endsWith('```')) {
      result = result.substring(3, result.length - 3).trim();
    }

    // Убираем обрамляющие одинарные/двойные кавычки
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.substring(1, result.length - 1);
    }

    // Если LLM написал "Translation: ...", берём только после двоеточия
    final colonIdx = result.indexOf(': ');
    if (colonIdx > 0 && colonIdx < 20) {
      final prefix = result.substring(0, colonIdx).toLowerCase();
      if (prefix.contains('translat') || prefix.contains('перевод')) {
        result = result.substring(colonIdx + 2).trim();
      }
    }

    return result;
  }

  static const _langNames = {
    'en': 'English',   'ru': 'Russian',    'zh': 'Chinese (Simplified)',
    'hi': 'Hindi',     'es': 'Spanish',    'de': 'German',
    'fr': 'French',    'ja': 'Japanese',   'pt': 'Portuguese',
    'it': 'Italian',   'ko': 'Korean',     'nl': 'Dutch',
    'pl': 'Polish',    'ar': 'Arabic',     'tr': 'Turkish',
    'uk': 'Ukrainian', 'be': 'Belarusian', 'kk': 'Kazakh',
    'uz': 'Uzbek',     'az': 'Azerbaijani','hy': 'Armenian',
    'ka': 'Georgian',  'vi': 'Vietnamese', 'id': 'Indonesian',
    'th': 'Thai',      'ms': 'Malay',      'fa': 'Persian',
    'he': 'Hebrew',    'sv': 'Swedish',    'da': 'Danish',
    'fi': 'Finnish',   'cs': 'Czech',      'ro': 'Romanian',
    'hu': 'Hungarian', 'bg': 'Bulgarian',  'hr': 'Croatian',
    'sk': 'Slovak',    'sl': 'Slovenian',  'et': 'Estonian',
    'lv': 'Latvian',   'lt': 'Lithuanian',
  };

  String _langName(String code) =>
      _langNames[code.toLowerCase()] ?? code.toUpperCase();
}
