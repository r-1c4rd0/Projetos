import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _fileName = 'titans_theme_preference.json';
const _jsonKey = 'theme';

Future<File> _preferenceFile() async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}${Platform.pathSeparator}$_fileName');
}

Future<String?> readThemePreference() async {
  try {
    final file = await _preferenceFile();
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is Map<String, Object?>) {
      return decoded[_jsonKey]?.toString();
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> writeThemePreference(String value) async {
  final file = await _preferenceFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode({_jsonKey: value}));
}
