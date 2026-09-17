# Design — Modo Jarbas (Wake Word e Serviço)

## Visão geral da solução

`lib/jarbas_service.dart` é responsável pelo ciclo de vida do motor de wake
word e pela orquestração da captura pós-wake-word, tudo rodando dentro de
um foreground service (`flutter_foreground_task`) para sobreviver em
segundo plano.

> **Nota (2026-09-17): migração de Porcupine pra Vosk implementada.**
> Motivo da troca: a conta criada em console.picovoice.ai caiu em revisão
> manual de "caso de uso comercial", sem previsão de liberação (ver
> `teste_04.md`). Vosk é offline, open-source e não exige conta/API key.

## Escolha do pacote Vosk (2026-09-17)

O plano original (spec revisada em 2026-09-16) apontava `vosk_flutter_2`.
Na implementação, esse pacote se mostrou inviável e dois outros foram
descartados antes de chegar no usado de fato:

| Pacote | Por que foi descartado |
|---|---|
| `vosk_flutter_2` (bilal-codingkey) | `minSdkVersion 30` no `android/build.gradle` — o Note 9 roda Android 10 (API 29) e **não conseguiria nem instalar o app** |
| `vosk_flutter` (alphacep, oficial, 0.3.48) | Pacote abandonado desde 2023: `environment.sdk: <3.0.0` no `pubspec.yaml`, incompatível com o Dart 3.13 deste projeto; força downgrade de `http`/`permission_handler` em cascata |
| `vosk_flutter_fixed` (dima-xd) | `minSdkVersion 21` e Dart 3 OK, mas o próprio pacote declara `compileSdk 33` enquanto suas dependências transitivas (`androidx.lifecycle` etc.) exigem `compileSdk >= 34` — build falha por metadado de AAR inconsistente (mesma classe de problema que o `porcupine_flutter` já tinha dado nesta spec) |

