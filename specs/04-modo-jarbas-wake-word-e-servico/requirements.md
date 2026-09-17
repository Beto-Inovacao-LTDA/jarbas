# Requirements — Modo Jarbas (Wake Word e Serviço)

**Status:** Migração de Picovoice/Porcupine pra Vosk **implementada e
validada de ponta a ponta** no Note 9 em 2026-09-17 (motivo original: conta
Picovoice presa em revisão manual sem previsão). Motor final:
`vosk_flutter_service` (não `vosk_flutter_2` nem o `vosk_flutter` oficial —
ver `design.md`, seção "Escolha do pacote", para o porquê). Ciclo completo
funcionando de verdade: "ok jarbas" detectado → feedback tátil → comando
capturado → executado no HA → retorno à escuta — repetido em múltiplos
ciclos sem crash. Dois bugs de crash reais (deriv de reiniciar/liberar o
`AudioRecord` nativo do Vosk de forma insegura) foram encontrados e
corrigidos durante essa validação, ver `teste_04.md` e `design.md`.
**Pendente:** validação de consumo de bateria/CPU em repouso por período
prolongado (RNF-02).
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
- Motor de wake word: decidido Vosk no lugar de Picovoice/Porcupine (ver
  Status acima). Alternativa `open_wake_word` pesquisada e descartada em
  favor do Vosk, mas registrada como plano C se o Vosk não performar bem no
  aparelho real.

## Critérios de Aceite
- [x] Modo Jarbas, uma vez ativado num segundo aparelho, detecta a wake
      word e completa o mesmo fluxo de comando sem interação manual além
      da fala. Validado no Note 9 em 2026-09-17: "ok jarbas" + "ligar spot
      mesa" executou de verdade no HA, em múltiplos ciclos seguidos.
- [ ] Wake word engine falha ao iniciar → usuário é notificado, Modo Jarbas
      não fica ativado silenciosamente. Validado no Note 9 com Porcupine
      (sem AccessKey configurado); ainda não re-testado com o cenário de
      falha específico do Vosk (ex.: permissão de microfone negada) — código
      implementado (`_fail` em `JarbasTaskHandler`), mas esse cenário exato
      não foi forçado na validação de 2026-09-17.
- [x] Reconhecimento de voz sem resultado após a wake word retorna à escuta
      sem enviar comando vazio — comportamento do código, coerente com os
      múltiplos ciclos de escuta→captura→escuta observados na validação.
- [ ] Consumo de bateria validado em repouso por um período prolongado no
      aparelho dedicado (ver `teste_04.md`).
