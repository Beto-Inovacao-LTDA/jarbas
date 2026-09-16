# Design — Dados e Persistência

## Visão geral da solução

Cria-se `lib/settings_store.dart` com o modelo `Shortcut` e a classe
`SettingsStore`, encapsulando todo acesso ao `SharedPreferences`. Nenhuma
outra camada do app acessa `SharedPreferences` diretamente.

## Módulos

### `lib/settings_store.dart`

#### `class Shortcut`
```dart
class Shortcut {
  final String label;   // texto do botão, ex: "Luz da sala"
  final String phrase;  // frase enviada ao Assist
}
```

#### `class SettingsStore`
- `Future<String?> getBaseUrl()` / `Future<void> setBaseUrl(String)`
- `Future<String?> getToken()` / `Future<void> setToken(String)`
- `Future<List<Shortcut>> getShortcuts()` / `Future<void> setShortcuts(List<Shortcut>)`
- `Future<bool> getJarbasAutostart()` / `Future<void> setJarbasAutostart(bool)`
- `List<Shortcut> defaultShortcuts()` — retorna os 3 atalhos padrão de RF-05
  ("Acender luzes", "Apagar luzes", "Trancar tudo"); usado quando
  `getShortcuts()` não encontra nada salvo.

## Chaves de persistência (`SharedPreferences`)

| Chave | Conteúdo |
|---|---|
| `ha_base_url` | URL do Home Assistant |
| `ha_token` | Long-Lived Access Token |
| `ha_shortcuts` | JSON serializado da lista de `Shortcut` |
| `jarbas_autostart` | Bool — iniciar Modo Jarbas automaticamente ao abrir o app (opcional, útil no aparelho dedicado) |

## Fluxo

1. App inicia → `SettingsStore.getShortcuts()`.
2. Se vazio/nulo, grava e retorna `defaultShortcuts()`.
3. Tela de configurações (spec `03`) lê/grava via os mesmos métodos.

## Decisões Técnicas

- Token guardado em texto puro no `SharedPreferences` — decisão negociada
  no `requirements.md` original (sem criptografia adicional no MVP).
- `Shortcut` é um modelo imutável simples; qualquer edição gera uma nova
  lista e chama `setShortcuts()` inteira (sem CRUD granular no storage).

## Riscos / pontos em aberto

- Nenhum identificado além do já registrado em "fora de escopo" (token sem
  criptografia adicional).
