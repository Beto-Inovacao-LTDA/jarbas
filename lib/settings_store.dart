import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Shortcut {
  final String label;
  final String phrase;

  const Shortcut({required this.label, required this.phrase});

  Map<String, dynamic> toJson() => {'label': label, 'phrase': phrase};

  factory Shortcut.fromJson(Map<String, dynamic> json) => Shortcut(
    label: json['label'] as String,
    phrase: json['phrase'] as String,
  );
}

class SettingsStore {
  static const _keyBaseUrl = 'ha_base_url';
  static const _keyToken = 'ha_token';
  static const _keyShortcuts = 'ha_shortcuts';
  static const _keyJarbasAutostart = 'jarbas_autostart';

  Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl);
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, value);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> setToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, value);
  }

  Future<List<Shortcut>> getShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyShortcuts);
    if (raw == null) {
      final defaults = defaultShortcuts();
      await setShortcuts(defaults);
      return defaults;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => Shortcut.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> setShortcuts(List<Shortcut> shortcuts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(shortcuts.map((s) => s.toJson()).toList());
    await prefs.setString(_keyShortcuts, raw);
  }

  Future<bool> getJarbasAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyJarbasAutostart) ?? false;
  }

  Future<void> setJarbasAutostart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyJarbasAutostart, value);
  }

  List<Shortcut> defaultShortcuts() => const [
    Shortcut(label: 'Acender luzes', phrase: 'acender as luzes'),
    Shortcut(label: 'Apagar luzes', phrase: 'apagar as luzes'),
    Shortcut(label: 'Trancar tudo', phrase: 'trancar tudo'),
  ];
}
