import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static const _fileName = 'vidalis_crash.log';
  static const _maxEntries = 200;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Persiste un error en disco y lo imprime en consola.
  static Future<void> log(String context, Object error, [StackTrace? stack]) async {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] [$context]\n$error\n${stack ?? "(sin stack)"}\n---\n';
    debugPrint('🔴 [CrashLogger][$context] $error');
    try {
      final f = await _file();
      await f.writeAsString(entry, mode: FileMode.append, flush: true);
      await _trim(f);
    } catch (e) {
      debugPrint('CrashLogger write error: $e');
    }
  }

  /// Devuelve el contenido del log como string.
  static Future<String> getLogs() async {
    try {
      final f = await _file();
      if (!await f.exists()) return 'Sin logs disponibles.';
      return await f.readAsString();
    } catch (e) {
      return 'Error leyendo logs: $e';
    }
  }

  /// Ruta al archivo de log (para compartir con el equipo).
  static Future<String?> getLogPath() async {
    try {
      final f = await _file();
      return await f.exists() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<void> _trim(File f) async {
    final lines = await f.readAsLines();
    final separators = <int>[];
    for (int i = 0; i < lines.length; i++) {
      if (lines[i] == '---') separators.add(i);
    }
    if (separators.length > _maxEntries) {
      final cutLine = separators[separators.length - _maxEntries];
      final trimmed = lines.sublist(cutLine + 1).join('\n');
      await f.writeAsString(trimmed, flush: true);
    }
  }
}
