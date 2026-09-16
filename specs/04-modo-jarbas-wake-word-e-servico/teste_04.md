# Testes — Modo Jarbas (Wake Word e Serviço)

## Status

Planejado.

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

Pendente.
