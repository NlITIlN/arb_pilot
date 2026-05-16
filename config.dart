// lib/tools/i18n/config.dart
//
// Единственный источник настроек arb_pilot.
// Читает arb_pilot.yaml (если есть) и CLI аргументы.
// CLI аргументы имеют приоритет над конфигом.

import 'dart:io';

class ArbPilotConfig {
  // ── Языки ────────────────────────────────────────────────
  final String sourceLang;
  final List<String> targetLangs;

  // ── Пути ─────────────────────────────────────────────────
  final String projectRoot;
  final List<String> l10nPaths;
  final String arbPrefix;

  // ── Паттерны обращения к переводам ───────────────────────
  final List<String> accessors;

  // ── Провайдеры ───────────────────────────────────────────
  final String? deeplKey;
  final String? googleKey;
  final String? yandexKey;
  final String ollamaHost;
  final String ollamaModel;

  // ── Режим работы ─────────────────────────────────────────
  final bool autoMode;
  final bool interactiveMode;
  final bool dryRun;
  final bool removeOrphaned;

  // ── Вывод ────────────────────────────────────────────────
  final bool jsonOutput;
  final bool useColor;
  final bool debug;

  const ArbPilotConfig({
    required this.sourceLang,
    required this.targetLangs,
    required this.projectRoot,
    required this.l10nPaths,
    required this.arbPrefix,
    required this.accessors,
    this.deeplKey,
    this.googleKey,
    this.yandexKey,
    required this.ollamaHost,
    required this.ollamaModel,
    required this.autoMode,
    required this.interactiveMode,
    required this.dryRun,
    required this.removeOrphaned,
    required this.jsonOutput,
    required this.useColor,
    required this.debug,
  });

  // ── Defaults ─────────────────────────────────────────────

  static const _defaultSourceLang = 'en';
  static const _defaultTargetLangs = ['ru', 'zh', 'hi', 'es'];
  static const _defaultL10nPaths = ['lib/core/l10n', 'lib/features/*/l10n'];
  static const _defaultAccessors = ['l10n', 'AppLocalizations.of(context)'];
  static const _defaultArbPrefix = 'app';
  static const _defaultOllamaHost = 'http://localhost:11434';
  static const _defaultOllamaModel = 'llama3';

  // ── Factory: из CLI аргументов + yaml ────────────────────

