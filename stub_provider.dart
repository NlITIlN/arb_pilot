// lib/tools/i18n/translator/stub_provider.dart
//
// Заглушка — активируется когда все провайдеры недоступны.
// Создаёт записи с ⚠️ NEEDS_REVIEW для ручного перевода.

import 'provider.dart';

class StubProvider implements TranslationProvider {
  @override
  String get name => 'Stub';

  @override
  bool supportsLanguage(String langCode) => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
  }) async {
    return TranslationResult(
      text: '⚠️ NEEDS_REVIEW: $text',
      provider: name,
      needsReview: true,
      warning: 'Нет доступных провайдеров. Переведите вручную: grep -r "NEEDS_REVIEW" lib/',
    );
  }
}
