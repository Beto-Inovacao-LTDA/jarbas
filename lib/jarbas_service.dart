import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

import 'ha_service.dart';
import 'settings_store.dart';

const String _modelAssetPath = 'assets/vosk/vosk-model-small-pt-0.3.zip';
const String _wakeBeepAssetPath = 'sounds/wake_beep.wav';
const int _sampleRate = 16000;
const List<String> _wakeWordGrammar = ['ok jarbas', '[unk]'];
const String _wakeWordPhrase = 'ok jarbas';
const int _serviceId = 1000;
const String _notificationChannelId = 'jarbas_wake_word';
const Duration _silenceTimeout = Duration(seconds: 5);

enum JarbasStatus { listening, capturing, sending, error }

/// API pública consumida pela UI (`home_screen.dart`) para ativar/desativar
/// o Modo Jarbas. O trabalho de verdade (Vosk + speech_to_text + HaService)
/// roda dentro de [JarbasTaskHandler], numa isolate separada mantida viva
/// pelo foreground service.
class JarbasService {
  JarbasService._();

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _notificationChannelId,
        channelName: 'Modo Jarbas',
        channelDescription: 'Detecção contínua da wake word "OK Jarbas".',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }

  static Future<ServiceRequestResult> start() async {
    _ensureInitialized();
    if (await FlutterForegroundTask.isRunningService) {
      return const ServiceRequestSuccess();
    }
    return FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Jarbas',
      notificationText: 'Ouvindo "OK Jarbas"...',
      callback: startJarbasTaskCallback,
    );
  }

  static Future<ServiceRequestResult> stop() {
    return FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void startJarbasTaskCallback() {
  FlutterForegroundTask.setTaskHandler(JarbasTaskHandler());
}

class JarbasTaskHandler extends TaskHandler {
  SettingsStore? _store;
  HaService? _haService;
  stt.SpeechToText? _speech;
  Model? _voskModel;
  Recognizer? _voskRecognizer;
  SpeechService? _voskSpeechService;
  StreamSubscription<String>? _voskResultSubscription;
  AudioPlayer? _beepPlayer;
  bool _speechInitialized = false;
  bool _processingWakeWord = false;
  Completer<String>? _pendingCapture;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Criado aqui (não como inicializador de campo) porque o construtor de
    // AudioPlayer acessa bindings do Flutter que ainda não existem no
    // instante em que JarbasTaskHandler é construído — só ficam prontos
    // depois que a isolate de segundo plano termina de inicializar,
    // durante onStart(). Criar antes disso lança "Binding has not yet been
    // initialized" (silenciado pelo try/catch de _playBeep, então o beep
    // simplesmente nunca tocava).
    _beepPlayer = AudioPlayer();
    try {
      final modelPath = await ModelLoader().loadFromAssets(_modelAssetPath);
      final model = await VoskFlutterPlugin.instance().createModel(modelPath);
      final recognizer = await VoskFlutterPlugin.instance().createRecognizer(
        model: model,
        sampleRate: _sampleRate,
        grammar: _wakeWordGrammar,
      );
      _voskModel = model;
      _voskRecognizer = recognizer;
      await _startWakeWordListening();
    } on MicrophoneAccessDeniedException {
      await _fail('Permissão de microfone negada para o Modo Jarbas.');
      return;
    } catch (error) {
      await _fail(
        'Não foi possível iniciar a detecção de "OK Jarbas": $error',
      );
      return;
    }

    _store = SettingsStore();
    _haService = HaService();
    _speech = stt.SpeechToText();
    _sendStatus(JarbasStatus.listening);
  }

  /// Cria um [SpeechService] novo em cima do [_voskRecognizer] já carregado
  /// (reaproveita o modelo, não recarrega os assets) e começa a escutar a
  /// wake word. Precisa ser chamado de novo a cada vez que o serviço
  /// anterior é totalmente descartado (ver [_onWakeWordDetected] e
  /// [_stopWakeWordListening]) — reiniciar o mesmo [AudioRecord] nativo
  /// depois que outro app (o `speech_to_text` do Google) usou o microfone
  /// pode falhar com "error reading audio buffer" e derrubar o processo.
  Future<void> _startWakeWordListening() async {
    final speechService = await VoskFlutterPlugin.instance().initSpeechService(
      _voskRecognizer!,
    );
    _voskSpeechService = speechService;
    _voskResultSubscription = speechService.onResult().listen(_onVoskResult);
    await speechService.start(onRecognitionError: _onVoskRecognitionError);
  }

  /// Para e libera o [SpeechService] atual (thread nativa + `AudioRecord`).
  /// Sempre chamar `stop()` antes de `dispose()`: `dispose()` libera o
  /// `AudioRecord` diretamente, e se a thread nativa do Vosk ainda estiver
  /// lendo dele nesse momento, ela derruba o app inteiro com
  /// `RuntimeException: error reading audio buffer` (não capturável do lado
  /// Dart). `stop()` primeiro garante que a thread já saiu do loop de
  /// leitura antes de liberar o recurso.
  Future<void> _stopWakeWordListening() async {
    await _voskResultSubscription?.cancel();
    _voskResultSubscription = null;
    await _voskSpeechService?.stop();
    await _voskSpeechService?.dispose();
    _voskSpeechService = null;
  }

  void _onVoskRecognitionError(dynamic error) {
    _sendStatus(JarbasStatus.error, message: error.toString());
  }

  void _onVoskResult(String resultJson) {
    if (_processingWakeWord) return;

    final text = _extractRecognizedText(resultJson);
    if (text != _wakeWordPhrase) return;

    _processingWakeWord = true;
    unawaited(
      _onWakeWordDetected().whenComplete(() => _processingWakeWord = false),
    );
  }

  String _extractRecognizedText(String resultJson) {
    try {
      final decoded = jsonDecode(resultJson) as Map<String, dynamic>;
      return (decoded['text'] as String? ?? '').trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> _onWakeWordDetected() async {
    await _stopWakeWordListening();
    unawaited(_emitWakeWordFeedback());
    _sendStatus(JarbasStatus.capturing);

    try {
      final text = await _captureCommand();
      if (text.trim().isEmpty) {
        _sendStatus(JarbasStatus.listening);
        return;
      }

      _sendStatus(JarbasStatus.sending);
      final baseUrl = await _store!.getBaseUrl();
      final token = await _store!.getToken();
      if (baseUrl == null || token == null) {
        _sendStatus(
          JarbasStatus.listening,
          message: 'Configure a URL e o token do Home Assistant.',
        );
        return;
      }

      try {
        final speech = await _haService!.sendCommand(baseUrl, token, text);
        _sendStatus(JarbasStatus.listening, message: speech);
      } on HaServiceException catch (error) {
        _sendStatus(JarbasStatus.listening, message: error.message);
      }
    } finally {
      await _startWakeWordListening();
    }
  }

  Future<void> _emitWakeWordFeedback() async {
    await Future.wait([_vibrate(), _playBeep()]);
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 200);
      }
    } catch (_) {
      // Feedback é best-effort; a falta dele não deve interromper o fluxo.
    }
  }

  Future<void> _playBeep() async {
    try {
      await _beepPlayer?.play(AssetSource(_wakeBeepAssetPath));
    } catch (_) {
      // Feedback é best-effort; a falta dele não deve interromper o fluxo.
    }
  }

  Future<String> _captureCommand() async {
    if (!_speechInitialized) {
      _speechInitialized = await _speech!.initialize(
        onStatus: (status) {
          if (status == 'done' && (_pendingCapture?.isCompleted == false)) {
            _pendingCapture!.complete('');
          }
        },
      );
    }
    if (!_speechInitialized) {
      _sendStatus(
        JarbasStatus.listening,
        message: 'Reconhecimento de voz indisponível.',
      );
      return '';
    }

    final completer = Completer<String>();
    _pendingCapture = completer;
    await _speech!.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'pt_BR',
        listenFor: _silenceTimeout,
      ),
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
    );

    final text = await completer.future.timeout(
      _silenceTimeout + const Duration(seconds: 2),
      onTimeout: () => '',
    );
    _pendingCapture = null;
    await _speech!.stop();
    return text;
  }

  Future<void> _fail(String message) async {
    _sendStatus(JarbasStatus.error, message: message);
    await FlutterForegroundTask.stopService();
  }

  void _sendStatus(JarbasStatus status, {String? message}) {
    FlutterForegroundTask.sendDataToMain({
      'status': status.name,
      'message': ?message,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _stopWakeWordListening();
    await _voskRecognizer?.dispose();
    _voskModel?.dispose();
    await _speech?.cancel();
    await _beepPlayer?.dispose();
  }
}
