# Testes — Modo Jarbas (Wake Word e Serviço)

## Status

**Motor de wake word migrado de Porcupine pra Vosk em 2026-09-17**
(`vosk_flutter_service`) — decisão de 2026-09-16, porque a conta criada em
console.picovoice.ai (mais de uma tentativa com e-mails diferentes —
corporativo, pessoal, educacional) caiu em revisão manual da Picovoice
("Thank you for your interest in Picovoice! Your request is in! Our team
will review it shortly... we'll only reach out once we've verified your
commercial use case"), sem AccessKey liberado e sem previsão. Vosk é
offline, open-source, sem gatekeeping de conta.

**Ciclo completo validado no Note 9 em 2026-09-17**: wake word detectada,
feedback tátil, captura do comando, execução no HA e retorno à escuta —
tudo funcionando em produção, sem crash. Dois bugs de crash reais foram
encontrados e corrigidos durante a validação (ver Resultado). Consumo de
bateria 24/7 ainda não validado (precisa de um período prolongado, fora do
escopo desta sessão).

## Comando

Não há suíte automatizada completa (wake word e foreground service
dependem de hardware/áudio real). Testes manuais no aparelho dedicado:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Escopo previsto

- Ativar Modo Jarbas → notificação persistente aparece, indicador na tela
  muda para "ativo".
- Falar "OK Jarbas" a distâncias/volumes variados → medir taxa de
  detecção/falso-positivo.
- Após detecção: feedback sonoro/visual, captura da frase seguinte, envio
  ao HA, retorno à escuta — repetir por vários ciclos seguidos.
- Silêncio após a wake word (sem falar comando) → volta à escuta sem
  enviar comando vazio.
- Desativar Modo Jarbas → notificação some, indicador volta a "inativo".
- Consumo de bateria/CPU em repouso por período prolongado (algumas horas)
  no aparelho dedicado, com otimização de bateria desativada para o app.

## Critério de aprovação

Wake word detectada de forma confiável em uso normal de sala, fluxo
completo funciona sem interação manual além da fala, e consumo de bateria
em repouso é compatível com operação 24/7.

## Resultado

**Validado no Note 9 (2026-09-16), com Porcupine e sem AccessKey
configurado** (comportamento pré-migração, mantido aqui como histórico):
- Botão "Ativar Modo Jarbas" sobe o foreground service de verdade
  (notificação `jarbas_wake_word`, id 1000, confirmada no logcat/EdgeLighting
  do sistema) e o `JarbasTaskHandler.onStart` roda numa isolate separada.
- Sem AccessKey salvo, o handler detecta a falta de configuração, manda
  `FlutterForegroundTask.stopService()` sozinho e a notificação some em
  menos de 1s — exatamente o comportamento esperado (não fica "ativo" sem
  detecção de verdade rodando).
- A tela principal reflete isso: indicador volta a "Modo Jarbas inativo",
  switch desliga sozinho, mensagem "Configure o AccessKey da Picovoice nas
  configurações." aparece.

**Validado após a migração pra Vosk (2026-09-17):**
- `flutter pub get` resolve as dependências (`vosk_flutter_service ^0.1.3`,
  `permission_handler ^13.0.0`) sem conflito.
- `flutter analyze`: sem erros.
- `flutter test`: 19/19 passando (specs 02/03; esta spec não tem suíte
  automatizada própria por design, ver Comando acima — o teste do campo de
  AccessKey da Picovoice foi removido de `settings_screen_test.dart`).
- `flutter build apk --debug`: build completo com sucesso (precisou subir
  `compileSdk` do módulo `app` pra 37 — ver `design.md`).
- `adb install -r` do APK debug no Note 9 (Android 10, API 29): instalação
  bem-sucedida — confirma que `minSdkVersion 21` do `vosk_flutter_service`
  é compatível com o aparelho dedicado.
- App abre sem crash (`adb logcat` sem `FATAL EXCEPTION`/`AndroidRuntime`
  para o pacote `com.betoinovacao.ha_voice_app` durante o lançamento).

**Ciclo completo validado no Note 9 (2026-09-17), com o app já instalado e
o aparelho desbloqueado:**
- "Ok Jarbas" detectado corretamente pelo Vosk (`{"text": "ok jarbas"}` no
  log), em 4 ciclos seguidos sem crash.
- Feedback tátil (vibração de 200ms via pacote `vibration`) confirmado
  tanto no log (`VibratorService: vibrate - package:
  com.betoinovacao.ha_voice_app`) quanto sentido fisicamente pelo usuário.
- Comando falado em seguida ("ligar spot mesa") capturado pelo
  `speech_to_text` e enviado ao HA — luz "spot mesa" mudou de estado de
  verdade, confirmado pelo usuário.
- Após o envio, retorno automático à escuta da wake word — repetido por
  múltiplos ciclos sem crash nem intervenção manual.
- Desativar Modo Jarbas pelo switch: serviço encerra de forma limpa
  (`dumpsys activity services` sem entradas, notificação some), processo
  do app continua vivo, sem crash.

**Dois bugs de crash reais encontrados e corrigidos nesta sessão** (ver
`design.md` para detalhes técnicos):
1. Desativar o Modo Jarbas derrubava o app inteiro:
   `onDestroy` chamava `dispose()` no `SpeechService` sem chamar `stop()`
   antes — liberava o `AudioRecord` nativo enquanto a thread do Vosk podia
   ainda estar lendo dele, gerando `RuntimeException: error reading audio
   buffer` (Java, numa thread crua, não capturável do lado Dart) e
   derrubando o processo. Corrigido chamando `stop()` antes de `dispose()`.
2. O Modo Jarbas parava de responder depois do primeiro ciclo completo:
   reiniciar o mesmo `AudioRecord` do Vosk logo depois do
   `speech_to_text` (Google) ter usado o microfone para capturar o comando
   causava o mesmo crash. Corrigido descartando e recriando o
   `SpeechService` (reaproveitando o modelo/recognizer já carregados) a
   cada ciclo, em vez de reiniciar o mesmo `AudioRecord`.

**Ainda pendente:** validação de consumo de bateria/CPU em repouso por
período prolongado (algumas horas) no aparelho dedicado — fora do escopo
desta sessão, requer o aparelho ligado sem uso por várias horas.
