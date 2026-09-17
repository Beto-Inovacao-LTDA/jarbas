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
  **"OK Jarbas"**. Ao detectar, vibra + emite um beep, captura a frase
  seguinte e envia do mesmo jeito que o modo sob demanda.

Projeto pessoal do estúdio Beto Engenharia e Inovação, sem publicação em
loja — distribuído via `adb install` direto no(s) aparelho(s).

## Sumário

- [Como funciona, por baixo do capô](#como-funciona-por-baixo-do-capô)
- [Stack técnica](#stack-técnica)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Instalação do ambiente de desenvolvimento](#instalação-do-ambiente-de-desenvolvimento)
- [Configurar o aparelho Android (Modo Desenvolvedor)](#configurar-o-aparelho-android-modo-desenvolvedor)
- [Como rodar](#como-rodar)
- [Build de distribuição](#build-de-distribuição)
- [Estado do projeto](#estado-do-projeto)
- [Segurança e segredos](#segurança-e-segredos)

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
| `lib/main.dart` | Bootstrap do `MaterialApp` (tema, `AppBarTheme` na cor do app), inicializa a porta de comunicação do `flutter_foreground_task` |
| `lib/settings_store.dart` | Camada de persistência (`SharedPreferences`): URL do HA, token, atalhos, preferência de autostart do Modo Jarbas |
| `lib/ha_service.dart` | Único ponto de contato HTTP com o HA. `sendCommand()` e `testConnection()`, com exceções tipadas (`HaUnauthorizedException`, `HaTimeoutException`, `HaConnectionException`, `HaUnexpectedResponseException`) |
| `lib/home_screen.dart` | Tela principal: botão de microfone, grade de atalhos (caixas arredondadas coloridas), indicador/switch do Modo Jarbas, navegação pra configurações |
| `lib/settings_screen.dart` | Tela de configurações: URL/token do HA, "Testar conexão", CRUD de atalhos |
| `lib/jarbas_service.dart` | `JarbasTaskHandler`: ciclo de vida do motor de wake word (Vosk), orquestra captura pós-detecção e envio ao HA, dentro do foreground service |

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
3. Dentro dessa isolate, `JarbasTaskHandler.onStart()` carrega o modelo
   Vosk pt-BR embutido nos assets (`ModelLoader.loadFromAssets`), cria o
   `Recognizer` com gramática restrita à frase "ok jarbas" e inicia o
   `SpeechService`.
   - **Se falhar** (permissão de microfone negada, modelo ausente/
     corrompido): manda uma mensagem de erro pra UI e **desliga o próprio
     serviço** (`FlutterForegroundTask.stopService()`). Isso é proposital —
     o Modo Jarbas nunca fica "ativo" com uma notificação persistente sem
     detecção de verdade rodando por trás.
4. Com sucesso, o `SpeechService` processa áudio localmente (sem rede) em
   loop, procurando a wake word.
5. Ao detectar: para e **libera completamente** o `SpeechService` do Vosk
   (nunca reinicia o mesmo — ver "Lições de produção" abaixo), dispara
   feedback (vibração + beep, pacotes `vibration`/`audioplayers`), e
   aciona `speech_to_text.listen()` com `listenFor: 5s` — um timeout de
   silêncio pra nunca ficar esperando indefinidamente. Se ninguém falar
   nada nesses 5s (ou o resultado vier vazio), volta a escutar a wake word
   sem mandar comando nenhum pro HA.
6. Com texto capturado, mesma chamada `HaService.sendCommand()` do modo sob
   demanda. Erro ou sucesso, sempre **recria um `SpeechService` novo** (não
   o antigo) e retoma a escuta da wake word em seguida (`try/finally`).
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

### Lições de produção (bugs reais encontrados e corrigidos)

Este projeto teve alguns bugs sutis, específicos de rodar código Flutter
numa isolate de segundo plano sem `Activity`. Valem registro porque a
mesma classe de erro pode voltar a acontecer:

- **Qualquer chamada de rede numa camada que atualiza estado de UI precisa
  de um `catch` genérico como rede de segurança**, nunca só os tipos
  "esperados". Um `catch` específico demais em `HaService` (só cobria
  `TimeoutException`/`SocketException`/`ClientException`) deixou passar um
  `ArgumentError` de URL inválida — a UI travava com o spinner girando pra
  sempre, sem crash e sem mensagem.
- **`HapticFeedback`/`SystemSound` (API padrão do Flutter) não funcionam
  numa isolate de segundo plano sem `Activity`** — falham silenciosamente,
  sem exceção. O feedback tátil do Modo Jarbas usa o pacote `vibration`
  (aciona o `Vibrator` do Android direto via `Context`) em vez disso.
- **Nunca inicializar um plugin como inicializador de campo de classe numa
  isolate de segundo plano** — só depois que o ciclo de vida da task
  começa (dentro de `onStart()`). `AudioPlayer()` criado como campo (`final
  AudioPlayer _player = AudioPlayer();`) lançava "Binding has not yet been
  initialized" silenciosamente (engolido por um `try/catch` de
  best-effort); o beep do Modo Jarbas simplesmente nunca tocava, sem erro
  visível. Corrigido criando o `AudioPlayer` na primeira linha de
  `onStart()`.
- **Nunca reiniciar o mesmo `AudioRecord` nativo do Vosk depois que outro
  app (o `speech_to_text`/Google) usou o microfone.** A biblioteca nativa
  do Vosk (`org.vosk.android.SpeechService`) lança
  `RuntimeException("error reading audio buffer")` numa thread Java crua
  se isso acontecer — não capturável do lado Dart, derruba o processo
  inteiro (sintoma: "Modo Jarbas parou de responder" ou "o app fecha ao
  desativar"). Corrigido descartando e recriando o `SpeechService` a cada
  ciclo (reaproveitando o modelo/`Recognizer` já carregados, sem recarregar
  os assets).

Detalhes técnicos completos de cada um, com trechos de log, estão em
`specs/04-modo-jarbas-wake-word-e-servico/design.md` e
`specs/06-melhorias-de-interface/design.md`.

## Stack técnica

- **Flutter** (Dart ^3.13.3), Android only por enquanto (iOS não foi alvo
  do projeto)
- [`speech_to_text`](https://pub.dev/packages/speech_to_text) — STT nativo
  do Android, compartilhado pelos dois modos
- [`vosk_flutter_service`](https://pub.dev/packages/vosk_flutter_service) —
  motor de wake word 100% offline ([Vosk](https://alphacephei.com/vosk/)),
  modelo pt-BR pequeno embutido nos assets
- [`flutter_foreground_task`](https://pub.dev/packages/flutter_foreground_task)
  — foreground service Android com isolate dedicada, sobrevive em segundo
  plano
- [`vibration`](https://pub.dev/packages/vibration) — feedback tátil ao
  detectar a wake word (funciona em isolate de segundo plano; `HapticFeedback`
  padrão do Flutter não funciona)
- [`audioplayers`](https://pub.dev/packages/audioplayers) — beep sonoro ao
  detectar a wake word (asset sintetizado em `assets/sounds/`)
- [`http`](https://pub.dev/packages/http) — única lib de rede, sem cliente
  adicional
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) —
  persistência local (URL, token, atalhos)
- [`permission_handler`](https://pub.dev/packages/permission_handler)

### Por que `vosk_flutter_service` e não outro pacote Vosk

Existem vários pacotes Flutter para Vosk no pub.dev; a escolha não foi
óbvia. Resumo (detalhes completos em
`specs/04-modo-jarbas-wake-word-e-servico/design.md`, seção "Escolha do
pacote Vosk"):

| Pacote | Por que foi descartado |
|---|---|
| `vosk_flutter_2` | `minSdkVersion 30` — incompatível com Android 10 (API 29), o aparelho dedicado deste projeto nem conseguiria instalar o app |
| `vosk_flutter` (oficial, alphacep) | Abandonado desde 2023, `environment.sdk` trava em Dart <3.0, força downgrade em cascata de outras dependências |
| `vosk_flutter_fixed` | `compileSdkVersion` do próprio pacote inconsistente com suas dependências transitivas — build falha por metadado de AAR |

### Detalhe de build que vale saber

`permission_handler_android` (dependência transitiva do
`vosk_flutter_service`) exige `compileSdk >= 37`; o `android/app/build.gradle.kts`
já fixa isso (`compileSdk = 37`) em vez de usar o padrão do Flutter (hoje
36) — requer a **Android SDK Platform 37** instalada (ver seção de
instalação abaixo).

## Estrutura do projeto

```
ha_voice_app/
├── lib/                    # código do app (ver tabela de módulos acima)
├── assets/
│   ├── icon/                # ícone do app (gerado com PIL)
│   ├── vosk/                 # modelo Vosk pt-BR (wake word "OK Jarbas")
│   └── sounds/                # beep de detecção da wake word (sintetizado)
├── android/                 # config nativa (manifest, foreground service, network security)
├── test/                    # testes automatizados (flutter test)
├── docs/
│   ├── arquitetura.md        # arquitetura técnica em profundidade
│   └── guia_usuario.md       # guia de uso do app (não-técnico)
├── secrets/                  # tokens/chaves de teste locais — nunca commitado (.gitignore)
└── specs/                    # Spec-Driven Development: requirements/design/tasks/teste por etapa
```

## Instalação do ambiente de desenvolvimento

Passo a passo pra deixar uma máquina nova pronta pra compilar e rodar este
projeto. As versões abaixo são as usadas no desenvolvimento; versões
próximas devem funcionar, mas em caso de dúvida use exatamente estas.

- **Flutter**: 3.47.4 (channel stable) / Dart 3.13.3
- **Java (JDK)**: 17 ou superior (usado aqui: OpenJDK 21)
- **Android SDK**: Platform 37 (compileSdk do projeto) + Platform-Tools
  (`adb`)
- **Gradle**: gerenciado pelo wrapper do projeto (9.3.1), não precisa
  instalar à parte

### 1. Instalar o Flutter SDK

**Linux / macOS:**
```bash
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
export PATH="$PATH:$HOME/development/flutter/bin"
# adicione a linha acima no seu ~/.bashrc, ~/.zshrc ou equivalente pra persistir
flutter --version
```

**Windows:** baixe o zip do Flutter SDK em
[flutter.dev/docs/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows),
extraia (ex.: `C:\development\flutter`) e adicione `C:\development\flutter\bin`
ao `PATH` do usuário.

### 2. Instalar o Java (JDK)

```bash
# Linux (Ubuntu/Debian)
sudo apt install openjdk-21-jdk

# macOS (via Homebrew)
brew install openjdk@21

# Windows: baixe o instalador em https://adoptium.net/ (Temurin 21 LTS)
```

Confirme com `java -version`.

### 3. Instalar o Android SDK

O jeito mais simples é instalar o **Android Studio**
([developer.android.com/studio](https://developer.android.com/studio)) —
ele já vem com um gerenciador gráfico de SDKs. Alternativamente, só as
*command-line tools* (mais leve, sem IDE):

```bash
# baixe o zip de "Command line tools only" em
# https://developer.android.com/studio#command-tools
# extraia em, por exemplo, ~/Android/Sdk/cmdline-tools/latest/

export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-37" "build-tools;37.0.0"
```

Depois de instalado (por qualquer um dos dois jeitos), confirme:
```bash
flutter doctor
```
Resolva qualquer item marcado com `✗`/`!` antes de seguir — o mais comum é
aceitar as licenças do Android (`flutter doctor --android-licenses`).

### 4. Buscar as dependências do projeto

```bash
cd ha_voice_app
flutter pub get
```

## Configurar o aparelho Android (Modo Desenvolvedor)

Pra instalar/depurar o app num celular físico (recomendado — o app usa
microfone, foreground service e wake word contínua, difícil de testar bem
num emulador), o aparelho precisa estar em **Modo Desenvolvedor** com
depuração habilitada.

### 1. Ativar as Opções do desenvolvedor

1. Abra **Ajustes → Sobre o telefone** (ou **Sobre o dispositivo**).
2. Procure **Informações de software** (varia por fabricante) e toque
   **7 vezes seguidas** em **Número da versão** (ou **Build number**).
   Depois de alguns toques aparece uma contagem regressiva; ao terminar, a
   mensagem "Você agora é um desenvolvedor!" confirma que ativou.
3. Volte pra **Ajustes** — agora existe um novo item **Opções do
   desenvolvedor** (geralmente dentro de **Configurações gerais** ou
   **Sistema**, dependendo do fabricante/versão do Android).

### 2. Depuração via cabo USB

1. Em **Opções do desenvolvedor**, ative **Depuração USB**.
2. Conecte o aparelho ao computador via cabo USB.
3. No celular vai aparecer um diálogo "Permitir depuração USB?" com a
   impressão digital (fingerprint) RSA do computador — marque **Sempre
   permitir deste computador** e toque **OK**.
4. Confirme que o computador enxerga o aparelho:
   ```bash
   adb devices
   # deve listar algo como:
   # 3547554848373498    device
   ```
   Se aparecer `unauthorized`, olhe a tela do celular — o diálogo de
   autorização pode não ter aparecido ainda ou foi recusado sem querer.

### 3. Depuração sem fio (Wi-Fi) — pra não depender do cabo

Depois que a depuração USB já funcionou pelo menos uma vez (passo
anterior), dá pra continuar trabalhando sem cabo, com o aparelho na mesma
rede Wi-Fi do computador. Duas formas, dependendo da versão do Android:

**Android 11+ (pareamento sem fio nativo, mais robusto):**

1. Em **Opções do desenvolvedor**, ative **Depuração sem fio**.
2. Toque em **Parear dispositivo com código QR** ou **Parear dispositivo
   com código de pareamento** — abre uma tela com um IP:porta e um código
   de 6 dígitos.
3. No computador:
   ```bash
   adb pair <ip>:<porta-de-pareamento>
   # digite o código de 6 dígitos quando solicitado
   adb connect <ip>:<porta-de-conexão>
   # a porta de conexão aparece na tela principal de "Depuração sem fio"
   # (diferente da porta de pareamento)
   adb devices
   ```

**Qualquer versão Android (método `tcpip`, precisa do cabo uma vez por
sessão pra "religar" o modo Wi-Fi):**

1. Conecte o cabo USB uma vez, com a depuração USB já autorizada (passo
   2 acima).
2. Descubra o IP do aparelho na Wi-Fi: **Ajustes → Sobre o telefone → Status**,
   ou:
   ```bash
   adb shell ip addr show wlan0 | grep "inet "
   ```
3. Coloque o adb em modo TCP/IP e conecte:
   ```bash
   adb tcpip 5555
   adb connect <ip-do-aparelho>:5555
   adb devices   # confirma a conexão via Wi-Fi
   ```
4. Pode desconectar o cabo USB — a sessão continua pela rede.

> **Atenção:** em muitos aparelhos Android (esp. Samsung/One UI) o modo
> `adb tcpip` **não persiste** depois de reiniciar o aparelho ou se o
> Wi-Fi cair — nesse caso repita o passo 1 (cabo USB) e o passo 3. O
> pareamento sem fio nativo (Android 11+) costuma ser mais estável entre
> reinícios.

Fixar o IP do aparelho no roteador (reserva de DHCP por endereço MAC)
evita ter que redescobrir o IP toda sessão.

## Como rodar

### Pré-requisitos

- Ambiente configurado conforme a seção acima (`flutter doctor` sem erros
  bloqueantes)
- Aparelho Android em Modo Desenvolvedor, conectado via USB ou Wi-Fi (ver
  acima)
- Um Home Assistant acessível pela rede (local ou Tailscale) com um
  **Long-Lived Access Token** gerado no seu usuário

### Setup e testes

```bash
flutter pub get
flutter test        # roda a suíte automatizada
flutter analyze      # lint/análise estática
```

### Rodar num aparelho

```bash
adb devices                    # confirma o aparelho conectado (USB ou Wi-Fi)
flutter run                    # debug, hot reload
# ou, pra instalar sem manter sessão de debug anexada:
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Depois de instalado, abra o app → ⚙️ Configurações → preencha URL do HA e
token → **Testar conexão** → **Salvar**.

## Build de distribuição

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Sem loja de aplicativos — a instalação é sempre via `adb install` direto
no(s) aparelho(s).

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
| `04` — Modo Jarbas (wake word e serviço) | ✅ Implementada e validada de ponta a ponta no Note 9 (motor Vosk, offline) — falta só medir consumo de bateria em repouso por período prolongado |
| `05` — testes e distribuição | ⬜ Não iniciada |
| `06` — melhorias de interface | ✅ Implementada e validada (barra colorida, beep+vibração, atalhos redesenhados) |

Detalhes de cada etapa ficam registrados no `teste_0N.md` correspondente.

## Segurança e segredos

- `secrets/` é local, gitignored — nunca contém nada versionado. Guarda
  tokens de teste usados durante o desenvolvimento (não são usados
  hardcoded no app: o usuário final configura URL/token pela própria tela
  de Configurações).
- Cleartext HTTP é permitido globalmente
  (`network_security_config.xml`) porque o app fala com o HA na rede local
  (IP dinâmico por DHCP) e/ou via Tailscale — não é exposto à internet
  aberta.
