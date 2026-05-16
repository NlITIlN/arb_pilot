// lib/tools/i18n/path_utils.dart
//
// Минималистичный хелпер для работы с путями — заменяет package:path.
// Zero dependencies — только dart:io для Platform.pathSeparator.

import 'dart:io';

/// Простая замена `package:path` без зависимостей.
/// Покрывает только то, что нужно arb_pilot.
class PathUtils {
  static final String sep = Platform.pathSeparator;

  /// Объединяет части пути (аналог path.join)
  static String join(String first, [
    String? p2, String? p3, String? p4, String? p5,
  ]) {
    var result = first;
    for (final part in [p2, p3, p4, p5]) {
      if (part == null || part.isEmpty) continue;
      if (result.endsWith(sep)) {
        result = '$result$part';
      } else {
        result = '$result$sep$part';
      }
    }
    return result;
  }

  /// Возвращает имя файла (аналог path.basename)
  static String basename(String path) {
    final normalized = path.replaceAll('/', sep).replaceAll('\\', sep);
    final idx = normalized.lastIndexOf(sep);
    return idx < 0 ? normalized : normalized.substring(idx + 1);
  }

  /// Возвращает расширение файла (аналог path.extension)
  static String extension(String path) {
    final base = basename(path);
    final idx = base.lastIndexOf('.');
    return idx < 0 ? '' : base.substring(idx);
  }

  /// Возвращает путь без расширения (аналог path.basenameWithoutExtension)
  static String basenameWithoutExtension(String path) {
    final base = basename(path);
    final idx = base.lastIndexOf('.');
    return idx < 0 ? base : base.substring(0, idx);
  }

  /// Возвращает директорию (аналог path.dirname)
  static String dirname(String path) {
    final normalized = path.replaceAll('/', sep).replaceAll('\\', sep);
    final idx = normalized.lastIndexOf(sep);
    if (idx < 0) return '.';
    if (idx == 0) return sep;
    return normalized.substring(0, idx);
  }

  /// Относительный путь от [from] до [path] (аналог path.relative)
  static String relative(String path, {required String from}) {
    final p = _normalize(path);
    final f = _normalize(from);
    if (p.startsWith(f)) {
      var rel = p.substring(f.length);
      if (rel.startsWith(sep)) rel = rel.substring(sep.length);
      return rel.isEmpty ? '.' : rel;
    }
    return p;
  }

  /// Нормализует разделители
  static String _normalize(String path) {
    return path.replaceAll('/', sep).replaceAll('\\', sep);
  }
}
