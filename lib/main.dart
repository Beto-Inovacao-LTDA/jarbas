import 'package:flutter/material.dart';

import 'settings_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarbas (dev)',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const SettingsTestPage(),
    );
  }
}

// Tela temporária para validar a spec 01 (SettingsStore) na tela do
// aparelho. Será substituída pela UI real na spec 03.
class SettingsTestPage extends StatefulWidget {
  const SettingsTestPage({super.key});

  @override
  State<SettingsTestPage> createState() => _SettingsTestPageState();
}

class _SettingsTestPageState extends State<SettingsTestPage> {
  final _store = SettingsStore();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  List<Shortcut> _shortcuts = [];
  bool _autostart = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _store.getBaseUrl();
    final token = await _store.getToken();
    final shortcuts = await _store.getShortcuts();
    final autostart = await _store.getJarbasAutostart();
    setState(() {
      _urlController.text = url ?? '';
      _tokenController.text = token ?? '';
      _shortcuts = shortcuts;
      _autostart = autostart;
      _loading = false;
    });
  }

  Future<void> _saveUrl() async {
    await _store.setBaseUrl(_urlController.text);
    _snack('URL salva');
  }

  Future<void> _saveToken() async {
    await _store.setToken(_tokenController.text);
    _snack('Token salvo');
  }

  Future<void> _toggleAutostart(bool value) async {
    await _store.setJarbasAutostart(value);
    setState(() => _autostart = value);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Jarbas — teste SettingsStore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'URL do Home Assistant',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.15.13:8123',
                  ),
                ),
              ),
              IconButton(onPressed: _saveUrl, icon: const Icon(Icons.save)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Token (Long-Lived Access Token)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'eyJ...'),
                ),
              ),
              IconButton(onPressed: _saveToken, icon: const Icon(Icons.save)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Atalhos (padrão se nada salvo)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._shortcuts.map(
            (s) => ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(s.label),
              subtitle: Text('"${s.phrase}"'),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Iniciar Modo Jarbas automaticamente'),
            value: _autostart,
            onChanged: _toggleAutostart,
          ),
        ],
      ),
    );
  }
}
