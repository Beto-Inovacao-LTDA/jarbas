import 'package:flutter/material.dart';

import 'ha_service.dart';
import 'settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.store, this.haService});

  final SettingsStore? store;
  final HaService? haService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsStore _store = widget.store ?? SettingsStore();
  late final HaService _haService = widget.haService ?? HaService();

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _shortcutLabelController = TextEditingController();
  final _shortcutPhraseController = TextEditingController();

  List<Shortcut> _shortcuts = [];
  bool _loading = true;
  bool _testingConnection = false;
  String? _testResultMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _shortcutLabelController.dispose();
    _shortcutPhraseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await _store.getBaseUrl();
    final token = await _store.getToken();
    final shortcuts = await _store.getShortcuts();
    setState(() {
      _urlController.text = url ?? '';
      _tokenController.text = token ?? '';
      _shortcuts = shortcuts;
      _loading = false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testResultMessage = null;
    });
    final ok = await _haService.testConnection(
      _urlController.text,
      _tokenController.text,
    );
    if (!mounted) return;
    setState(() {
      _testingConnection = false;
      _testResultMessage = ok ? 'Conexão bem-sucedida' : 'Falha na conexão';
    });
  }

  Future<void> _save() async {
    await _store.setBaseUrl(_urlController.text);
    await _store.setToken(_tokenController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configurações salvas')));
  }

  Future<void> _addShortcut() async {
    final label = _shortcutLabelController.text.trim();
    final phrase = _shortcutPhraseController.text.trim();
    if (label.isEmpty || phrase.isEmpty) return;

    final updated = [..._shortcuts, Shortcut(label: label, phrase: phrase)];
    await _store.setShortcuts(updated);
    setState(() {
      _shortcuts = updated;
      _shortcutLabelController.clear();
      _shortcutPhraseController.clear();
    });
  }

  Future<void> _removeShortcut(int index) async {
    final updated = [..._shortcuts]..removeAt(index);
    await _store.setShortcuts(updated);
    setState(() => _shortcuts = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'URL do Home Assistant',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            key: const Key('url_field'),
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'http://192.168.15.13:8123',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Token (Long-Lived Access Token)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            key: const Key('token_field'),
            controller: _tokenController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'eyJ...'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                key: const Key('test_connection_button'),
                onPressed: _testingConnection ? null : _testConnection,
                child: _testingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Testar conexão'),
              ),
              const SizedBox(width: 12),
              if (_testResultMessage != null)
                Expanded(
                  key: const Key('test_connection_result'),
                  child: Text(_testResultMessage!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save_button'),
            onPressed: _save,
            child: const Text('Salvar'),
          ),
          const Divider(height: 32),
          const Text(
            'Atalhos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._shortcuts.asMap().entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(entry.value.label),
              subtitle: Text('"${entry.value.phrase}"'),
              trailing: IconButton(
                key: Key('remove_shortcut_${entry.key}'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeShortcut(entry.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('shortcut_label_field'),
            controller: _shortcutLabelController,
            decoration: const InputDecoration(labelText: 'Nome do atalho'),
          ),
          TextField(
            key: const Key('shortcut_phrase_field'),
            controller: _shortcutPhraseController,
            decoration: const InputDecoration(labelText: 'Frase de comando'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('add_shortcut_button'),
            onPressed: _addShortcut,
            child: const Text('Adicionar atalho'),
          ),
        ],
      ),
    );
  }
}
