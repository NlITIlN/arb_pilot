// lib/tools/i18n/discovery.dart
//
// Шаг 1: Поиск .arb файлов и .dart файлов.
// Поддерживает glob-паттерны из arb_pilot.yaml:
//   lib/core/l10n
//   lib/features/*/l10n
//   packages/*/lib/l10n

import 'dart:io';
import 'config.dart';
import 'path_utils.dart';

// ── Модели ────────────────────────────────────────────────────────────────────

/// Найденный .arb файл с метаданными
class ArbFile {
  final String path;
  final String langCode;  // 'en', 'ru', 'zh'
  final String module;    // 'core', 'auth', 'pkg/ui_kit'

  /// Содержимое: ключ → значение (только строковые, без @-мета)
  final Map<String, dynamic> entries;

  const ArbFile({
    required this.path,
    required this.langCode,
    required this.module,
    required this.entries,
  });

  Set<String> get keys => entries.keys.toSet();

  /// Контекст для ключа из @-метаданных
  String? contextFor(String key) {
    final meta = entries['@$key'];
    if (meta is Map) return meta['description'] as String?;
    return null;
  }

  @override
  String toString() => '[$module/$langCode] $path';
}

/// Результат поиска: индекс всех .arb файлов по модулю и локали
class ArbDiscoveryResult {
  /// module → langCode → ArbFile
  final Map<String, Map<String, ArbFile>> byModule;

  const ArbDiscoveryResult(this.byModule);

  Set<String> get modules => byModule.keys.toSet();

  ArbFile? get(String module, String langCode) =>
      byModule[module]?[langCode];

  List<ArbFile> get all {
    final result = <ArbFile>[];
    for (final m in byModule.values) {
      result.addAll(m.values);
    }
    return result;
  }

  int get totalFiles => all.length;
}

// ── Discovery ─────────────────────────────────────────────────────────────────

class ArbDiscovery {
  final ArbPilotConfig config;

  ArbDiscovery(this.config);

  /// Найти и загрузить все .arb файлы согласно конфигу
  Future<ArbDiscoveryResult> findArbFiles() async {
    final byModule = <String, Map<String, ArbFile>>{};

    for (final pattern in config.l10nPaths) {
      final dirs = await _resolveGlob(pattern);
      for (final dir in dirs) {
        final module = _moduleFromPath(dir, pattern);
        await _scanArbDir(dir, module, byModule);
      }
    }

    return ArbDiscoveryResult(byModule);
  }

