import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_voice_app/ha_service.dart';
import 'package:ha_voice_app/settings_screen.dart';
import 'package:ha_voice_app/settings_store.dart';

class _FakeSettingsStore extends SettingsStore {
  String? url;
  String? token;
  String? porcupineAccessKey;
  List<Shortcut> shortcuts = [];

  @override
  Future<String?> getBaseUrl() async => url;

  @override
  Future<void> setBaseUrl(String value) async => url = value;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> setToken(String value) async => token = value;

  @override
  Future<String?> getPorcupineAccessKey() async => porcupineAccessKey;

  @override
  Future<void> setPorcupineAccessKey(String value) async =>
      porcupineAccessKey = value;

  @override
  Future<List<Shortcut>> getShortcuts() async => shortcuts;

  @override
  Future<void> setShortcuts(List<Shortcut> value) async => shortcuts = value;
}

class _FakeHaService extends HaService {
  _FakeHaService({this.testConnectionResult = true});

  final bool testConnectionResult;
  String? lastTestedUrl;
  String? lastTestedToken;

  @override
  Future<bool> testConnection(String baseUrl, String token) async {
    lastTestedUrl = baseUrl;
    lastTestedToken = token;
    return testConnectionResult;
  }
}

void main() {
  testWidgets('carrega URL, token e atalhos existentes', (tester) async {
    final store = _FakeSettingsStore()
      ..url = 'http://ha.local:8123'
      ..token = 'abc123'
      ..shortcuts = const [
        Shortcut(label: 'Acender luzes', phrase: 'acender as luzes'),
      ];

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://ha.local:8123'), findsOneWidget);
    expect(find.text('Acender luzes'), findsOneWidget);
  });

  testWidgets('Salvar persiste URL e token no store', (tester) async {
    final store = _FakeSettingsStore();

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('url_field')),
      'http://192.168.15.13:8123',
    );
    await tester.enterText(find.byKey(const Key('token_field')), 'meutoken');
    await tester.enterText(
      find.byKey(const Key('porcupine_access_key_field')),
      'minha-access-key',
    );
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    expect(store.url, 'http://192.168.15.13:8123');
    expect(store.token, 'meutoken');
    expect(store.porcupineAccessKey, 'minha-access-key');
  });

  testWidgets('Testar conexão mostra sucesso via HaService', (tester) async {
    final store = _FakeSettingsStore();
    final haService = _FakeHaService(testConnectionResult: true);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(store: store, haService: haService)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('url_field')),
      'http://ha.local:8123',
    );
    await tester.enterText(find.byKey(const Key('token_field')), 'tok');
    await tester.tap(find.byKey(const Key('test_connection_button')));
    await tester.pumpAndSettle();

    expect(haService.lastTestedUrl, 'http://ha.local:8123');
    expect(haService.lastTestedToken, 'tok');
    expect(find.text('Conexão bem-sucedida'), findsOneWidget);
  });

  testWidgets('Testar conexão mostra falha via HaService', (tester) async {
    final store = _FakeSettingsStore();
    final haService = _FakeHaService(testConnectionResult: false);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(store: store, haService: haService)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('test_connection_button')));
    await tester.pumpAndSettle();

    expect(find.text('Falha na conexão'), findsOneWidget);
  });

  testWidgets('adiciona e remove atalho', (tester) async {
    final store = _FakeSettingsStore();

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('shortcut_label_field')),
      'Trancar tudo',
    );
    await tester.enterText(
      find.byKey(const Key('shortcut_phrase_field')),
      'trancar tudo',
    );
    final settingsScrollable = find
        .descendant(
          of: find.byKey(const Key('settings_list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('add_shortcut_button')),
      100,
      scrollable: settingsScrollable,
    );
    await tester.tap(find.byKey(const Key('add_shortcut_button')));
    await tester.pumpAndSettle();

    expect(find.text('Trancar tudo'), findsOneWidget);
    expect(store.shortcuts, hasLength(1));

    await tester.scrollUntilVisible(
      find.byKey(const Key('remove_shortcut_0')),
      100,
      scrollable: settingsScrollable,
    );
    await tester.tap(find.byKey(const Key('remove_shortcut_0')));
    await tester.pumpAndSettle();

    expect(find.text('Trancar tudo'), findsNothing);
    expect(store.shortcuts, isEmpty);
  });
}
