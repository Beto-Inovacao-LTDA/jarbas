import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_voice_app/ha_service.dart';
import 'package:ha_voice_app/home_screen.dart';
import 'package:ha_voice_app/settings_store.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class _FakeSettingsStore extends SettingsStore {
  String? url = 'http://ha.local:8123';
  String? token = 'tok';
  List<Shortcut> shortcuts = const [
    Shortcut(label: 'Acender luzes', phrase: 'acender as luzes'),
  ];

  @override
  Future<String?> getBaseUrl() async => url;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<List<Shortcut>> getShortcuts() async => shortcuts;

  @override
  Future<void> setShortcuts(List<Shortcut> value) async => shortcuts = value;
}

class _FakeHaService extends HaService {
  String? lastText;

  @override
  Future<String> sendCommand(
    String baseUrl,
    String token,
    String text,
  ) async {
    lastText = text;
    return 'Feito: $text';
  }
}

// Fake sem tocar em platform channel: apenas simula os callbacks de
// resultado/estado que a HomeScreen escuta.
class _FakeSpeechToText extends stt.SpeechToText {
  _FakeSpeechToText() : super.withMethodChannel();

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<stt.SpeechConfigOption>? options,
  }) async => true;

  @override
  Future listen({
    stt.SpeechResultListener? onResult,
    stt.SpeechListenOptions? listenOptions,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    dynamic listenFor,
    dynamic pauseFor,
    dynamic localeId,
    dynamic cancelOnError,
    dynamic partialResults,
    dynamic onDevice,
    dynamic listenMode,
    dynamic sampleRate,
  }) async {
    onResult?.call(
      SpeechRecognitionResult.init(
        const [SpeechRecognitionWords('ligar luz da sala', null, 1.0)],
        ResultType.finalResult,
      ),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('mic começa parado e mostra os atalhos', (tester) async {
    final store = _FakeSettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          haService: _FakeHaService(),
          speech: _FakeSpeechToText(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.text('Acender luzes'), findsOneWidget);
  });

  testWidgets(
    'tocar o microfone captura fala e envia via HaService',
    (tester) async {
      final store = _FakeSettingsStore();
      final haService = _FakeHaService();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            haService: haService,
            speech: _FakeSpeechToText(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mic_button')));
      await tester.pumpAndSettle();

      expect(haService.lastText, 'ligar luz da sala');
      expect(find.text('Feito: ligar luz da sala'), findsOneWidget);
    },
  );

  testWidgets('atalho dispara HaService.sendCommand sem usar o microfone', (
    tester,
  ) async {
    final store = _FakeSettingsStore();
    final haService = _FakeHaService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          haService: haService,
          speech: _FakeSpeechToText(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Acender luzes'));
    await tester.pumpAndSettle();

    expect(haService.lastText, 'acender as luzes');
    expect(find.text('Feito: acender as luzes'), findsOneWidget);
  });
}
