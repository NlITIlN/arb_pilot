// lib/tools/i18n/translator/provider.dart
//
// Единственный источник правды для интерфейса провайдеров перевода.
// Все провайдеры реализуют TranslationProvider.

/// Результат перевода одной строки
class TranslationResult {
  final String text;
  final String provider;
  final bool needsReview;
  final String? warning;

  const TranslationResult({
    required this.text,
    required this.provider,
    this.needsReview = false,
    this.warning,
  });
}

/// Итог записи одного ключа
class TranslationRecord {
  final String key;
  final String module;
  final String targetLocale;
  final String sourceLocale;
  final String? sourceText;
  final String translatedText;
  final String providerName;
  final bool needsReview;

  const TranslationRecord({
    required this.key,
    required this.module,
    required this.targetLocale,
    required this.sourceLocale,
    this.sourceText,
    required this.translatedText,
    required this.providerName,
    required this.needsReview,
  });
}

/// Контракт провайдера.
/// Реализации: DeepLProvider, GoogleTranslateProvider,
///             YandexTranslateProvider, OllamaProvider, StubProvider.
abstract class TranslationProvider {
  /// Человекочитаемое имя для логов
  String get name;

  /// Поддерживает ли провайдер данный язык (ISO 639-1: 'en', 'ru', 'zh'...)
  bool supportsLanguage(String langCode);

  /// Перевести строку.
  /// [context] — подсказка из @i18n-context комментария.
  /// Throws при сетевой ошибке или неверном API ключе.
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
  });

  /// Проверить доступность провайдера.
  /// Никогда не бросает исключения — возвращает false при любой ошибке.
  Future<bool> isAvailable();
}
