# Testes — Dados e Persistência

## Status

Planejado.

## Comando

```bash
flutter test test/settings_store_test.dart
```

## Escopo previsto

- Serialização/desserialização de `Shortcut` (`toJson`/`fromJson`).
- `SettingsStore` grava e lê URL/token corretamente (usando
  `SharedPreferences.setMockInitialValues` em teste).
- Primeira execução (sem dados salvos) retorna os 3 atalhos padrão de RF-05.
- Atalhos persistem entre chamadas simulando reabrir o app.

## Critério de aprovação

Todos os testes passam sem tocar em `SharedPreferences` real do
dispositivo (usar mock em memória).

## Resultado

Pendente.