**Usado:** [`vosk_flutter_service`](https://pub.dev/packages/vosk_flutter_service)
(dhia-bechattaoui, fork ativo do `vosk_flutter` oficial, última publicação
2026-09-05) — `minSdkVersion 21` (compatível com o Note 9), `compileSdk 36`
próprio, `environment.sdk: >=3.11.0 <4.0.0` (compatível com Dart 3.13), API
Dart idêntica ao `vosk_flutter` oficial (mesmas classes
`VoskFlutterPlugin`/`ModelLoader`/`Model`/`Recognizer`/`SpeechService`).
Import: `package:vosk_flutter_service/vosk_flutter_service.dart`.

Efeito colateral: `permission_handler_android` (dependência transitiva do
`vosk_flutter_service` via `permission_handler: ^13.0.0`) exige
`compileSdk >= 37`. `android/app/build.gradle.kts` foi ajustado pra
`compileSdk = 37` (Android SDK Platform 37.0 já instalado localmente) — ver
seção "Configuração Android específica".

## Módulos

### `lib/jarbas_service.dart`
- Start/stop do foreground service com notificação persistente.
- Inicialização do Vosk (`ModelLoader.loadFromAssets` + `createModel` +
  `createRecognizer` com `grammar: ['ok jarbas', '[unk]']` +
  `initSpeechService`).
- Loop de detecção local, sem rede.
- Callback de wake-word-detectada, expondo evento para a UI/orquestração.
- Ao detectar: feedback (vibração via pacote `vibration`) → descarta e
  recria o `SpeechService` do Vosk (ver "Bugs de crash corrigidos") →
  aciona `speech_to_text` (mesmo plugin da spec `03`) → timeout de silêncio
  configurável (padrão 5s) → `HaService.sendCommand()` (spec `02`) →
  retoma escuta da wake word com um `SpeechService` novo.

## Fluxo detalhado

1. Usuário toca "Ativar Modo Jarbas" (botão na `home_screen.dart`, spec
   `03`).
2. `jarbas_service.dart` inicia o foreground service
   (`flutter_foreground_task`), com notificação persistente.
3. Dentro do serviço, inicializa o Vosk (modelo pt-BR embutido nos assets,
   recognizer com gramática restrita à frase "ok jarbas").
4. O `SpeechService` do Vosk roda em loop, processando áudio localmente,
   sem rede.
5. Ao detectar a palavra:
   a. Emite feedback (vibração curta, 200ms).
   b. Para e libera o `SpeechService` do Vosk (`stop()` + `dispose()`,
      libera o `AudioRecord` nativo).
   c. Aciona `speech_to_text` para capturar a frase de comando.
   d. Ao obter resultado final (ou timeout de silêncio configurável,
      padrão 5s), chama `HaService.sendCommand(texto)`.
   e. Cria um `SpeechService` novo (reaproveitando o `recognizer`/modelo já
      carregados) e retoma a escuta da wake word.
6. Usuário toca "Desativar Modo Jarbas" → `stop()` no `SpeechService` atual,
   depois `dispose()` → encerra foreground service e detecção.

## Migração de Porcupine pra Vosk (implementada em 2026-09-17)

O que saiu do código:
- Dependência `porcupine_flutter` no `pubspec.yaml`.
- Import e uso de `PorcupineManager`/`PorcupineException` em
  `lib/jarbas_service.dart`.
- Pasta `assets/porcupine/` (só tinha o `README.md` — os arquivos
  `.ppn`/`.pv` nunca chegaram a existir).
- Campo de AccessKey da Picovoice: `getPorcupineAccessKey`/
  `setPorcupineAccessKey` em `lib/settings_store.dart`, o
  `TextEditingController`/`TextField` correspondente em
  `lib/settings_screen.dart` (chave `porcupine_access_key_field`), e o
  fake correspondente em `test/settings_screen_test.dart`.
- Patch de `compileSdkVersion` em `android/build.gradle.kts` que existia só
  por causa do `porcupine_flutter`/`flutter_voice_processor` (removido —
  não é mais necessário).

O que entrou no lugar:
- Dependência `vosk_flutter_service: ^0.1.3` no `pubspec.yaml` (ver
  "Escolha do pacote Vosk" acima).
- Modelo `vosk-model-small-pt-0.3` (Vosk pt-BR pequeno, ~31MB) embutido em
  `assets/vosk/vosk-model-small-pt-0.3.zip`, baixado de
  alphacephei.com/vosk/models e referenciado em `flutter: assets:`.
- `JarbasTaskHandler` reescrito: `ModelLoader().loadFromAssets(...)` +
  `vosk.createModel(...)` + `vosk.createRecognizer(model:, sampleRate:
  16000, grammar: ['ok jarbas', '[unk]'])` + `vosk.initSpeechService(...)`
  no lugar de `PorcupineManager`. Resultado do reconhecimento chega via
  `speechService.onResult()` (stream de JSON `{"text": "..."}`); o handler
  decodifica e compara o texto normalizado com `"ok jarbas"` pra disparar
  a captura de comando.
- Sem AccessKey/conta — o campo de configuração da Picovoice foi removido
  da tela de Configurações, nada o substitui.
- Mensagens de erro adaptadas: `MicrophoneAccessDeniedException` vira
  "Permissão de microfone negada para o Modo Jarbas."; qualquer outra
  falha na inicialização do Vosk (ex. modelo corrompido) cai no `catch`
  genérico com a mensagem do erro original.
- `android/app/proguard-rules.pro` criado com as regras de `keep` pra JNA
  recomendadas pelo pacote (só tem efeito se `minifyEnabled` for ativado no
  futuro — hoje não está).

## Bugs de crash corrigidos na validação (2026-09-17)

Ao validar o ciclo completo no Note 9 depois da migração, o app crashava
(processo inteiro morria) em dois cenários. Causa raiz em ambos: o
`SpeechService` nativo do Vosk (classe `org.vosk.android.SpeechService`, da
lib `com.alphacephei:vosk-android` usada por todos os forks do
`vosk_flutter`) roda uma thread Java crua (`RecognizerThread`) que faz
`AudioRecord.read()` em loop; se `read()` retorna um valor negativo (erro),
o código lança `throw new RuntimeException("error reading audio buffer")`
**sem tratamento** — uma exceção não capturável do lado Dart, que derruba o
processo inteiro. Ver o [source do
`SpeechService.java`](https://github.com/alphacep/vosk-api/blob/master/android/lib/src/main/java/org/vosk/android/SpeechService.java)
pra referência completa (`RecognizerThread.run()`, linha do `throw`).

1. **App fechava ao desativar o Modo Jarbas.** `onDestroy()` chamava
   `speechService.dispose()` direto, sem chamar `.stop()` antes.
   `dispose()` (→ `speechService.destroy` no method channel →
   `SpeechService.shutdown()`) libera o `AudioRecord`
   (`recorder.release()`) imediatamente; se a `RecognizerThread` ainda
   estiver no meio de um `read()` nesse instante, o `read()` seguinte falha
   e crasha. `.stop()` (→ `recognizerThread.interrupt(); .join()`) garante
   que a thread já saiu do loop e chamou `recorder.stop()` (não `release()`)
   antes de retornar — só depois disso é seguro chamar `dispose()`.
   **Fix:** `_stopWakeWordListening()` sempre chama `.stop()` antes de
   `.dispose()`.
2. **Modo Jarbas parava de responder depois do primeiro ciclo completo.**
   Ao detectar a wake word, o código antigo fazia `.stop()` no
   `SpeechService`, aguardava a captura via `speech_to_text` (que usa o
   `SpeechRecognizer`/`AudioRecord` do Google, um processo diferente
   disputando o mesmo microfone), e depois chamava `.start()` de novo no
   **mesmo** `SpeechService`/`AudioRecord`. Reiniciar a gravação nesse
   objeto logo depois de outro app ter usado o microfone se mostrou frágil
   — o `AudioRecord` reiniciava só aparentemente, e a próxima leitura
   falhava com o mesmo `RuntimeException`, matando o processo em segundo
   plano sem aviso nenhum (a wake word simplesmente "parava de funcionar").
   **Fix:** depois de capturar o comando, o `SpeechService` antigo é
   descartado (`stop()` + `dispose()`) e um **novo** é criado via
   `vosk.initSpeechService(_voskRecognizer!)` — reaproveita o `recognizer`
   e o modelo já carregados (não recarrega os ~31MB de assets), só recria a
   camada do `AudioRecord`. Ver `_startWakeWordListening()`/
   `_stopWakeWordListening()` em `lib/jarbas_service.dart`.

Ambos validados: 4 ciclos completos seguidos (wake word → comando → HA →
volta a escutar) sem crash, e desativar o Modo Jarbas várias vezes sem
derrubar o app.

## Feedback tátil roda numa isolate sem Activity

`HapticFeedback.mediumImpact()`/`SystemSound.play()` (usados na primeira
versão do código pós-migração) não tiveram efeito perceptível nenhum no
teste real — essas APIs do Flutter dependem do canal
`SystemChannels.platform`, que por sua vez depende de uma `Activity`/View
anexada; a isolate de segundo plano do `flutter_foreground_task` não tem
nenhuma das duas. Substituído pelo pacote
[`vibration`](https://pub.dev/packages/vibration) (`^3.2.1`), que aciona o
`Vibrator`/`VibratorManager` do Android direto via `Context` da aplicação —
funciona em isolate headless. Confirmado no log
(`VibratorService: vibrate - package: com.betoinovacao.ha_voice_app`) e
sentido fisicamente pelo usuário no teste real.

## Configuração Android específica

- `foregroundServiceType="microphone"` no manifest (permissões base já
  declaradas em `00-arquitetura-base`) — não mudou com a migração.
- Notificação persistente via `flutter_foreground_task` — não mudou com a
  migração.
- `compileSdk` do módulo `app` subido pra `37` em
  `android/app/build.gradle.kts` (o padrão do Flutter, `36`, não satisfazia
  o `permission_handler_android` puxado pelo `vosk_flutter_service` — ver
  "Escolha do pacote Vosk"). Requer a Android SDK Platform 37 instalada.

## Tratamento de erros

| Cenário | Tratamento |
|---|---|
| Wake word engine falha ao iniciar (ex.: modelo Vosk ausente/corrompido) | Notificar usuário, não ativar o Modo Jarbas silenciosamente |
| Reconhecimento de voz sem resultado após wake word | Retorna à escuta da wake word sem enviar comando vazio |
| `AudioRecord` nativo do Vosk falha ao ler (erro do SO, ver "Bugs de crash corrigidos") | Nunca reiniciar o mesmo `SpeechService`/`AudioRecord` após um `.stop()`; sempre descartar e recriar |

## Decisões Técnicas

- Indicador de estado (RF-20) fica na `home_screen.dart` (spec `03`), mas o
  estado (ativo/inativo) é publicado por este serviço.
- Timeout de silêncio padrão de 5s, configurável no código (não exposto na
  UI no MVP).

## Riscos legados e mitigação

Não aplicável (projeto novo, sem código legado nesta camada).

## Riscos / pontos em aberto

- ~~Confirmar taxa de detecção/falso-positivo da wake word "ok jarbas"~~ —
  confirmado em 2026-09-17: detectada corretamente em 4 tentativas seguidas
  em uso normal de sala no Note 9. Taxa de falso-positivo em uso prolongado
  (ruído de TV, conversas ao fundo) ainda não medida.
- Confirmar necessidade de autostart do Modo Jarbas ao ligar o aparelho
  dedicado (fora do escopo inicial, mas relevante para uso real 24/7).
- ~~Confirmar se o Android antigo do aparelho dedicado é compatível com o
  motor de wake word~~ — confirmado em 2026-09-17: `adb install` do APK
  com `vosk_flutter_service` funcionou no Note 9 (Android 10 / API 29),
  `minSdkVersion 21` do pacote é compatível.
- Consumo de bateria/CPU em repouso por período prolongado (RNF-02) ainda
  não medido — precisa de um teste de várias horas com o aparelho em uso
  normal, fora do escopo desta sessão.
