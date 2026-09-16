import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'ha_service.dart';
import 'settings_screen.dart';
import 'settings_store.dart';

enum _MicState { idle, listening, sending }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.store, this.haService, this.speech});

  final SettingsStore? store;
  final HaService? haService;
  final stt.SpeechToText? speech;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SettingsStore _store = widget.store ?? SettingsStore();
  late final HaService _haService = widget.haService ?? HaService();
  late final stt.SpeechToText _speech = widget.speech ?? stt.SpeechToText();

  List<Shortcut> _shortcuts = [];
  _MicState _micState = _MicState.idle;
  String _recognizedText = '';
  String _statusMessage = '';
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    final shortcuts = await _store.getShortcuts();
    if (!mounted) return;
    setState(() => _shortcuts = shortcuts);
  }

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechInitialized) return true;
    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _micState = _MicState.idle;
          _statusMessage = 'Erro no reconhecimento de voz';
        });
      },
      onStatus: (status) {
        if (status == 'done' && mounted && _micState == _MicState.listening) {
          setState(() => _micState = _MicState.idle);
        }
      },
    );
    _speechInitialized = available;
    return available;
  }

  Future<void> _toggleListening() async {
    if (_micState == _MicState.listening) {
      await _speech.stop();
      setState(() => _micState = _MicState.idle);
      return;
    }
    if (_micState == _MicState.sending) return;

    final available = await _ensureSpeechInitialized();
    if (!mounted) return;
    if (!available) {
      setState(() => _statusMessage = 'Microfone indisponível');
      return;
    }

    setState(() {
      _micState = _MicState.listening;
      _recognizedText = '';
      _statusMessage = 'Ouvindo...';
    });

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'pt_BR'),
      onResult: (result) {
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _sendCommand(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _sendCommand(String text) async {
    setState(() {
      _micState = _MicState.sending;
      _statusMessage = 'Enviando...';
    });

    final baseUrl = await _store.getBaseUrl();
    final token = await _store.getToken();
    if (baseUrl == null || token == null) {
      if (!mounted) return;
      setState(() {
        _micState = _MicState.idle;
        _statusMessage = 'Configure a URL e o token do Home Assistant';
      });
      return;
    }

    try {
      final speech = await _haService.sendCommand(baseUrl, token, text);
      if (!mounted) return;
      setState(() {
        _micState = _MicState.idle;
        _statusMessage = speech;
      });
    } on HaServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _micState = _MicState.idle;
        _statusMessage = e.message;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsScreen(store: _store)));
    _loadShortcuts();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = _micState == _MicState.listening;
    final sending = _micState == _MicState.sending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarbas'),
        actions: [
          IconButton(
            key: const Key('settings_button'),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              GestureDetector(
                key: const Key('mic_button'),
                onTap: sending ? null : _toggleListening,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: listening
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  child: Icon(
                    listening ? Icons.mic : Icons.mic_none,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_recognizedText.isNotEmpty)
                Text(_recognizedText, key: const Key('recognized_text')),
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _statusMessage,
                    key: const Key('status_message'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const Divider(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: _shortcuts
                      .map(
                        (s) => OutlinedButton(
                          key: Key('shortcut_${s.label}'),
                          onPressed: sending
                              ? null
                              : () => _sendCommand(s.phrase),
                          child: Text(s.label, textAlign: TextAlign.center),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
