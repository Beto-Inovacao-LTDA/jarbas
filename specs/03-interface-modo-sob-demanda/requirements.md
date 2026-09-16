# Requirements — Interface do Modo Sob Demanda

**Status:** Rascunho — aguardando aprovação antes de implementar
**Depende de:** `01-dados-e-persistencia`, `02-integracao-home-assistant`

## Objetivo

Entregar a tela principal (microfone + atalhos) e a tela de configurações,
cobrindo o fluxo completo do modo sob demanda: usuário toca o microfone,
fala, o app transcreve, envia ao HA e mostra a resposta.

## Contexto do Pedido

Este é o modo de uso primário do app no aparelho principal (S23 Ultra). O
Modo Jarbas (spec `04`) reaproveita o mesmo `speech_to_text` e o mesmo
`HaService`, mas dispara a captura por wake word em vez de toque.

## Requisitos cobertos

- RF-01: Botão circular de microfone, com estado visual distinto entre
  "ouvindo" e "parado".
- RF-02: Ao tocar o microfone, capturar áudio, transcrever em pt-BR e
  enviar automaticamente ao finalizar a fala (sem botão de "enviar"
  separado).
- RF-03: Exibir o texto reconhecido e uma mensagem de status (ouvindo /
  enviando / resposta do HA / erro).
- RF-04: Grade de atalhos rápidos — botões que disparam uma frase de
  comando fixa direto pro HA, sem usar o microfone.
- RF-05: Atalhos padrão visíveis na primeira execução (modelo já coberto
  pela spec `01`).
- RF-06: Acesso à tela de configurações via ícone no topo.
- RF-07: Campo de URL do Home Assistant.
- RF-08: Campo de token (mascarado).
- RF-09: Botão "Testar conexão" (UI; lógica de validação é da spec `02`).
- RF-10: Botão "Salvar", persistindo localmente URL e token.
- RF-11: Gerenciamento de atalhos: adicionar (nome + frase) e remover.

## Fora do Escopo / decisões negociadas

- Resposta falada (TTS) do resultado do comando.
- Tela de histórico de comandos enviados.
- Indicador do Modo Jarbas na tela principal — spec `04` (RF-20), embora o
  botão "Ativar Modo Jarbas" apareça nesta tela.

## Critérios de Aceite
- [ ] Um comando de voz simples ("ligar luz da sala", com entidade já
      cadastrada no HA) funciona de ponta a ponta no modo sob demanda.
- [ ] Um atalho configurado dispara o mesmo resultado sem usar o microfone.
- [ ] Erros de `HaService` (401, timeout, falha de conexão, resposta
      inesperada) aparecem como mensagem de status distinta na tela
      principal, sem derrubar o app.
- [ ] Configuração de URL/token sobrevive a reiniciar o app.
- [ ] "Testar conexão" valida URL + token contra a API do HA antes de
      salvar.
