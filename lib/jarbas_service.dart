import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'ha_service.dart';
import 'settings_store.dart';

const String _keywordAssetPath = 'assets/porcupine/ok_jarbas_android.ppn';
const String _modelAssetPath = 'assets/porcupine/porcupine_params_pt.pv';
const int _serviceId = 1000;
const String _notificationChannelId = 'jarbas_wake_word';
const Duration _silenceTimeout = Duration(seconds: 5);

enum JarbasStatus { listening, capturing, sending, error }

/// API pública consumida pela UI (`home_screen.dart`) para ativar/desativar
/// o Modo Jarbas. O trabalho de verdade (Porcupine + speech_to_text +
/// HaService) roda dentro de [JarbasTaskHandler], numa isolate separada
/// mantida viva pelo foreground service.
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
  PorcupineManager? _porcupineManager;
  bool _speechInitialized = false;
  Completer<String>? _pendingCapture;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final store = SettingsStore();
    final accessKey = await store.getPorcupineAccessKey();
    if (accessKey == null || accessKey.isEmpty) {
      await _fail('Configure o AccessKey da Picovoice nas configurações.');
      return;
    }

    try {
      final manager = await PorcupineManager.fromKeywordPaths(
        accessKey,
        [_keywordAssetPath],
        _onWakeWordDetected,
        modelPath: _modelAssetPath,
        errorCallback: (error) =>
            _sendStatus(JarbasStatus.error, message: error.message),
      );
      await manager.start();
      _porcupineManager = manager;
    } on PorcupineException catch (error) {
      await _fail(
        'Não foi possível iniciar a detecção de "OK Jarbas": ${error.message}',
      );
      return;
    } catch (error) {
      await _fail('Erro inesperado ao iniciar o Modo Jarbas: $error');
      return;
    }

    _store = store;
    _haService = HaService();
    _speech = stt.SpeechToText();
    _sendStatus(JarbasStatus.listening);
  }

  Future<void> _onWakeWordDetected(int keywordIndex) async {
    await _porcupineManager?.stop();
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
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
      await _porcupineManager?.start();
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
    await _porcupineManager?.delete();
    await _speech?.cancel();
  }
}