  factory ArbPilotConfig.fromArgs(List<String> args) {
    // Сначала определяем root, чтобы найти yaml
    final rootArg = _argValue(args, '--root') ??
        Platform.environment['ARB_PILOT_ROOT'] ??
        Directory.current.path;
    final projectRoot = _normalizePath(rootArg);

    // Читаем yaml
    final yaml = _loadYaml(projectRoot);

    // ── Языки
    final sourceLang = _argValue(args, '--source-lang') ??
        yaml['source_lang'] as String? ??
        _defaultSourceLang;

    final targetLangsArg = _argValue(args, '--langs');
    final List<String> targetLangs = targetLangsArg != null
        ? targetLangsArg.split(',').map((s) => s.trim()).toList()
        : _yamlStringList(yaml, 'target_langs') ?? _defaultTargetLangs;

    // ── Пути
    final List<String> l10nPaths =
        _yamlStringList(yaml, 'l10n_paths') ?? _defaultL10nPaths;

    final arbPrefix =
        yaml['arb_prefix'] as String? ?? _defaultArbPrefix;

    // ── Accessors
    final List<String> accessors =
        _yamlStringList(yaml, 'accessors') ?? _defaultAccessors;

    // ── Провайдеры
    final deeplKey = _argValue(args, '--deepl-key') ??
        Platform.environment['DEEPL_API_KEY'];
    final googleKey = _argValue(args, '--google-key') ??
        Platform.environment['GOOGLE_TRANSLATE_KEY'];
    final yandexKey = _argValue(args, '--yandex-key') ??
        Platform.environment['YANDEX_TRANSLATE_KEY'];
    final ollamaHost = _argValue(args, '--ollama-host') ??
        Platform.environment['OLLAMA_HOST'] ??
        _defaultOllamaHost;
    final ollamaModel = _argValue(args, '--ollama-model') ??
        Platform.environment['OLLAMA_MODEL'] ??
        _defaultOllamaModel;

    // ── Режимы
    final autoMode = args.contains('--auto');
    final interactiveMode = args.contains('--interactive');
    final dryRun = args.contains('--dry-run');
    final removeOrphaned = args.contains('--remove-orphaned');

    // ── Вывод
    final jsonOutput = _argValue(args, '--format') == 'json';
    final useColor = !args.contains('--no-color');
    final debug = args.contains('--debug') ||
        Platform.environment['DEBUG'] == '1';

    return ArbPilotConfig(
      sourceLang: sourceLang,
      targetLangs: targetLangs,
      projectRoot: projectRoot,
      l10nPaths: l10nPaths,
      arbPrefix: arbPrefix,
      accessors: accessors,
      deeplKey: (deeplKey?.isNotEmpty == true) ? deeplKey : null,
      googleKey: (googleKey?.isNotEmpty == true) ? googleKey : null,
      yandexKey: (yandexKey?.isNotEmpty == true) ? yandexKey : null,
      ollamaHost: ollamaHost,
      ollamaModel: ollamaModel,
      autoMode: autoMode,
      interactiveMode: interactiveMode,
      dryRun: dryRun,
      removeOrphaned: removeOrphaned,
      jsonOutput: jsonOutput,
      useColor: useColor,
      debug: debug,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  static String? _argValue(List<String> args, String name) {
    for (final arg in args) {
      if (arg.startsWith('$name=')) {
        return arg.substring(name.length + 1);
      }
    }
    return null;
  }

  static String _normalizePath(String path) {
    if (path == '.') return Directory.current.path;
    if (!path.startsWith('/') && !path.startsWith(r'\')) {
      return '${Directory.current.path}${Platform.pathSeparator}$path';
    }
    return path;
  }

  static List<String>? _yamlStringList(Map<String, dynamic> yaml, String key) {
    final value = yaml[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  /// Минимальный YAML парсер без зависимостей.
  /// Поддерживает: строки, списки через дефис, комментарии.
  static Map<String, dynamic> _loadYaml(String projectRoot) {
    final file = File('$projectRoot${Platform.pathSeparator}arb_pilot.yaml');
    if (!file.existsSync()) return {};

    try {
      final lines = file.readAsLinesSync();
      final result = <String, dynamic>{};
      String? currentKey;
      final currentList = <String>[];

      void flushList() {
        if (currentKey != null && currentList.isNotEmpty) {
          result[currentKey!] = List<String>.from(currentList);
          currentList.clear();
          currentKey = null;
        }
      }

      for (var rawLine in lines) {
        // Убираем комментарии
        final commentIdx = rawLine.indexOf('#');
        if (commentIdx >= 0) rawLine = rawLine.substring(0, commentIdx);
        final line = rawLine.trimRight();
        if (line.trim().isEmpty) continue;

        // Элемент списка: "  - value"
        final listMatch = RegExp(r'^\s+-\s+(.+)$').firstMatch(line);
        if (listMatch != null) {
          currentList.add(listMatch.group(1)!.trim());
          continue;
        }

        // Пара ключ: значение
        final kvMatch = RegExp(r'^(\w+):\s*(.*)$').firstMatch(line.trim());
        if (kvMatch != null) {
          flushList(); // сохраняем предыдущий список
          final key = kvMatch.group(1)!;
          final val = kvMatch.group(2)!.trim();
          if (val.isEmpty) {
            // Следующие строки — список
            currentKey = key;
          } else {
            result[key] = _unquote(val);
          }
        }
      }
      flushList();
      return result;
    } catch (e) {
      stderr.writeln('⚠️  Ошибка чтения arb_pilot.yaml: $e');
      return {};
    }
  }

  static String _unquote(String s) {
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }
}
