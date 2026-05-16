// lib/tools/i18n/differ.dart
//
// Шаг 3: Сравнение ключей из кода с .arb файлами.
// Находит: missing (нет перевода), orphaned (нет в коде), empty, needsReview.

import 'discovery.dart';
import 'ast_parser.dart';

// ── Модели ────────────────────────────────────────────────────────────────────

/// Ключ есть в коде, но отсутствует перевод для данного модуля + локали
class TranslationGap {
  final String key;
  final String module;
  final String targetLocale;
  final String sourceLocale;

  /// Исходный текст для перевода
  final String? sourceText;

  /// Контекст — из @i18n-context или @-метаданных .arb
  final String? context;

  const TranslationGap({
    required this.key,
    required this.module,
    required this.targetLocale,
    required this.sourceLocale,
    this.sourceText,
    this.context,
  });

  @override
  String toString() => '[$module] $key → $targetLocale';
}

/// Ключ есть в .arb, но не используется в коде
class OrphanKey {
  final String key;
  final String module;
  final String locale;
  final String arbPath;

  const OrphanKey({
    required this.key,
    required this.module,
    required this.locale,
    required this.arbPath,
  });

  @override
  String toString() => '[$module/$locale] $key';
}

/// Проблема качества существующего перевода
enum IssueKind { empty, needsReview, identicalToSource, placeholderMismatch, tooLong }

class QualityIssue {
  final String key;
  final String module;
  final String locale;
  final IssueKind kind;
  final String message;

  const QualityIssue({
    required this.key,
    required this.module,
    required this.locale,
    required this.kind,
    required this.message,
  });
}

// ── Differ ────────────────────────────────────────────────────────────────────

class ArbDiffer {
  final ArbDiscoveryResult arbFiles;
  final List<FoundKey> usedKeys;
  final List<String> targetLocales;
  final String sourceLocale;

  ArbDiffer({
    required this.arbFiles,
    required this.usedKeys,
    required this.targetLocales,
    required this.sourceLocale,
  });

  // ── Gaps ─────────────────────────────────────────────────────────────────────

  List<TranslationGap> findGaps() {
    final gaps = <TranslationGap>[];

    // Группируем ключи по модулю
    final keysByModule = <String, List<FoundKey>>{};
    for (final k in usedKeys) {
      keysByModule.putIfAbsent(k.module, () => []).add(k);
    }

    for (final entry in keysByModule.entries) {
      final module = entry.key;
      final keys = entry.value;
      final bestSource = _bestSourceLocale(module);

      for (final foundKey in keys) {
        final sourceText = _sourceText(module, foundKey.key, bestSource);
        final context = _context(module, foundKey);

        for (final locale in targetLocales) {
          if (locale == sourceLocale) continue;
          if (_hasTranslation(module, foundKey.key, locale)) continue;

          gaps.add(TranslationGap(
            key: foundKey.key,
            module: module,
            targetLocale: locale,
            sourceLocale: bestSource,
            sourceText: sourceText,
            context: context,
          ));
        }
      }
    }

    return gaps;
  }

  // ── Orphans ───────────────────────────────────────────────────────────────────

  List<OrphanKey> findOrphans() {
    final orphans = <OrphanKey>[];
    final allUsedKeys = usedKeys.map((k) => k.key).toSet();

    for (final module in arbFiles.modules) {
      final localeMap = arbFiles.byModule[module]!;
      for (final entry in localeMap.entries) {
        final locale = entry.key;
        final arb = entry.value;

        for (final key in arb.keys) {
          if (key.startsWith('@')) continue;
          if (!allUsedKeys.contains(key)) {
            orphans.add(OrphanKey(
              key: key,
              module: module,
              locale: locale,
              arbPath: arb.path,
            ));
          }
        }
      }
    }

    return orphans;
  }

  // ── Quality issues ────────────────────────────────────────────────────────────

