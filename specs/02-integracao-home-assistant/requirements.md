# Requirements — Integração com o Home Assistant

**Status:** Implementada e validada por testes unitários
**Depende de:** `00-arquitetura-base`, `01-dados-e-persistencia`

## Objetivo

Implementar a única forma de comunicação do app com o Home Assistant:
enviar texto ao endpoint do Assist e tratar os erros previsíveis, sem
nenhuma interpretação própria de comando.

## Contexto do Pedido

Home Assistant é acessado via Tailscale (MagicDNS) com HTTP puro dentro da
tailnet (já criptografado pelo WireGuard). Autenticação via Long-Lived
Access Token (Bearer). Tanto o modo sob demanda quanto o Modo Jarbas
(specs `03` e `04`) reusam este mesmo serviço.

## Requisitos cobertos

- RF-09: Botão "Testar conexão", validando URL + token contra a API do HA
  antes de salvar (lógica de validação; o botão em si é UI — spec `03`).
- RF-12: Toda comunicação via `POST {url}/api/conversation/process`, corpo
  `{"text": "<frase>", "language": "pt-BR"}`, header `Authorization: Bearer
  <token>`.
- RF-13: Sem interpretação própria de comando — delega 100% ao Assist do HA.
- RF-14: Tratamento explícito de erros: token inválido (401), timeout,
  falha de conexão, resposta inesperada — cada um com mensagem própria.

## Fora do Escopo / decisões negociadas

- UI que exibe as mensagens de erro — spec `03`.
- Qualquer lógica de NLU/parsing de comando no app (delega 100% ao HA).
- Funcionamento do envio de comando sem conectividade com a tailnet
  Tailscale (fora de escopo geral do produto).

## Critérios de Aceite
- [x] `HaService.sendCommand(texto)` faz `POST /api/conversation/process`
      com o corpo e header corretos e retorna a fala de resposta
      (`response.speech.plain.speech`).
- [x] `HaService.testConnection(url, token)` retorna sucesso/falha sem
      persistir nada.
- [x] 401 (token inválido), timeout e falha de conexão geram erros
      distintos e identificáveis pelo chamador.
- [x] Resposta HTTP com formato inesperado (sem quebrar o app) é tratada
      como erro.
