// lib/tools/i18n/ast_parser.dart
//
// Шаг 2: Извлечение ключей локализации из Dart-кода.
// Использует regex (без analyzer) — быстро, без зависимостей.
// Паттерны accessor настраиваются через arb_pilot.yaml.

import 'dart:io';
import 'path_utils.dart';
import 'config.dart';

// ── Модели ────────────────────────────────────────────────────────────────────

class FoundKey {
  final String key;
  final String file;       // относительный путь
  final int line;
  final String module;

  /// Контекст из // @i18n-context: ... комментария
  final String? inlineContext;

  const FoundKey({
    required this.key,
    required this.file,
    required this.line,
    required this.module,
    this.inlineContext,
  });

  @override
  String toString() => '$module::$key ($file:$line)';
}

// ── Parser ────────────────────────────────────────────────────────────────────

class AstParser {
  final ArbPilotConfig config;

  /// Скомпилированные regex из списка accessor'ов
  late final List<RegExp> _patterns;

  static final _contextAnnotation = RegExp(
    r'//\s*@i18n-context:\s*(.+)$',
  );

  AstParser(this.config) {
    _patterns = _buildPatterns(config.accessors);
  }

  /// Парсит все dart-файлы и возвращает список уникальных ключей
  Future<List<FoundKey>> extractKeys(List<String> dartFiles) async {
    // key → лучший FoundKey (приоритет — с контекстом)
    final seen = <String, FoundKey>{};

    for (final filePath in dartFiles) {
      try {
        final keys = await _parseFile(filePath);
        for (final k in keys) {
          final existing = seen[k.key];
          if (existing == null ||
              (existing.inlineContext == null && k.inlineContext != null)) {
            seen[k.key] = k;
          }
        }
      } catch (e) {
        if (config.debug) {
          stderr.writeln('  ⚠️  Ошибка парсинга $filePath: $e');
        }
      }
    }

    return seen.values.toList();
  }

  Future<List<FoundKey>> _parseFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    final lines = await file.readAsLines();
    final results = <FoundKey>[];
    final seenInFile = <String>{};

    // Собираем @i18n-context аннотации: lineIndex → context
    final contextMap = <int, String>{};
    for (var i = 0; i < lines.length; i++) {
      final m = _contextAnnotation.firstMatch(lines[i]);
      if (m != null) {
        // Контекст применяется к строке с аннотацией И следующей
        contextMap[i] = m.group(1)!.trim();
        if (i + 1 < lines.length) contextMap[i + 1] = m.group(1)!.trim();
      }
    }

    // Ищем ключи
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final context = contextMap[i];

      for (final pattern in _patterns) {
        for (final match in pattern.allMatches(line)) {
          final key = match.group(1);
          if (key == null || !_isValidKey(key)) continue;
          if (seenInFile.contains(key)) continue;
          seenInFile.add(key);

          results.add(FoundKey(
            key: key,
            file: PathUtils.relative(filePath, from: config.projectRoot),
            line: i + 1,
            module: _moduleFromPath(filePath),
            inlineContext: context,
          ));
        }
      }
    }

    return results;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Строит regex из accessor'ов конфига.
  /// "l10n" → l10n[!?]?\\.([a-zA-Z][a-zA-Z0-9_]*)
  /// "AppLocalizations.of(context)" → AppLocalizations\.of\(context\)[!?]?\\.([...])
  static List<RegExp> _buildPatterns(List<String> accessors) {
    final patterns = <RegExp>[];

    for (final accessor in accessors) {
      // Экранируем спецсимволы regex для статичной части
      final escaped = RegExp.escape(accessor);
      // После accessor может быть ?. или !. (null-safe) или просто .
      final pattern = RegExp('$escaped[!?]?\\.([a-zA-Z][a-zA-Z0-9_]*)');
      patterns.add(pattern);
    }

    return patterns;
  }

  static const _systemKeys = {
    'of', 'delegate', 'supportedLocales', 'toString',
    'hashCode', 'runtimeType', 'noSuchMethod',
  };

  bool _isValidKey(String key) {
    if (_systemKeys.contains(key)) return false;
    if (key.isEmpty) return false;
    // camelCase: первая буква — строчная
    if (key[0] != key[0].toLowerCase()) return false;
    return true;
  }

  String _moduleFromPath(String filePath) {
    final rel = PathUtils.relative(filePath, from: config.projectRoot);
    final parts = rel.split(PathUtils.sep);

    // lib/features/MODULE/...
    final featIdx = parts.indexOf('features');
    if (featIdx >= 0 && featIdx + 1 < parts.length) {
      return parts[featIdx + 1];
    }

    // lib/core/...
    if (parts.contains('core')) return 'core';

    // packages/PKG/...
    final pkgIdx = parts.indexOf('packages');
    if (pkgIdx >= 0 && pkgIdx + 1 < parts.length) {
      return 'pkg_${parts[pkgIdx + 1]}';
    }

    return 'core'; // фоллбэк
  }
}
