# Design — Interface do Modo Sob Demanda

## Visão geral da solução

Duas telas (`home_screen.dart`, `settings_screen.dart`) consomem
`SettingsStore` (spec `01`) e `HaService` (spec `02`) e o pacote
`speech_to_text`. Nenhuma lógica de rede ou persistência mora nas telas —
elas só orquestram estado de UI e chamam os serviços.

## Módulos

### `lib/home_screen.dart`
- Botão circular de microfone com 2 estados visuais: ouvindo / parado
  (RF-01).
- Integração com `speech_to_text`: inicia captura ao tocar, usa o callback
  de resultado final do plugin para enviar automaticamente via
  `HaService.sendCommand` (RF-02) — sem botão de "enviar" separado.
- Área de texto reconhecido + mensagem de status: ouvindo / enviando /
  resposta do HA / erro (RF-03).
- Grade de atalhos rápidos, um botão por `Shortcut` (RF-04): ao tocar,
  chama `HaService.sendCommand(shortcut.phrase)` direto, sem passar pelo
  microfone.
- Ícone de configurações no topo (`Navigator.push` para
  `settings_screen.dart`) (RF-06).
- Botão "Ativar/Desativar Modo Jarbas" e indicador de estado — implementado
  nesta tela, mas a lógica de start/stop do serviço é da spec `04`.

### `lib/settings_screen.dart`
- Campo de texto para URL do HA (RF-07).
- Campo de texto mascarado para o token (RF-08).
- Botão "Testar conexão" → chama `HaService.testConnection()`, mostra
  sucesso/falha (RF-09).
- Botão "Salvar" → `SettingsStore.setBaseUrl()`/`setToken()` (RF-10).
- Lista de atalhos com adicionar (nome + frase) e remover, persistindo via
  `SettingsStore.setShortcuts()` (RF-11).

## Fluxo — modo sob demanda

1. Usuário toca o microfone → `speech_to_text` começa a ouvir, UI muda
   para estado "ouvindo".
2. Ao detectar fim de fala, o plugin retorna o texto final.
3. UI muda para "enviando", chama `HaService.sendCommand(texto)`.
4. Sucesso → UI mostra a fala de resposta do HA, volta para "parado".
5. Erro → UI mostra mensagem específica por tipo de exceção (spec `02`),
   volta para "parado".

## Decisões Técnicas

- Toda chamada a `HaService` passa por `try/catch` nas exceções tipadas de
  `ha_service.dart`, mapeando cada uma para uma string de mensagem fixa.
- `speech_to_text` configurado com `localeId: 'pt_BR'`.

## Riscos / pontos em aberto

- Comportamento do `speech_to_text` varia por fabricante de Android;
  validar em teste manual no S23 Ultra antes de considerar a spec
  concluída (ver `teste_03.md`).
