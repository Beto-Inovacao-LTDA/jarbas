# Testes — Testes e Distribuição

## Status

Planejado.

## Comando

```bash
flutter test
flutter build apk --release
```

## Escopo previsto

- Toda a suíte automatizada (`teste_00`–`teste_04`) passando junta.
- Checklist manual de aceite geral (ver `requirements.md` desta spec)
  executado nos dois aparelhos.
- APK release instalado e validado nos dois aparelhos via `adb install`.

## Critério de aprovação

Todos os critérios de aceite gerais do produto são verificados manualmente
nos dois aparelhos reais, sem crash e sem regressão nas specs anteriores.

## Resultado

Pendente.
