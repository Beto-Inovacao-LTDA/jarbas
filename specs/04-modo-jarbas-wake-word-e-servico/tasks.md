# Tasks — Modo Jarbas (Wake Word e Serviço)

## Wake word

- [x] 7.1 ~~Criar conta/AccessKey na Picovoice~~ — abandonado em
      2026-09-16: conta recusada (revisão manual de "verificação de caso de
      uso comercial", sem previsão). Ver `teste_04.md`. Migrado pra Vosk.
- [x] 7.2 Validar taxa de detecção/falso-positivo da wake word "ok jarbas"
      com o modelo Vosk pt-BR num aparelho real — validado em 2026-09-17:
      detectada corretamente em 4 tentativas seguidas, uso normal de sala
      no Note 9. Taxa de falso-positivo em uso prolongado (ruído de fundo)
      ainda não medida — reavaliar se aparecer na prática.
- [x] 7.3 Integrar motor de wake word (`vosk_flutter_service`) em
      `jarbas_service.dart`
- [x] 7.4 Implementar callback de wake-word-detectada expondo evento para
      a UI/orquestração

## Migração de Porcupine pra Vosk (implementada em 2026-09-17)

- [x] 7.5 Baixar o modelo Vosk pt-BR pequeno e embuti-lo em
      `assets/vosk/`, adicionar a entrada em `pubspec.yaml` (`flutter:
      assets:`)
- [x] 7.6 Adicionar dependência de wake word Vosk e remover
      `porcupine_flutter` do `pubspec.yaml` — pacote usado:
      `vosk_flutter_service` (não o `vosk_flutter_2` do plano original nem
      o `vosk_flutter` oficial; ver `design.md`, "Escolha do pacote Vosk",
      pro porquê de cada um ter sido descartado)
- [x] 7.7 Reescrever `JarbasTaskHandler` em `lib/jarbas_service.dart`:
      trocar `PorcupineManager` por `ModelLoader.loadFromAssets` +
      `createModel` + `createRecognizer(grammar: ['ok jarbas', '[unk]'])` +
      `initSpeechService`, mantendo o mesmo fluxo de feedback/captura/envio
- [x] 7.8 Remover a pasta `assets/porcupine/` e o campo de AccessKey da
      Picovoice (`settings_store.dart`, `settings_screen.dart`,
      `test/settings_screen_test.dart`)
- [x] 7.9 Atualizar mensagens de erro do fluxo de start (permissão de
      microfone negada / erro genérico de inicialização do Vosk)
- [x] 7.10 Ajustes de build não previstos no plano original: `compileSdk`
      subido pra 37 em `android/app/build.gradle.kts` (exigido pelo
      `permission_handler_android` transitivo), `permission_handler`
      atualizado pra `^13.0.0`, `android/app/proguard-rules.pro` criado,
      patch obsoleto de `compileSdkVersion` do Porcupine removido de
      `android/build.gradle.kts`
- [x] 7.11 Corrigir dois crashes reais encontrados na validação em
      dispositivo (`onDestroy` sem `stop()` antes do `dispose()`; reinício
      do mesmo `AudioRecord` do Vosk depois do `speech_to_text` usar o
      microfone) — ver `design.md`, "Bugs de crash corrigidos"
- [x] 7.12 Trocar feedback tátil (`HapticFeedback`/`SystemSound`, sem
      efeito na isolate de segundo plano) pelo pacote `vibration` — ver
      `design.md`, "Feedback tátil roda numa isolate sem Activity"

## Foreground service

- [x] 8.1 Declarar `foregroundServiceType="microphone"` no manifest
- [x] 8.2 Integrar `flutter_foreground_task`, criar notificação persistente
- [x] 8.3 Implementar start/stop do serviço a partir dos botões
      "Ativar"/"Desativar Modo Jarbas" (RF-15, RF-19)

## Orquestração do fluxo completo

- [x] 9.1 Ao detectar wake word: feedback sonoro/visual (RF-17)
- [x] 9.2 Acionar `speech_to_text` para captura da frase seguinte
- [x] 9.3 Timeout de silêncio configurável (padrão 5s) para evitar espera
      indefinida
- [x] 9.4 Enviar comando capturado via `HaService.sendCommand()` (RF-18)
- [x] 9.5 Retornar ao estado de escuta da wake word após o envio
- [x] 9.6 Indicador visual de estado ativo/inativo na tela principal
      (RF-20)

## Pendente pra validação final

- [x] Rodar `flutter pub get`/`flutter analyze`/`flutter test` após a
      migração pra Vosk — tudo passando (19/19 testes)
- [x] Instalar no aparelho dedicado (Note 9) — `adb install` funcionou,
      confirma compatibilidade de `minSdkVersion`
- [x] Validar detecção real de "ok jarbas" falando de verdade no aparelho
      — detectada corretamente em 4 ciclos seguidos
- [x] Ciclo completo (wake word → comando → HA → volta a escutar) — "ligar
      spot mesa" executou de verdade no HA, repetido sem crash
- [x] Desativar Modo Jarbas — encerra de forma limpa, sem crash
- [ ] Validação de consumo de bateria em repouso por período prolongado
      (algumas horas) — não feito nesta sessão

## Dependências

Depende de `02-integracao-home-assistant` (`HaService`) e
`03-interface-modo-sob-demanda` (mesmo `speech_to_text`, botão/indicador na
`home_screen.dart`). Fornece a base para a validação final em
`05-testes-e-distribuicao`.
