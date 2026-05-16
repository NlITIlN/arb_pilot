// bin/language_revisor.dart
//
// ✈️  arb_pilot — точка входа CLI
//
// Pipeline:
//   1. Конфиг    — читаем arb_pilot.yaml + CLI args
//   2. Discovery — находим .arb и .dart файлы
//   3. Parse     — извлекаем ключи из Dart кода
//   4. Diff      — ищем missing, orphaned, quality issues
//   5. Translate — переводим через chain провайдеров
//   6. Write     — мержим в .arb файлы
//   7. Report    — выводим итог

import 'dart:io';

// Подключаем все модули напрямую (zero pub deps)
import '../lib/tools/i18n/config.dart';
import '../lib/tools/i18n/discovery.dart';
import '../lib/tools/i18n/ast_parser.dart';
import '../lib/tools/i18n/differ.dart';
import '../lib/tools/i18n/arb_writer.dart';
import '../lib/tools/i18n/reporter.dart';
import '../lib/tools/i18n/translator/chain.dart';
import '../lib/tools/i18n/translator/provider.dart';

Future<void> main(List<String> args) async {
  // ── Help ────────────────────────────────────────────────────────────────────
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  // ── Config ───────────────────────────────────────────────────────────────────
  final config = ArbPilotConfig.fromArgs(args);

  final reporter = Reporter(
    jsonOutput:  config.jsonOutput,
    projectRoot: config.projectRoot,
    useColor:    config.useColor,
  );

  reporter.printHeader();

  final stopwatch = Stopwatch()..start();

  // ── 1. Discovery ─────────────────────────────────────────────────────────────
  final discovery = ArbDiscovery(config);
  final arbDiscovery = await discovery.findArbFiles();
  final dartFilesList = await discovery.findDartFiles();

  // Строим карту модуль → локали для отображения
  final moduleLocales = <String, List<String>>{};
  for (final module in arbDiscovery.modules) {
    moduleLocales[module] =
        arbDiscovery.byModule[module]!.keys.toList()..sort();
  }

  reporter.printDiscovery(
    dartFiles: dartFilesList.length,
    arbFiles:  arbDiscovery.totalFiles,
    byModule:  moduleLocales,
  );

  if (arbDiscovery.totalFiles == 0 && !config.jsonOutput) {
    stderr.writeln(
      '  ⚠️  Не найдено ни одного .arb файла.\n'
      '  Проверьте l10n_paths в arb_pilot.yaml или создайте '
      'lib/core/l10n/app_en.arb',
    );
    exit(1);
  }

  // ── 2. Parse ─────────────────────────────────────────────────────────────────
  final parser = AstParser(config);
  final usedKeys = await parser.extractKeys(dartFilesList);

  reporter.printParsing(
    total:       usedKeys.length,
    withContext: usedKeys.where((k) => k.inlineContext != null).length,
  );

  // ── 3. Diff ──────────────────────────────────────────────────────────────────
  final differ = ArbDiffer(
    arbFiles:      arbDiscovery,
    usedKeys:      usedKeys,
    targetLocales: config.targetLangs,
    sourceLocale:  config.sourceLang,
  );

  final gaps          = differ.findGaps();
  final orphans       = differ.findOrphans();
  final qualityIssues = differ.findQualityIssues();

  final emptyCount      = qualityIssues.where((i) => i.kind == IssueKind.empty).length;
  final needsReviewCount = qualityIssues.where((i) => i.kind == IssueKind.needsReview).length;

  reporter.printStats(
    missing:       gaps.length,
    orphaned:      orphans.length,
    empty:         emptyCount,
    needsReview:   needsReviewCount,
    qualityIssues: qualityIssues,
  );
  reporter.printGaps(gaps);
  reporter.printOrphans(orphans);
  reporter.printQualityIssues(qualityIssues);

  // JSON-отчёт — выводим и выходим если только аудит
  if (config.jsonOutput) {
    reporter.printJsonReport(
      gaps:            gaps,
      orphans:         orphans,
      qualityIssues:   qualityIssues,
      targetLocales:   config.targetLangs,
      totalSourceKeys: usedKeys.length,
    );
    exit(gaps.isNotEmpty || orphans.isNotEmpty ? 2 : 0);
  }

  // Только аудит — нет флагов --auto / --interactive
  if (!config.autoMode && !config.interactiveMode) {
    if (gaps.isEmpty && orphans.isEmpty) {
      exit(0);
    }
    stdout.writeln(
      '  Запустите с --auto для автоперевода '
      'или --interactive для подтверждения каждого шага.',
    );
    exit(gaps.isNotEmpty ? 2 : 0);
  }

  // ── 4. Remove orphaned ────────────────────────────────────────────────────────
  var orphanedRemoved = 0;
  if (config.removeOrphaned && orphans.isNotEmpty) {
    // Группируем по файлу
    final byFile = <String, List<String>>{};
    for (final o in orphans) {
      byFile.putIfAbsent(o.arbPath, () => []).add(o.key);
    }

    for (final entry in byFile.entries) {
      bool proceed = true;
      if (config.interactiveMode) {
        proceed = reporter.askYesNo(
          'Удалить ${entry.value.length} устаревших ключей из '
          '${entry.key.split('/').last}?',
        );
      }
      if (proceed) {
        final writer = ArbWriter(config);
        orphanedRemoved += await writer.removeOrphaned(
          entry.key,
          entry.value,
          dryRun: config.dryRun,
        );
      }
    }
  }

  // ── 5. Translate ──────────────────────────────────────────────────────────────
  if (gaps.isEmpty) {
    reporter.printSummary(
      translated:      0,
      skipped:         0,
      errors:          0,
      orphanedRemoved: orphanedRemoved,
      elapsed:         stopwatch.elapsed,
      dryRun:          config.dryRun,
    );
    exit(0);
  }

  // Инициализируем провайдеры
  final chain = TranslationChain.fromConfig(config);
  final availability = await chain.checkAvailability();
  reporter.printProviderStatus(availability);
  reporter.printTranslationHeader(gaps.length);

  final records    = <TranslationRecord>[];
  var translated   = 0;
  var skipped      = 0;
  var errors       = 0;

  for (final gap in gaps) {
    if (gap.sourceText == null || gap.sourceText!.trim().isEmpty) {
      skipped++;
      continue;
    }

    // Интерактивный режим — спрашиваем
    if (config.interactiveMode) {
      final proceed = reporter.askYesNo(
        'Перевести [${gap.targetLocale}] ${gap.key} = '
        '"${gap.sourceText!.length > 50 ? "${gap.sourceText!.substring(0, 50)}…" : gap.sourceText}"?',
        defaultNo: false,
      );
      if (!proceed) {
        skipped++;
        continue;
      }
    }

    try {
      final result = await chain.translate(
        gap.sourceText!,
        from:    gap.sourceLocale,
        to:      gap.targetLocale,
        context: gap.context,
        debug:   config.debug,
      );

      reporter.printTranslationResult(
        key:          gap.key,
        locale:       gap.targetLocale,
        result:       result.text,
        provider:     result.provider,
        needsReview:  result.needsReview,
        dryRun:       config.dryRun,
      );

      records.add(TranslationRecord(
        key:           gap.key,
        module:        gap.module,
        targetLocale:  gap.targetLocale,
        sourceLocale:  gap.sourceLocale,
        sourceText:    gap.sourceText,
        translatedText: result.text,
        providerName:  result.provider,
        needsReview:   result.needsReview,
      ));

      translated++;
    } catch (e) {
      reporter.printTranslationError(gap.key, gap.targetLocale, e.toString());
      errors++;
      if (config.debug) stderr.writeln(StackTrace.current);
    }
  }

  // ── 6. Write ──────────────────────────────────────────────────────────────────
  if (records.isNotEmpty) {
    final writer = ArbWriter(config);
    await writer.write(records, dryRun: config.dryRun);
  }

  // ── 7. Report ─────────────────────────────────────────────────────────────────
  reporter.printSummary(
    translated:      translated,
    skipped:         skipped,
    errors:          errors,
    orphanedRemoved: orphanedRemoved,
    elapsed:         stopwatch.elapsed,
    dryRun:          config.dryRun,
  );

  exit(errors > 0 ? 1 : 0);
}

