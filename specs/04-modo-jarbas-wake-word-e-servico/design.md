# Design — Modo Jarbas (Wake Word e Serviço)

## Visão geral da solução

Cria-se `lib/jarbas_service.dart`, responsável pelo ciclo de vida do
Porcupine (wake word) e pela orquestração da captura pós-wake-word, tudo
rodando dentro de um foreground service (`flutter_foreground_task`) para
sobreviver em segundo plano.

## Módulos

### `lib/jarbas_service.dart`
- Start/stop do foreground service com notificação persistente.
- Inicialização do Porcupine com a wake word treinada ("Jarbas").
- Loop de detecção local, sem rede.
- Callback de wake-word-detectada, expondo evento para a UI/orquestração.
- Ao detectar: feedback (bipe + vibração) → pausa wake word → aciona
  `speech_to_text` (mesmo plugin da spec `03`) → timeout de silêncio
  configurável (padrão 5s) → `HaService.sendCommand()` (spec `02`) →
  retoma escuta da wake word.

## Fluxo detalhado

1. Usuário toca "Ativar Modo Jarbas" (botão na `home_screen.dart`, spec
   `03`).
2. `jarbas_service.dart` inicia o foreground service
   (`flutter_foreground_task`), com notificação persistente.
3. Dentro do serviço, inicializa o Porcupine com a wake word treinada.
4. Porcupine roda em loop, processando áudio localmente, sem rede.
5. Ao detectar a palavra:
   a. Emite feedback (bipe curto + vibração).
   b. Pausa a escuta da wake word.
   c. Aciona `speech_to_text` para capturar a frase de comando.
   d. Ao obter resultado final (ou timeout de silêncio configurável,
      padrão 5s), chama `HaService.sendCommand(texto)`.
   e. Retoma a escuta da wake word.
6. Usuário toca "Desativar Modo Jarbas" → encerra foreground service e
   detecção.

## Configuração Android específica

- `foregroundServiceType="microphone"` no manifest (permissões base já
  declaradas em `00-arquitetura-base`).
- Notificação persistente via `flutter_foreground_task`.

## Tratamento de erros

| Cenário | Tratamento |
|---|---|
| Wake word engine falha ao iniciar | Notificar usuário, não ativar o Modo Jarbas silenciosamente |
| Reconhecimento de voz sem resultado após wake word | Retorna à escuta da wake word sem enviar comando vazio |

## Decisões Técnicas

- Indicador de estado (RF-20) fica na `home_screen.dart` (spec `03`), mas o
  estado (ativo/inativo) é publicado por este serviço.
- Timeout de silêncio padrão de 5s, configurável no código (não exposto na
  UI no MVP).

## Riscos legados e mitigação

Não aplicável (projeto novo, sem código legado nesta camada).

## Riscos / pontos em aberto

- Confirmar taxa de detecção/falso-positivo da wake word customizada
  "Jarbas" na plataforma Porcupine; ter uma wake word pronta da biblioteca
  como fallback caso a customizada não funcione bem.
- Confirmar necessidade de autostart do Modo Jarbas ao ligar o aparelho
  dedicado (fora do escopo inicial, mas relevante para uso real 24/7).
- Confirmar se o Android antigo do aparelho dedicado é compatível com
  `porcupine_flutter` e `flutter_foreground_task` (ver risco já registrado
  em `00-arquitetura-base`).
