# Testes — Integração com o Home Assistant

## Status

Planejado.

## Comando

```bash
flutter test test/ha_service_test.dart
```

## Escopo previsto

- `sendCommand` monta URL, headers e corpo corretos (usando um `http.Client`
  mockado, ex.: `mockito` ou `http.MockClient`).
- `sendCommand` extrai `response.speech.plain.speech` de uma resposta 200
  simulada.
- 401 → `HaUnauthorizedException`.
- Timeout simulado → `HaTimeoutException`.
- Erro de socket/conexão simulado → `HaConnectionException`.
- Corpo de resposta sem o campo esperado → `HaUnexpectedResponseException`.
- `testConnection` retorna `true`/`false` conforme o status simulado.

## Critério de aprovação

Todos os cenários de erro da tabela do `design.md` têm um teste
correspondente, sem nenhuma chamada de rede real.

## Resultado

Pendente.