  List<QualityIssue> findQualityIssues() {
    final issues = <QualityIssue>[];

    for (final module in arbFiles.modules) {
      final localeMap = arbFiles.byModule[module]!;
      final sourceArb = localeMap[sourceLocale];

      for (final entry in localeMap.entries) {
        final locale = entry.key;
        final arb = entry.value;

        for (final key in arb.keys) {
          if (key.startsWith('@')) continue;

          final value = arb.entries[key];
          if (value is! String) continue;

          // 1. Пустое значение
          if (value.trim().isEmpty) {
            issues.add(QualityIssue(
              key: key, module: module, locale: locale,
              kind: IssueKind.empty,
              message: 'Пустое значение',
            ));
            continue;
          }

          // 2. NEEDS_REVIEW маркер
          if (value.startsWith('⚠️ NEEDS_REVIEW:') ||
              value.contains('[TRANSLATE]') ||
              value.contains('TODO:')) {
            issues.add(QualityIssue(
              key: key, module: module, locale: locale,
              kind: IssueKind.needsReview,
              message: 'Требует ручного перевода',
            ));
          }

          // 3. Идентично исходнику (возможно не переведено)
          if (locale != sourceLocale && sourceArb != null) {
            final srcValue = sourceArb.entries[key];
            if (srcValue is String &&
                srcValue == value &&
                !_acceptableSameValue(value)) {
              issues.add(QualityIssue(
                key: key, module: module, locale: locale,
                kind: IssueKind.identicalToSource,
                message: 'Значение идентично исходнику',
              ));
            }
          }

          // 4. Несовпадение placeholder'ов {var}
          if (sourceArb != null) {
            final srcValue = sourceArb.entries[key];
            if (srcValue is String) {
              final srcPH = _placeholders(srcValue);
              final valPH = _placeholders(value);
              if (!_setsEqual(srcPH, valPH)) {
                issues.add(QualityIssue(
                  key: key, module: module, locale: locale,
                  kind: IssueKind.placeholderMismatch,
                  message:
                      'Placeholder mismatch: ожидается ${srcPH.join(",")}, '
                      'найдено ${valPH.join(",")}',
                ));
              }
            }
          }

          // 5. Слишком длинный перевод
          if (sourceArb != null) {
            final srcValue = sourceArb.entries[key];
            if (srcValue is String && srcValue.isNotEmpty) {
              final ratio = value.length / srcValue.length;
              if (ratio > 2.5) {
                issues.add(QualityIssue(
                  key: key, module: module, locale: locale,
                  kind: IssueKind.tooLong,
                  message:
                      'Перевод в ${ratio.toStringAsFixed(1)}x длиннее оригинала',
                ));
              }
            }
          }
        }
      }
    }

    return issues;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool _hasTranslation(String module, String key, String locale) {
    // Ищем в модуле
    final inModule = arbFiles.get(module, locale);
    if (inModule != null && inModule.keys.contains(key)) return true;
    // Фоллбэк на core
    final inCore = arbFiles.get('core', locale);
    if (inCore != null && inCore.keys.contains(key)) return true;
    return false;
  }

  String _bestSourceLocale(String module) {
    if (arbFiles.get(module, sourceLocale) != null) return sourceLocale;
    final available = arbFiles.byModule[module]?.keys;
    return available?.firstOrNull ?? sourceLocale;
  }

  String? _sourceText(String module, String key, String locale) {
    final arb = arbFiles.get(module, locale) ?? arbFiles.get('core', locale);
    final val = arb?.entries[key];
    return val is String ? val : null;
  }

  String? _context(String module, FoundKey foundKey) {
    // 1. Inline-аннотация в коде
    if (foundKey.inlineContext != null) return foundKey.inlineContext;

    // 2. description из @-метаданных .arb
    for (final locale in [sourceLocale, 'en', 'ru']) {
      final arb = arbFiles.get(module, locale) ?? arbFiles.get('core', locale);
      final ctx = arb?.contextFor(foundKey.key);
      if (ctx != null) return ctx;
    }
    return null;
  }

  Set<String> _placeholders(String text) =>
      RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

  bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  bool _acceptableSameValue(String value) {
    if (value.length <= 3) return true;
    if (RegExp(r'^[\d\s\W]+$').hasMatch(value)) return true;
    if (RegExp(r'^[A-Z][a-zA-Z]+$').hasMatch(value)) return true;
    return false;
  }
}
