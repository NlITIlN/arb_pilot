// lib/tools/i18n/translator/chain.dart
//
// Fallback-цепочка провайдеров.
// Порядок: DeepL → Google → Yandex → Ollama → Stub
// Для каждого языка выбирается первый доступный провайдер.

import 'dart:io';
import 'provider.dart';
import 'deepl_provider.dart';
import 'google_provider.dart';
import 'yandex_provider.dart';
import 'llm_provider.dart';
import 'stub_provider.dart';
import '../config.dart';

class TranslationChain {
  /// Провайдеры в порядке приоритета
  final List<TranslationProvider> _providers;

  /// Кэш: langCode → проверенный провайдер
  final _cache = <String, TranslationProvider>{};

  TranslationChain(this._providers);

  /// Строит цепочку из конфига
  factory TranslationChain.fromConfig(ArbPilotConfig config) {
    final providers = <TranslationProvider>[];

    if (config.deeplKey != null) {
      providers.add(DeepLProvider(apiKey: config.deeplKey!));
    }
    if (config.googleKey != null) {
      providers.add(GoogleTranslateProvider(apiKey: config.googleKey!));
    }
    if (config.yandexKey != null) {
      providers.add(YandexTranslateProvider(apiKey: config.yandexKey!));
    }

    // Ollama — если хотя бы один из платных ключей не задан
    // ИЛИ явно передана модель
    final hasAnyCloudKey = config.deeplKey != null ||
        config.googleKey != null ||
        config.yandexKey != null;
    if (!hasAnyCloudKey ||
        Platform.environment['OLLAMA_MODEL'] != null) {
      providers.add(OllamaProvider(
        host:  config.ollamaHost,
        model: config.ollamaModel,
      ));
    }

    // Stub — всегда последний
    providers.add(StubProvider());

    return TranslationChain(providers);
  }

  /// Проверяет доступность всех провайдеров (параллельно)
  Future<Map<String, bool>> checkAvailability() async {
    final results = <String, bool>{};
    final futures = _providers.map((p) async {
      results[p.name] = await p.isAvailable();
    });
    await Future.wait(futures);
    return results;
  }

  /// Список доступных провайдеров
  Future<List<TranslationProvider>> availableProviders() async {
    final available = <TranslationProvider>[];
    for (final p in _providers) {
      if (await p.isAvailable()) available.add(p);
    }
    return available;
  }

  /// Перевести строку — автоматически выбирает лучший провайдер для языка.
  /// Если провайдер падает — пробует следующий.
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
    bool debug = false,
  }) async {
    // Сначала смотрим кэш (не проверяем доступность повторно)
    final cached = _cache[to];
    if (cached != null) {
      try {
        return await cached.translate(text, from: from, to: to, context: context);
      } catch (e) {
        // Кэшированный провайдер упал — идём дальше по цепочке
        _cache.remove(to);
        if (debug) stderr.writeln('  ⚡ ${cached.name} упал: $e');
      }
    }

    // Перебираем провайдеры
    for (final provider in _providers) {
      if (!provider.supportsLanguage(to)) continue;

      bool available;
      try {
        available = await provider.isAvailable();
      } catch (_) {
        available = false;
      }
      if (!available) continue;

      try {
        final result = await provider.translate(
          text, from: from, to: to, context: context,
        );
        _cache[to] = provider; // кэшируем успешный провайдер
        return result;
      } catch (e) {
        if (debug) {
          stderr.writeln('  ⚡ ${provider.name} ошибка для "$to": $e');
        }
        // Пробуем следующий
        continue;
      }
    }

    // Всё упало — Stub всегда доступен
    return StubProvider().translate(text, from: from, to: to, context: context);
  }

  /// Сбросить кэш провайдеров (например при ошибках сети)
  void resetCache() => _cache.clear();

  List<TranslationProvider> get providers => List.unmodifiable(_providers);
}
