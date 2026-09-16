# Requirements — Modo Jarbas (Wake Word e Serviço)

**Status:** Rascunho — aguardando aprovação antes de implementar
**Depende de:** `02-integracao-home-assistant`, `03-interface-modo-sob-demanda`

## Objetivo

Permitir que um aparelho dedicado (celular antigo, sempre na tomada) fique
continuamente ouvindo a palavra de ativação "OK Jarbas" e, ao detectá-la,
capture e envie um comando de voz ao HA automaticamente — sem toque manual.

## Contexto do Pedido

O Modo Jarbas roda em segundo plano 24/7 num aparelho dedicado, exigindo
detecção de wake word 100% offline e consumo de bateria/CPU compatível com
uso contínuo. Reaproveita o mesmo `speech_to_text` (spec `03`) e o mesmo
`HaService` (spec `02`) do modo sob demanda.

## Requisitos cobertos

- RF-15: Botão "Ativar Modo Jarbas" na tela principal.
- RF-16: Ao ativar, iniciar detecção contínua e offline de palavra de
  ativação ("OK Jarbas"), rodando em foreground service com notificação
  persistente.
- RF-17: Ao detectar a wake word, emitir feedback sonoro/visual curto e
  então capturar a frase de comando seguinte (reaproveitando o mesmo fluxo
  de reconhecimento de voz do modo sob demanda).
- RF-18: Enviar o comando capturado ao HA da mesma forma que no modo sob
  demanda (RF-12), depois retornar ao estado de escuta da wake word.
- RF-19: Botão "Desativar Modo Jarbas", encerrando o foreground service e
  a detecção de wake word.
- RF-20: Indicador visual claro na tela principal do estado do Modo Jarbas
  (ativo/inativo).
- RNF-01: Detecção de wake word deve funcionar 100% offline.
- RNF-02: Consumo de bateria/CPU em repouso compatível com operação 24/7 em
  aparelho sempre ligado na tomada.

## Fora do Escopo / decisões negociadas

- Múltiplas wake words / múltiplos nomes de assistente.
- Autostart do Modo Jarbas ao ligar o aparelho (decisão em aberto, candidata
  a uma spec futura).

## Critérios de Aceite
- [ ] Modo Jarbas, uma vez ativado num segundo aparelho, detecta a wake
      word e completa o mesmo fluxo de comando sem interação manual além
      da fala.
- [ ] Wake word engine falha ao iniciar → usuário é notificado, Modo Jarbas
      não fica ativado silenciosamente.
- [ ] Reconhecimento de voz sem resultado após a wake word retorna à escuta
      sem enviar comando vazio.
- [ ] Consumo de bateria validado em repouso por um período prolongado no
      aparelho dedicado (ver `teste_04.md`).