// ── Help ──────────────────────────────────────────────────────────────────────

void _printHelp() {
  const help = '''
✈️  arb_pilot — Smart i18n CLI for Dart & Flutter

ИСПОЛЬЗОВАНИЕ
  dart run bin/language_revisor.dart [флаги]

РЕЖИМЫ
  (без флагов)        Аудит — только читает, ничего не меняет
  --auto              Автоперевод без подтверждений
  --interactive       Подтверждение каждого шага
  --dry-run           Показать план без записи в файлы

ПРОВАЙДЕРЫ ПЕРЕВОДА
  --deepl-key=KEY     DeepL API ключ (Free: заканчивается на :fx)
  --google-key=KEY    Google Cloud Translation ключ
  --yandex-key=KEY    Yandex Cloud Translate ключ
  --ollama-model=NAME Модель Ollama (default: llama3)
  --ollama-host=URL   Хост Ollama (default: http://localhost:11434)

ФИЛЬТРЫ
  --source-lang=CODE  Исходный язык (default: en)
  --langs=ru,zh,hi    Целевые языки через запятую
  --root=PATH         Корень проекта (default: текущая директория)
  --remove-orphaned   Удалить устаревшие ключи из .arb

ВЫВОД
  --format=json       JSON-отчёт для CI/CD (exit 2 если есть проблемы)
  --no-color          Без ANSI цветов
  --debug             Подробный вывод ошибок

ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
  DEEPL_API_KEY, GOOGLE_TRANSLATE_KEY, YANDEX_TRANSLATE_KEY
  ARB_PILOT_ROOT, OLLAMA_MODEL, OLLAMA_HOST, DEBUG=1

КОДЫ ВЫХОДА
  0   Всё синхронизировано / перевод успешен
  1   Ошибка (сеть, API ключ, битый .arb)
  2   Аудит завершён — найдены проблемы

ПРИМЕРЫ
  dart run bin/language_revisor.dart
  dart run bin/language_revisor.dart --auto --deepl-key=abc:fx
  dart run bin/language_revisor.dart --auto --deepl-key=KEY --google-key=KEY
  dart run bin/language_revisor.dart --auto --ollama-model=mistral
  dart run bin/language_revisor.dart --interactive --langs=ru,zh
  dart run bin/language_revisor.dart --format=json > report.json
  dart run bin/language_revisor.dart --auto --dry-run

ДОКУМЕНТАЦИЯ
  INSTALLATION.md  — установка и интеграция
  COMMANDS.md      — все команды и флаги
  PROVIDERS.md     — настройка провайдеров перевода
''';
  stdout.write(help);
}
