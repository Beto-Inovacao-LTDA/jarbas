# Jarbas

App Flutter (Android) que funciona como uma Alexa caseira para o
[Home Assistant](https://www.home-assistant.io/): fala um comando, o app
transcreve e manda pro Assist do HA processar. Zero interpretação própria de
comando — o app é só o "microfone e alto-falante", toda a inteligência de
NLU/automação fica no HA.

Dois jeitos de usar:

- **Modo sob demanda** — toca no botão de microfone, fala, o app envia
  automaticamente ao terminar a fala. Também tem uma grade de atalhos
  (botões que disparam uma frase fixa sem precisar falar).
- **Modo Jarbas** — um aparelho dedicado (celular antigo, sempre na
  tomada) fica ouvindo continuamente, offline, a palavra de ativação
  **"OK Jarbas"**. Ao detectar, captura a frase seguinte e envia do mesmo
  jeito que o modo sob demanda.

Projeto pessoal do estúdio Beto Engenharia e Inovação, sem publicação em
loja — distribuído via `adb install` direto no(s) aparelho(s).

## Como funciona, por baixo do capô

### Visão geral

```
┌─────────────────────────┐        ┌──────────────────────────────┐
│   Modo sob demanda        │        │   Modo Jarbas                  │
│   home_screen.dart        │        │   jarbas_service.dart          │
│   (toque no microfone)    │        │   (foreground service,         │
│                           │        │    escuta contínua offline)    │
└─────────────┬─────────────┘        └───────────────┬────────────────┘
              │ texto reconhecido                     │ "OK Jarbas" detectada
              │ (speech_to_text)                       │ → dispara captura
              ▼                                       ▼
       ┌─────────────────────────────────────────────────────┐
       │              speech_to_text (compartilhado)           │
       │     STT nativo do Android, pt-BR, timeout de 5s        │
       │           de silêncio no Modo Jarbas                   │
       └───────────────────────┬─────────────────────────────┘
                                │ texto final (ou vazio → descarta)
                                ▼
                        ┌───────────────┐
                        │   HaService    │  lib/ha_service.dart
                        └───────┬───────┘
                                │ POST /api/conversation/process
                                │ Authorization: Bearer <token>
                                ▼
                ┌───────────────────────────────┐
                │        Home Assistant           │
                │   Assist processa e responde    │
                │   (NLU, entidades, automações)  │
                └───────────────────────────────┘
```

Os dois modos convergem no mesmo `speech_to_text` e no mesmo `HaService` —
a única diferença é **o que dispara a captura de voz** (toque manual vs.
wake word) e **onde o código roda** (isolate principal da UI vs. isolate
separada do foreground service, no caso do Modo Jarbas).

### Módulo por módulo

| Arquivo | Responsabilidade |
|---|---|
| `lib/main.dart` | Bootstrap do `MaterialApp`, inicializa a porta de comunicação do `flutter_foreground_task` |
| `lib/settings_store.dart` | Camada de persistência (`SharedPreferences`): URL do HA, token, AccessKey da Picovoice, atalhos, preferência de autostart do Modo Jarbas |
| `lib/ha_service.dart` | Único ponto de contato HTTP com o HA. `sendCommand()` e `testConnection()`, com exceções tipadas (`HaUnauthorizedException`, `HaTimeoutException`, `HaConnectionException`, `HaUnexpectedResponseException`) |
| `lib/home_screen.dart` | Tela principal: botão de microfone, grade de atalhos, indicador/switch do Modo Jarbas, navegação pra configurações |
| `lib/settings_screen.dart` | Tela de configurações: URL/token do HA, "Testar conexão", AccessKey da Picovoice, CRUD de atalhos |
| `lib/jarbas_service.dart` | `JarbasTaskHandler`: ciclo de vida do Porcupine (wake word), orquestra captura pós-detecção e envio ao HA, dentro do foreground service |

### Fluxo — modo sob demanda

1. Usuário toca o botão de microfone (`home_screen.dart`). Na primeira vez,
   isso dispara `speech_to_text.initialize()` — a inicialização é
   **preguiçosa** (só no primeiro toque), pra não pedir permissão de
   microfone antes da hora.
2. `speech_to_text` escuta, transcreve em pt-BR. Ao detectar fim de fala
   (resultado final), o texto vai direto pro `HaService.sendCommand()` —
   sem botão de "enviar" separado.
3. `HaService` monta o `POST {baseUrl}/api/conversation/process` com o
   corpo `{"text": "...", "language": "pt-BR"}` e o header
   `Authorization: Bearer <token>`, aplica timeout de 10s.
4. Sucesso → extrai `response.speech.plain.speech` da resposta do HA e
   mostra na tela. Erro → uma das quatro exceções tipadas vira mensagem de
   status específica, sem derrubar o app.
5. Atalhos (grade de botões) pulam os passos 1-2: tocam direto em
   `HaService.sendCommand()` com uma frase fixa configurada pelo usuário.

### Fluxo — Modo Jarbas

Esta é a parte mais particular da arquitetura: pra sobreviver com a tela
apagada/app em segundo plano, o Modo Jarbas roda **numa isolate Dart
separada da isolate principal da UI**, gerenciada pelo plugin
`flutter_foreground_task`. É basicamente um segundo mini-programa Dart,
vivo enquanto o serviço em primeiro plano do Android estiver de pé,
comunicando com a UI só por mensagens (nunca compartilhando objetos/estado
diretamente).

1. Usuário liga o switch "Modo Jarbas" na tela principal.
   `JarbasService.start()` pede permissão de notificação (obrigatória no
   Android 13+ pra manter a notificação persistente visível) e chama
   `FlutterForegroundTask.startService(...)`.
2. O Android sobe um `Service` em primeiro plano com notificação
   persistente, e dispara `startJarbasTaskCallback()` — uma função
   top-level marcada `@pragma('vm:entry-point')` (exigência do plugin: só
   funções top-level podem ser o ponto de entrada da isolate nova).
3. Dentro dessa isolate, `JarbasTaskHandler.onStart()` roda: cria seu
   **próprio** `SettingsStore`, `HaService` e `SpeechToText` (não dá pra
   reusar instâncias da isolate principal), lê o AccessKey da Picovoice e
   tenta inicializar o `PorcupineManager` com o arquivo `.ppn` da wake word
   "OK Jarbas".
   - **Se falhar** (AccessKey ausente, arquivo de wake word faltando, erro
     do motor): manda uma mensagem de erro pra UI e **desliga o próprio
     serviço** (`FlutterForegroundTask.stopService()`). Isso é proposital —
     o Modo Jarbas nunca fica "ativo" com uma notificação persistente sem
     detecção de verdade rodando por trás.
4. Com sucesso, `PorcupineManager` processa áudio localmente (sem rede) em
   loop, procurando a wake word.
5. Ao detectar: pausa o Porcupine, dispara feedback tátil/sonoro
   (`HapticFeedback` + `SystemSound`, sem dependência nova), e aciona
   `speech_to_text.listen()` com `listenFor: 5s` — um timeout de silêncio
   pra nunca ficar esperando indefinidamente. Se ninguém falar nada nesses
   5s (ou o resultado vier vazio), volta a escutar a wake word sem mandar
   comando nenhum pro HA.
6. Com texto capturado, mesma chamada `HaService.sendCommand()` do modo sob
   demanda. Erro ou sucesso, sempre retoma a escuta da wake word em
   seguida (`try/finally`).
7. `FlutterForegroundTask.sendDataToMain(...)` manda o estado atual
   (`listening` / `capturing` / `sending` / `error`, com mensagem opcional)
   pra isolate principal, que atualiza o indicador na `home_screen.dart`
   via `addTaskDataCallback`.

### Por que os dois modos não se atrapalham

`HaService`, `SettingsStore` e a lógica de `speech_to_text` são as mesmas
classes reaproveitadas nos dois modos — mas cada isolate cria suas
**próprias instâncias**. Não há estado global compartilhado entre a UI e o
Modo Jarbas; toda comunicação é por mensagens serializáveis (`Map` com
tipos primitivos) através do `FlutterForegroundTask.sendDataToMain`/
`sendDataToTask`.

### Tratamento de erros: a lição que já mordeu esse projeto

Durante o teste manual da spec 03, um `catch` específico demais em
`HaService` (só cobria `TimeoutException`/`SocketException`/
`ClientException`) deixou passar um `ArgumentError` de URL inválida —
resultado: a UI travava com o spinner girando pra sempre, sem crash e sem
mensagem nenhuma. A correção virou princípio do projeto: **qualquer chamada
de rede numa camada que atualiza estado de UI precisa de um `catch`
genérico como rede de segurança**, nunca só os tipos "esperados". O mesmo
princípio guiou o design do `JarbasTaskHandler` (qualquer falha ao iniciar
o Porcupine é tratada, nunca deixa o serviço "pendurado").

## Stack técnica

- **Flutter** (Dart ^3.13.3), Android only por enquanto (iOS não foi alvo
  do projeto)
- [`speech_to_text`](https://pub.dev/packages/speech_to_text) — STT nativo
  do Android, compartilhado pelos dois modos
- [`http`](https://pub.dev/packages/http) — única lib de rede, sem cliente
  adicional
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) —
  persistência local (URL, token, atalhos, AccessKey)
- [`porcupine_flutter`](https://pub.dev/packages/porcupine_flutter)
  ([Picovoice](https://picovoice.ai/)) — motor de wake word 100% offline
- [`flutter_foreground_task`](https://pub.dev/packages/flutter_foreground_task)
  — foreground service Android com isolate dedicada, sobrevive em segundo
  plano
- [`permission_handler`](https://pub.dev/packages/permission_handler)

### Detalhe de build que vale saber

`porcupine_flutter`/`flutter_voice_processor` são publicados com
`compileSdkVersion` incompatível com o `flutter_foreground_task`. O
`android/build.gradle.kts` reescreve isso direto no pub cache antes do
Gradle avaliar os módulos — roda de novo automaticamente a cada build, não
precisa mexer manualmente depois de `flutter pub get`/`pub cache repair`.

## Estrutura do projeto

```
ha_voice_app/
├── lib/                    # código do app (ver tabela de módulos acima)
├── assets/
│   ├── icon/                # ícone do app (gerado com PIL)
│   └── porcupine/            # .ppn/.pv da wake word "OK Jarbas" (ver README lá)
├── android/                 # config nativa (manifest, foreground service, network security)
├── test/                    # testes automatizados (flutter test)
├── docs/
│   ├── arquitetura.md        # arquitetura técnica em profundidade
│   └── guia_usuario.md       # guia de uso do app (não-técnico)
├── secrets/                  # tokens/chaves de teste locais — nunca commitado (.gitignore)
└── specs/                    # Spec-Driven Development: requirements/design/tasks/teste por etapa
```

## Como rodar

### Pré-requisitos

- Flutter SDK instalado (`flutter doctor` sem erros bloqueantes)
- Um Home Assistant acessível pela rede (local ou Tailscale) com um
  **Long-Lived Access Token** gerado no seu usuário
- Pra usar o Modo Jarbas: conta e AccessKey em
  [console.picovoice.ai](https://console.picovoice.ai/), e a wake word "OK
  Jarbas" treinada (ver `assets/porcupine/README.md`)

### Setup

```bash
flutter pub get
flutter test        # roda a suíte automatizada
flutter analyze      # lint/análise estática
```

### Rodar num aparelho

```bash
adb devices                    # confirma o aparelho conectado (USB ou adb connect via Wi-Fi)
flutter run                    # debug, hot reload
# ou, pra instalar sem manter sessão de debug anexada:
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Depois de instalado, abra o app → ⚙️ Configurações → preencha URL do HA,
token e (se for usar o Modo Jarbas) o AccessKey da Picovoice → **Testar
conexão** → **Salvar**.

### Build de distribuição

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Sem loja de aplicativos — a instalação é sempre via `adb install` direto
no(s) aparelho(s) (ver spec `05`).

## Guia do usuário

Documentação não-técnica de como usar o app no dia a dia:
[`docs/guia_usuario.md`](docs/guia_usuario.md).

## Estado do projeto

Desenvolvimento guiado por Spec-Driven Development — cada etapa numerada em
`specs/NN-nome/` tem `requirements.md`, `design.md`, `tasks.md` e
`teste_0N.md`. Ver `specs/README.md` pra ordem de execução e o gate de
aprovação.

| Spec | Status |
|---|---|
| `00` — arquitetura base | ✅ Implementada e validada |
| `01` — dados e persistência | ✅ Implementada e validada |
| `02` — integração com o Home Assistant | ✅ Implementada e validada |
| `03` — interface do modo sob demanda | ✅ Implementada e validada |
| `04` — Modo Jarbas (wake word e serviço) | 🟡 Código completo; **bloqueada** pra validação final — conta na Picovoice em revisão manual de "caso de uso comercial", sem AccessKey liberado ainda |
| `05` — testes e distribuição | ⬜ Não iniciada |

Detalhes de cada bloqueio/decisão ficam registrados no `teste_0N.md` da
spec correspondente.

## Segurança e segredos

- `secrets/` é local, gitignored — nunca contém nada versionado. Guarda
  tokens de teste usados durante o desenvolvimento (não são usados
  hardcoded no app: o usuário final configura URL/token pela própria tela
  de Configurações).
- Cleartext HTTP é permitido globalmente
  (`network_security_config.xml`) porque o app fala com o HA na rede local
  (IP dinâmico por DHCP) e/ou via Tailscale — não é exposto à internet
  aberta.
