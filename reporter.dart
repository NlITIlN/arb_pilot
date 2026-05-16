// lib/tools/i18n/reporter.dart
//
// Форматированный вывод в терминал и JSON-отчёты для CI/CD.
// Поддерживает ANSI цвета с автоопределением (Windows, CI, --no-color).

import 'dart:convert';
import 'dart:io';
import 'differ.dart';

// ── ANSI ──────────────────────────────────────────────────────────────────────

class _C {
  static const reset   = '\x1B[0m';
  static const bold    = '\x1B[1m';
  static const dim     = '\x1B[2m';
  static const red     = '\x1B[31m';
  static const green   = '\x1B[32m';
  static const yellow  = '\x1B[33m';
  static const blue    = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan    = '\x1B[36m';
  static const white   = '\x1B[97m';
  static const gray    = '\x1B[90m';

  static bool _supported = _detectSupport();

  static bool _detectSupport() {
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    if (Platform.environment['TERM'] == 'dumb') return false;
    if (Platform.isWindows) {
      return Platform.environment.containsKey('WT_SESSION') ||
          Platform.environment.containsKey('COLORTERM');
    }
    return stdout.hasTerminal;
  }

  static void forceDisable() => _supported = false;

  static String apply(String text, List<String> codes) {
    if (!_supported) return text;
    return '${codes.join()}$text$reset';
  }
}

// ── Reporter ──────────────────────────────────────────────────────────────────

class Reporter {
  final bool jsonOutput;
  final String projectRoot;

