# Design — Integração com o Home Assistant

## Visão geral da solução

Cria-se `lib/ha_service.dart` com a classe `HaService`, único ponto de
contato HTTP com o Home Assistant. Recebe `baseUrl`/`token` (lidos via
`SettingsStore`, spec `01`) e expõe métodos de alto nível para a UI (spec
`03`) e para o Modo Jarbas (spec `04`).

## Módulos

### `lib/ha_service.dart`

#### `class HaService`
- `Future<String> sendCommand(String baseUrl, String token, String text)`
  → `POST {baseUrl}/api/conversation/process`, extrai
  `response.speech.plain.speech` do corpo de resposta.
- `Future<bool> testConnection(String baseUrl, String token)` → mesma
  chamada com um texto neutro (ou `GET /api/`), só valida status 2xx.
- Erros tipados (ex.: `HaUnauthorizedException`, `HaTimeoutException`,
  `HaConnectionException`, `HaUnexpectedResponseException`), para que a UI
  (spec `03`) escolha a mensagem certa sem fazer `catch (e)` genérico.

## Contrato de requisição

```
POST {baseUrl}/api/conversation/process
Headers: Authorization: Bearer {token}, Content-Type: application/json
Body: {"text": "<frase>", "language": "pt-BR"}
```

Resposta relevante extraída: `response.speech.plain.speech`.

## Fluxo

1. Chamador (home_screen ou jarbas_service) obtém `baseUrl`/`token` via
   `SettingsStore`.
2. Chama `HaService.sendCommand(...)`.
3. `HaService` faz o `POST`, aplica timeout, interpreta status code e
   corpo, e retorna texto ou lança exceção tipada.

## Tratamento de erros

| Cenário | Tratamento |
|---|---|
| Token inválido (401) | Lança `HaUnauthorizedException`; UI mostra mensagem clara, não derruba o app |
| Timeout de rede | Lança `HaTimeoutException`; UI mostra falha de conexão, mantém estado anterior |
| Falha de conexão (host inalcançável) | Lança `HaConnectionException` |
| Resposta inesperada (JSON sem o campo esperado) | Lança `HaUnexpectedResponseException` |

## Decisões Técnicas

- Usar o pacote `http` (já listado em `00-arquitetura-base`), sem cliente
  HTTP adicional.
- Timeout configurável com valor padrão razoável (ex.: 10s) para não travar
  a UI indefinidamente.
- Nenhuma lógica de interpretação de comando no app — texto bruto vai e
  volta como está (RF-13).

## Riscos / pontos em aberto

- Confirmar o formato exato de erro que o HA retorna para token inválido
  (pode não ser sempre 401 puro) — ajustar `HaUnauthorizedException` durante
  a implementação se necessário.