  /// Найти все .dart файлы для парсинга
  Future<List<String>> findDartFiles() async {
    final files = <String>[];
    final roots = [
      PathUtils.join(config.projectRoot, 'lib'),
    ];

    // Локальные пакеты
    final pkgsDir = Directory(PathUtils.join(config.projectRoot, 'packages'));
    if (pkgsDir.existsSync()) {
      for (final d in pkgsDir.listSync().whereType<Directory>()) {
        roots.add(PathUtils.join(d.path, 'lib'));
      }
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!path.endsWith('.dart')) continue;
        if (path.endsWith('.g.dart')) continue;
        if (path.endsWith('.freezed.dart')) continue;
        if (path.contains('${PathUtils.sep}tools${PathUtils.sep}i18n')) continue;
        if (path.contains('${PathUtils.sep}bin${PathUtils.sep}')) continue;
        files.add(path);
      }
    }

    return files;
  }

  // ── Glob resolver ───────────────────────────────────────────────────────────

  /// Разворачивает паттерн вида "lib/features/*/l10n" в список реальных путей
  Future<List<String>> _resolveGlob(String pattern) async {
    final full = PathUtils.join(config.projectRoot, pattern);

    if (!pattern.contains('*')) {
      return [full];
    }

    final segments = full.split(PathUtils.sep);
    return _expandGlob(segments, 0, '');
  }

  Future<List<String>> _expandGlob(
    List<String> segments,
    int index,
    String current,
  ) async {
    if (index >= segments.length) return [current];

    final seg = segments[index];
    final results = <String>[];

    if (seg == '*') {
      final parentDir = Directory(current.isEmpty ? '.' : current);
      if (!parentDir.existsSync()) return [];

      for (final entity in parentDir.listSync().whereType<Directory>()) {
        final sub = entity.path;
        final expanded = await _expandGlob(segments, index + 1, sub);
        results.addAll(expanded);
      }
    } else {
      final next = current.isEmpty ? seg : '$current${PathUtils.sep}$seg';
      final expanded = await _expandGlob(segments, index + 1, next);
      results.addAll(expanded);
    }

    return results;
  }

  // ── ARB scanner ─────────────────────────────────────────────────────────────

  Future<void> _scanArbDir(
    String dirPath,
    String module,
    Map<String, Map<String, ArbFile>> byModule,
  ) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = PathUtils.basename(entity.path);
      if (!name.endsWith('.arb')) continue;

      final langCode = _extractLangCode(name);
      if (langCode == null) continue;

      final entries = await _loadArbFile(entity.path);
      if (entries == null) continue;

      byModule.putIfAbsent(module, () {})[langCode] = ArbFile(
        path: entity.path,
        langCode: langCode,
        module: module,
        entries: entries,
      );
    }
  }

  Future<Map<String, dynamic>?> _loadArbFile(String path) async {
    try {
      final content = await File(path).readAsString();
      // Базовый JSON парсер — dart:convert
      final raw = _jsonDecode(content);
      if (raw is! Map<String, dynamic>) return null;
      return raw;
    } catch (e) {
      stderr.writeln('  ⚠️  Ошибка чтения $path: $e');
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// app_en.arb → 'en', intl_ru.arb → 'ru', messages_zh_CN.arb → 'zh_CN'
  String? _extractLangCode(String filename) {
    // Ищем паттерн: PREFIX_LANGCODE.arb
    final match = RegExp(r'[_-]([a-z]{2}(?:_[A-Z]{2})?)\.arb$')
        .firstMatch(filename);
    return match?.group(1);
  }

  /// Определяет имя модуля из пути
  String _moduleFromPath(String resolvedPath, String pattern) {
    // lib/core/l10n → core
    if (pattern == 'lib/core/l10n' || resolvedPath.contains('/core/')) {
      return 'core';
    }

    // lib/features/*/l10n → имя фичи
    if (pattern.contains('features/*/')) {
      final parts = resolvedPath.split(PathUtils.sep);
      final idx = parts.lastIndexOf('features');
      if (idx >= 0 && idx + 1 < parts.length) {
        return parts[idx + 1];
      }
    }

    // packages/*/lib/l10n → pkg_имяпакета
    if (pattern.contains('packages/*/')) {
      final parts = resolvedPath.split(PathUtils.sep);
      final idx = parts.lastIndexOf('packages');
      if (idx >= 0 && idx + 1 < parts.length) {
        return 'pkg_${parts[idx + 1]}';
      }
    }

    // Фоллбэк — последняя значимая часть пути
    final parts = resolvedPath.split(PathUtils.sep);
    // Пропускаем 'l10n', 'lib'
    for (final skip in ['l10n', 'lib']) {
      if (parts.last == skip && parts.length > 1) {
        return parts[parts.length - 2];
      }
    }
    return parts.last;
  }

  // Встроенный JSON decoder без зависимостей
  static dynamic _jsonDecode(String source) {
    return _JsonParser(source).parse();
  }
}

// ── Минимальный JSON парсер (dart:convert уже есть в SDK) ────────────────────
// Используем dart:convert через динамический импорт чтобы не было конфликтов

class _JsonParser {
  final String _source;
  int _pos = 0;

  _JsonParser(this._source);

  dynamic parse() {
    _skipWhitespace();
    final value = _parseValue();
    return value;
  }

  dynamic _parseValue() {
    _skipWhitespace();
    if (_pos >= _source.length) throw FormatException('Unexpected end of input');

    final ch = _source[_pos];
    if (ch == '{') return _parseObject();
    if (ch == '[') return _parseArray();
    if (ch == '"') return _parseString();
    if (ch == 't') return _parseLiteral('true', true);
    if (ch == 'f') return _parseLiteral('false', false);
    if (ch == 'n') return _parseLiteral('null', null);
    if (ch == '-' || _isDigit(ch)) return _parseNumber();
    throw FormatException('Unexpected character: $ch at pos $_pos');
  }

  Map<String, dynamic> _parseObject() {
    _expect('{');
    final map = <String, dynamic>{};
    _skipWhitespace();
    if (_pos < _source.length && _source[_pos] == '}') {
      _pos++;
      return map;
    }
    while (true) {
      _skipWhitespace();
      final key = _parseString();
      _skipWhitespace();
      _expect(':');
      _skipWhitespace();
      final value = _parseValue();
      map[key] = value;
      _skipWhitespace();
      if (_pos >= _source.length) break;
      if (_source[_pos] == '}') { _pos++; break; }
      _expect(',');
    }
    return map;
  }

  List<dynamic> _parseArray() {
    _expect('[');
    final list = <dynamic>[];
    _skipWhitespace();
    if (_pos < _source.length && _source[_pos] == ']') {
      _pos++;
      return list;
    }
    while (true) {
      _skipWhitespace();
      list.add(_parseValue());
      _skipWhitespace();
      if (_pos >= _source.length) break;
      if (_source[_pos] == ']') { _pos++; break; }
      _expect(',');
    }
    return list;
  }

  String _parseString() {
    _expect('"');
    final buf = StringBuffer();
    while (_pos < _source.length) {
      final ch = _source[_pos++];
      if (ch == '"') break;
      if (ch == '\\') {
        final esc = _source[_pos++];
        switch (esc) {
          case '"': buf.write('"'); break;
          case '\\': buf.write('\\'); break;
          case '/': buf.write('/'); break;
          case 'n': buf.write('\n'); break;
          case 'r': buf.write('\r'); break;
          case 't': buf.write('\t'); break;
          case 'u':
            final hex = _source.substring(_pos, _pos + 4);
            _pos += 4;
            buf.writeCharCode(int.parse(hex, radix: 16));
            break;
          default: buf.write(esc);
        }
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  dynamic _parseLiteral(String lit, dynamic value) {
    if (_source.startsWith(lit, _pos)) {
      _pos += lit.length;
      return value;
    }
    throw FormatException('Expected $lit at pos $_pos');
  }

  num _parseNumber() {
    final start = _pos;
    if (_pos < _source.length && _source[_pos] == '-') _pos++;
    while (_pos < _source.length && _isDigit(_source[_pos])) _pos++;
    final isFloat = _pos < _source.length &&
        (_source[_pos] == '.' || _source[_pos] == 'e' || _source[_pos] == 'E');
    if (isFloat) {
      while (_pos < _source.length &&
          (_isDigit(_source[_pos]) ||
              _source[_pos] == '.' ||
              _source[_pos] == 'e' ||
              _source[_pos] == 'E' ||
              _source[_pos] == '+' ||
              _source[_pos] == '-')) _pos++;
      return double.parse(_source.substring(start, _pos));
    }
    return int.parse(_source.substring(start, _pos));
  }

  void _skipWhitespace() {
    while (_pos < _source.length && _source[_pos].trim().isEmpty) _pos++;
  }

  void _expect(String ch) {
    if (_pos >= _source.length || _source[_pos] != ch) {
      throw FormatException('Expected $ch at pos $_pos, got '
          '${_pos < _source.length ? _source[_pos] : 'EOF'}');
    }
    _pos++;
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
}