  Reporter({required this.jsonOutput, required this.projectRoot, bool useColor = true}) {
    if (!useColor) _C.forceDisable();
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  void printHeader() {
    if (jsonOutput) return;
    _line('═', 62);
    _p(_C.apply('  ✈️  arb_pilot — i18n Revisor', [_C.bold, _C.white]));
    _p('  Проект: ${_C.apply(projectRoot, [_C.dim])}');
    _p('  ${_C.apply(DateTime.now().toLocal().toString().substring(0, 19), [_C.gray])}');
    _line('═', 62);
    stdout.writeln();
  }

  // ── Discovery ─────────────────────────────────────────────────────────────────

  void printDiscovery({
    required int dartFiles,
    required int arbFiles,
    required Map<String, List<String>> byModule,
  }) {
    if (jsonOutput) return;
    _section('📁 Обнаружено');
    _item('Dart файлов для анализа', '$dartFiles');
    _item('.arb файлов найдено', '$arbFiles');
    for (final e in byModule.entries) {
      _p('    ${_C.apply(e.key, [_C.cyan])}: [${e.value.join(", ")}]');
    }
    stdout.writeln();
  }

  // ── Parsing ───────────────────────────────────────────────────────────────────

  void printParsing({required int total, required int withContext}) {
    if (jsonOutput) return;
    _section('🔍 Анализ кода');
    _item('Уникальных ключей найдено', '$total');
    _item('С @i18n-context аннотацией',
        '$withContext / $total',
        color: withContext == total ? _C.green : _C.yellow);
    if (withContext < total) {
      _p('    ${_C.apply("⚠  ${total - withContext} ключей без контекста — качество перевода ниже", [_C.yellow])}');
    }
    stdout.writeln();
  }

  // ── Summary stats ─────────────────────────────────────────────────────────────

  void printStats({
    required int missing,
    required int orphaned,
    required int empty,
    required int needsReview,
    required List<QualityIssue> qualityIssues,
  }) {
    if (jsonOutput) return;
    _section('📊 Результаты проверки');
    _item('Отсутствующих переводов', '$missing',
        color: missing == 0 ? _C.green : _C.red);
    _item('Устаревших ключей (orphaned)', '$orphaned',
        color: orphaned == 0 ? _C.green : _C.yellow);
    _item('Пустых значений', '$empty',
        color: empty == 0 ? _C.green : _C.red);
    _item('Требуют ревью (NEEDS_REVIEW)', '$needsReview',
        color: needsReview == 0 ? _C.green : _C.yellow);

    if (qualityIssues.isNotEmpty) {
      _item('Проблем качества', '${qualityIssues.length}',
          color: _C.yellow);
    }

    if (missing == 0 && orphaned == 0 && empty == 0 && needsReview == 0) {
      stdout.writeln();
      _p(_C.apply('  ✅ Всё синхронизировано!', [_C.green, _C.bold]));
    }
    stdout.writeln();
  }

  // ── Detailed gaps ─────────────────────────────────────────────────────────────

  void printGaps(List<TranslationGap> gaps, {int maxShow = 25}) {
    if (jsonOutput || gaps.isEmpty) return;

    _section('❌ Отсутствующие переводы (первые ${gaps.take(maxShow).length}):');

    // Группируем по ключу для компактности
    final byKey = <String, List<TranslationGap>>{};
    for (final g in gaps) {
      byKey.putIfAbsent('${g.module}::${g.key}', () => []).add(g);
    }

    var shown = 0;
    for (final entry in byKey.entries) {
      if (shown >= maxShow) break;
      final locales = entry.value.map((g) => g.targetLocale).join(', ');
      final sample = entry.value.first;
      final src = sample.sourceText != null
          ? ' = "${_cut(sample.sourceText!, 45)}"'
          : '';
      _p('    ${_C.apply(entry.key, [_C.red])}$src');
      _p('      → [$locales]');
      shown++;
    }
    if (gaps.length > maxShow) {
      _p('    ${_C.apply("... и ещё ${gaps.length - maxShow}", [_C.gray])}');
    }
    stdout.writeln();
  }

  // ── Orphans ───────────────────────────────────────────────────────────────────

  void printOrphans(List<OrphanKey> orphans, {int maxShow = 20}) {
    if (jsonOutput || orphans.isEmpty) return;
    _section('👻 Устаревшие ключи (есть в .arb, нет в коде):');
    for (final o in orphans.take(maxShow)) {
      _p('    ${_C.apply("[${o.module}/${o.locale}]", [_C.gray])} '
         '${_C.apply(o.key, [_C.yellow])}');
    }
    if (orphans.length > maxShow) {
      _p('    ${_C.apply("... и ещё ${orphans.length - maxShow}", [_C.gray])}');
    }
    stdout.writeln();
  }

  // ── Quality ───────────────────────────────────────────────────────────────────

  void printQualityIssues(List<QualityIssue> issues, {int maxShow = 15}) {
    if (jsonOutput || issues.isEmpty) return;
    _section('⚠️  Проблемы качества:');
    for (final i in issues.take(maxShow)) {
      _p('    ${_C.apply("[${i.module}/${i.locale}]", [_C.gray])} '
         '${_C.apply(i.key, [_C.yellow])} — ${i.message}');
    }
    if (issues.length > maxShow) {
      _p('    ${_C.apply("... и ещё ${issues.length - maxShow}", [_C.gray])}');
    }
    stdout.writeln();
  }

  // ── Translation progress ──────────────────────────────────────────────────────

  void printTranslationHeader(int total) {
    if (jsonOutput) return;
    _section('🤖 Автоперевод ($total строк)');
  }

  void printTranslationResult({
    required String key,
    required String locale,
    required String result,
    required String provider,
    required bool needsReview,
    bool dryRun = false,
  }) {
    if (jsonOutput) return;
    final prefix = dryRun ? _C.apply('  [dry-run]', [_C.blue]) : '';
    final mark   = needsReview ? _C.apply(' ⚠', [_C.yellow]) : '';
    final prov   = _C.apply('($provider)', [_C.gray]);
    final color  = needsReview ? _C.yellow : _C.green;

    _p('$prefix  ${_C.apply("[$locale]", [_C.cyan])} '
       '$key → ${_C.apply('"${_cut(result, 52)}"', [color])} $prov$mark');
  }

  void printTranslationError(String key, String locale, String error) {
    if (jsonOutput) return;
    _p('    ${_C.apply("[$locale] $key → ОШИБКА: $error", [_C.red])}');
  }

  // ── Provider availability ──────────────────────────────────────────────────────

  void printProviderStatus(Map<String, bool> status) {
    if (jsonOutput) return;
    _section('🔌 Провайдеры перевода');
    for (final e in status.entries) {
      final icon  = e.value ? '✓' : '✗';
      final color = e.value ? _C.green : _C.gray;
      _p('    ${_C.apply(icon, [color])} ${e.key}');
    }
    stdout.writeln();
  }

  // ── Final summary ─────────────────────────────────────────────────────────────

  void printSummary({
    required int translated,
    required int skipped,
    required int errors,
    required int orphanedRemoved,
    required Duration elapsed,
    bool dryRun = false,
  }) {
    if (jsonOutput) return;
    stdout.writeln();
    _line('─', 62);
    _p(_C.apply('  📋 Итог', [_C.bold]));
    _line('─', 62);

    if (dryRun) {
      _p(_C.apply('  ℹ  Dry-run режим — файлы не изменены', [_C.blue]));
    }
    if (translated > 0) {
      _item('✅ Переведено', '$translated строк', color: _C.green);
    }
    if (skipped > 0) {
      _item('⏭  Пропущено', '$skipped', color: _C.gray);
    }
    if (errors > 0) {
      _item('❌ Ошибок', '$errors', color: _C.red);
    }
    if (orphanedRemoved > 0) {
      _item('🗑  Удалено устаревших', '$orphanedRemoved', color: _C.yellow);
    }
    _item('⏱  Время', '${elapsed.inSeconds}с');
    _line('═', 62);

    if (errors == 0 && translated > 0 && !dryRun) {
      _p(_C.apply('\n  🎉 Локализация обновлена!', [_C.green, _C.bold]));
    } else if (dryRun && translated > 0) {
      _p(_C.apply('\n  ℹ  Запустите без --dry-run для применения изменений.', [_C.blue]));
    } else if (errors > 0) {
      _p(_C.apply('\n  ⚠  Завершено с ошибками.', [_C.yellow]));
    }
    stdout.writeln();
  }

  // ── JSON output ───────────────────────────────────────────────────────────────

  void printJsonReport({
    required List<TranslationGap> gaps,
    required List<OrphanKey> orphans,
    required List<QualityIssue> qualityIssues,
    required List<String> targetLocales,
    required int totalSourceKeys,
  }) {
    if (!jsonOutput) return;

    final byLang = <String, dynamic>{};
    for (final locale in targetLocales) {
      final missing = gaps
          .where((g) => g.targetLocale == locale)
          .map((g) => g.key)
          .toList();
      final coverage = totalSourceKeys == 0
          ? 1.0
          : (totalSourceKeys - missing.length) / totalSourceKeys;
      byLang[locale] = {
        'missing_count': missing.length,
        'missing_keys':  missing,
        'coverage':      double.parse(coverage.toStringAsFixed(4)),
      };
    }

    final report = {
      'generated_at':    DateTime.now().toIso8601String(),
      'total_issues':    gaps.length + orphans.length + qualityIssues.length,
      'by_type': {
        'missing':      gaps.length,
        'orphaned':     orphans.length,
        'empty':        qualityIssues.where((i) => i.kind == IssueKind.empty).length,
        'needs_review': qualityIssues.where((i) => i.kind == IssueKind.needsReview).length,
        'quality':      qualityIssues.length,
      },
      'orphaned_keys': orphans.map((o) => {
        'key':    o.key,
        'module': o.module,
        'locale': o.locale,
      }).toList(),
      'by_language': byLang,
    };

    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  }

  // ── Interactive ───────────────────────────────────────────────────────────────

  bool askYesNo(String question, {bool defaultNo = true}) {
    stdout.write('  $question [${defaultNo ? "y/N" : "Y/n"}]: ');
    final answer = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (defaultNo) return answer == 'y' || answer == 'д' || answer == 'yes' || answer == 'да';
    return answer != 'n' && answer != 'н' && answer != 'no' && answer != 'нет';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _section(String title) {
    _p(_C.apply(title, [_C.bold, _C.cyan]));
  }

  void _item(String label, String value, {String? color}) {
    final v = color != null ? _C.apply(value, [color]) : value;
    stdout.writeln('  ${label.padRight(40)} $v');
  }

  void _p(String text) => stdout.writeln(text);

  void _line(String char, int width) =>
      stdout.writeln(char * width);

  String _cut(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
