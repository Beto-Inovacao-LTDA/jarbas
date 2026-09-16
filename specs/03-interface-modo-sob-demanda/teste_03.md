# Testes — Interface do Modo Sob Demanda

## Status

Planejado.

## Comando

```bash
flutter test test/home_screen_test.dart test/settings_screen_test.dart
```

## Escopo previsto

- Widget test: estado visual do botão de microfone alterna entre
  ouvindo/parado.
- Widget test: grade de atalhos renderiza um botão por `Shortcut` e dispara
  `HaService.sendCommand` com a frase certa (usando um `HaService` fake).
- Widget test: tela de configurações salva URL/token via `SettingsStore`
  fake e reflete mensagens de "Testar conexão".
- Teste manual no S23 Ultra: comando de voz real ponta a ponta ("ligar luz
  da sala") e um atalho configurado, contra um HA real.

## Critério de aprovação

Testes automatizados passam sem depender de rede real; o teste manual
ponta a ponta funciona no aparelho principal com um HA acessível via
Tailscale.

## Resultado

Pendente.
