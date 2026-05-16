// lib/tools/i18n/arb_writer.dart
//
// Шаг 5: Запись результатов перевода в .arb файлы.
// Мержит новые переводы с существующими, не перезаписывает уже переведённое.
// Сортирует ключи: @@системные → обычные (алфавитно) + @метаданные рядом.

import 'dart:convert';
import 'dart:io';
import 'path_utils.dart';
import 'translator/provider.dart';
import 'config.dart';

class ArbWriter {
  final ArbPilotConfig config;

  ArbWriter(this.config);

  /// Записать список записей в соответствующие .arb файлы
  Future<int> write(List<TranslationRecord> records, {bool dryRun = false}) async {
    if (records.isEmpty) return 0;

    // Группируем: module → locale → [records]
    final grouped = <String, Map<String, List<TranslationRecord>>>{};
    for (final r in records) {
      grouped
          .putIfAbsent(r.module, () => {})
          .putIfAbsent(r.targetLocale, () => [])
          .add(r);
    }

    var written = 0;
    for (final moduleEntry in grouped.entries) {
      for (final localeEntry in moduleEntry.value.entries) {
        final count = await _mergeIntoArb(
          module:  moduleEntry.key,
          locale:  localeEntry.key,
          records: localeEntry.value,
          dryRun:  dryRun,
        );
        written += count;
      }
    }
    return written;
  }

  Future<int> _mergeIntoArb({
    required String module,
    required String locale,
    required List<TranslationRecord> records,
    required bool dryRun,
  }) async {
    final filePath = _resolveArbPath(module, locale);
    final file = File(filePath);

    // Читаем существующий файл
    Map<String, dynamic> existing = {'@@locale': locale};
    if (file.existsSync()) {
      try {
        existing = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        // битый arb — начинаем с чистого
        existing = {'@@locale': locale};
      }
    } else if (!dryRun) {
      await file.parent.create(recursive: true);
    }

    // Мержим
    var added = 0;
    for (final record in records) {
      // Не перезаписываем уже существующий перевод
      if (existing.containsKey(record.key)) continue;

      existing[record.key] = record.translatedText;
      existing['@${record.key}'] = {
        'description': record.needsReview
            ? 'Auto-translated by ${record.providerName}. NEEDS REVIEW.'
            : 'Auto-translated by ${record.providerName}.',
        if (record.needsReview) 'x-needs-review': true,
        if (record.sourceText != null) 'x-source': record.sourceText,
      };
      added++;
    }

    if (added == 0) return 0;

    existing['@@last_modified'] = DateTime.now().toIso8601String();

    if (!dryRun) {
      final sorted = _sortKeys(existing);
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString('${encoder.convert(sorted)}\n');
      stdout.writeln(
        '  ✓ ${PathUtils.relative(filePath, from: config.projectRoot)} '
        '(+$added)',
      );
    }

    return added;
  }

  /// Удалить orphaned ключи из .arb файла
  Future<int> removeOrphaned(
    String arbPath,
    List<String> keysToRemove, {
    bool dryRun = false,
  }) async {
    if (keysToRemove.isEmpty) return 0;
    final file = File(arbPath);
    if (!file.existsSync()) return 0;

    Map<String, dynamic> content;
    try {
      content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return 0;
    }

    var removed = 0;
    for (final key in keysToRemove) {
      if (content.remove(key) != null) removed++;
      content.remove('@$key'); // и метаданные
    }

    if (removed > 0 && !dryRun) {
      content['@@last_modified'] = DateTime.now().toIso8601String();
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString('${encoder.convert(_sortKeys(content))}\n');
      stdout.writeln(
        '  🗑  ${PathUtils.relative(arbPath, from: config.projectRoot)} '
        '(-$removed orphaned)',
      );
    }

    return removed;
  }

  // ── Path resolver ─────────────────────────────────────────────────────────────

  String _resolveArbPath(String module, String locale) {
    final prefix = config.arbPrefix;

    if (module == 'core') {
      return PathUtils.join(
        config.projectRoot, 'lib', 'core', 'l10n',
        '${prefix}_$locale.arb',
      );
    }

    if (module.startsWith('pkg_')) {
      final pkgName = module.substring(4);
      return PathUtils.join(
        config.projectRoot, 'packages', pkgName, 'lib', 'l10n',
        '${pkgName}_$locale.arb',
      );
    }

    // Feature module
    return PathUtils.join(
      config.projectRoot, 'lib', 'features', module, 'l10n',
      '${module}_$locale.arb',
    );
  }

  // ── Key sorter ────────────────────────────────────────────────────────────────

  /// Порядок: @@locale → @@прочие → ключи алфавитно + @мета сразу за ключом
  Map<String, dynamic> _sortKeys(Map<String, dynamic> map) {
    final system   = <String, dynamic>{};
    final regular  = <String, dynamic>{};
    final metadata = <String, dynamic>{};

    for (final e in map.entries) {
      if (e.key.startsWith('@@')) {
        system[e.key] = e.value;
      } else if (e.key.startsWith('@')) {
        metadata[e.key] = e.value;
      } else {
        regular[e.key] = e.value;
      }
    }

    final sorted = <String, dynamic>{};

    // @@locale первым
    if (system.containsKey('@@locale')) sorted['@@locale'] = system['@@locale'];
    for (final e in system.entries) {
      if (e.key != '@@locale') sorted[e.key] = e.value;
    }

    // Обычные ключи алфавитно, сразу за каждым — его @-мета
    final keys = regular.keys.toList()..sort();
    for (final key in keys) {
      sorted[key] = regular[key];
      if (metadata.containsKey('@$key')) {
        sorted['@$key'] = metadata['@$key'];
      }
    }

    return sorted;
  }
}
