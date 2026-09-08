import 'dart:html' as html;

const _storageKey = 'titans.theme.preference';

Future<String?> readThemePreference() async =>
    html.window.localStorage[_storageKey];

Future<void> writeThemePreference(String value) async {
  html.window.localStorage[_storageKey] = value;
}
