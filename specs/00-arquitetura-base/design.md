# Design — Arquitetura Base

## Visão geral da solução

```
┌───────────────────────────┐        ┌───────────────────────────┐
│   Modo sob demanda         │        │   Modo Jarbas               │
│   (toque no microfone)     │        │   (wake word contínua)      │
└──────────────┬─────────────┘        └──────────────┬─────────────┘
               │                                       │
               │ texto reconhecido                     │ wake word detectada
               │                                       │  → aciona captura
               ▼                                       ▼
        ┌──────────────────────────────────────────────────┐
        │           speech_to_text (compartilhado)           │
        └──────────────────────┬───────────────────────────┘
                                │ texto final
                                ▼
                        ┌───────────────┐
                        │   HaService    │
                        └───────┬───────┘
                                │ HTTP + Bearer token
                                ▼
                ┌───────────────────────────────┐
                │ Home Assistant (via Tailscale) │
                │ /api/conversation/process       │
                └───────────────────────────────┘
```

Os dois modos convergem no mesmo `speech_to_text` e no mesmo `HaService` —
a única diferença é o que dispara a captura de voz (toque manual vs. wake
word). Ver spec `01` (persistência), `02` (HaService), `03` (UI) e `04`
(Jarbas) para o detalhamento de cada camada.

## Estrutura de diretórios (alvo)

```
ha_voice_app/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── res/xml/
│           └── network_security_config.xml
├── lib/
│   ├── main.dart
│   ├── home_screen.dart          # spec 03
│   ├── settings_screen.dart      # spec 03
│   ├── settings_store.dart       # spec 01
│   ├── ha_service.dart           # spec 02
│   └── jarbas_service.dart       # spec 04
├── pubspec.yaml
├── specs/                        # esta pasta
└── README.md
```

## Módulos desta spec

- `pubspec.yaml` — dependências do projeto.
- `android/app/src/main/AndroidManifest.xml` — permissões e referência ao
  `network_security_config`.
- `android/app/src/main/res/xml/network_security_config.xml` — cleartext
  liberado só para `ts.net`.

## Dependências (pubspec.yaml)

| Pacote | Função |
|---|---|
| `speech_to_text` | Reconhecimento de voz nativo (pt-BR) |
| `http` | Chamadas REST ao Home Assistant |
| `shared_preferences` | Persistência local (URL, token, atalhos) |
| `permission_handler` | Permissões em runtime (microfone, notificações) |
| `porcupine_flutter` | Detecção offline de wake word |
| `flutter_foreground_task` | Execução em foreground service (Modo Jarbas) |

## Configuração Android

### Permissões (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

As permissões de foreground service/notificação só são efetivamente
*usadas* a partir da spec `04`, mas ficam declaradas aqui junto do restante
do manifest base para não reabrir o arquivo depois.

### Referência ao `networkSecurityConfig`
```xml
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

### `network_security_config.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

## Decisões Técnicas

- Cleartext HTTP é liberado globalmente (`base-config`), não só para
  `ts.net`. O app precisa falar tanto com o HA na rede local (IP
  `192.168.x.x`, que muda por DHCP) quanto via Tailscale (RNF-03, já
  criptografado por WireGuard). Como o Network Security Config do Android só
  casa `domain-config` por hostname/IP exato (não aceita CIDR nem IP
  dinâmico), restringir por domínio exigiria IP fixo reservado no roteador —
  optamos por liberar cleartext geral, aceitável porque o app só se conecta
  à rede doméstica do próprio usuário e ao seu tailnet.
- Nenhuma dependência de serviço de nuvem de terceiros além do próprio HA e
  do motor de wake word local (RNF-05).

## Riscos / pontos em aberto

- Confirmar se o Android antigo do Modo Jarbas roda uma versão de Android
  suportada pelas dependências nativas (`porcupine_flutter`,
  `flutter_foreground_task`) — validar na spec `04`.
