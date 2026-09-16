# Testes — Modo Jarbas (Wake Word e Serviço)

## Status

Parcialmente validado. **Bloqueado** para o restante: a conta criada em
console.picovoice.ai (2026-09-16, mais de uma tentativa com e-mails
diferentes — corporativo, pessoal, educacional) caiu em revisão manual da
Picovoice ("Thank you for your interest in Picovoice! Your request is in!
Our team will review it shortly... we'll only reach out once we've verified
your commercial use case"). Sem AccessKey liberado, não dá pra treinar a
wake word customizada nem testar detecção real. Decisão registrada: seguir
implementando o código agora (spec `04` completa exceto o motor de wake
word em si) e retomar o restante do teste manual assim que a conta for
aprovada. Alternativas ao Porcupine foram pesquisadas (`open_wake_word` via
openWakeWord, sem gatekeeping de conta) e ficam de pé como plano B se a
aprovação não vier.

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

**Validado no Note 9 (2026-09-16), sem AccessKey configurado:**
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
- Campo de AccessKey (mascarado) adicionado e persistindo na tela de
  Configurações.
- `flutter analyze` e os 19 testes automatizados do projeto (specs 02/03)
  continuam passando; esta spec não tem suíte automatizada própria por
  design (ver Comando acima).

**Pendente (bloqueado pela Picovoice):** detecção real da wake word,
ciclos repetidos wake-word → comando → resposta, teste de timeout de
silêncio com fala real, e validação de consumo de bateria 24/7. Retomar
assim que a conta liberar (ver checklist em `tasks.md`).
