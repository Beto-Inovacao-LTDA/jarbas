# Tasks — Modo Jarbas (Wake Word e Serviço)

## Wake word

- [ ] 7.1 Criar conta/AccessKey na Picovoice, treinar wake word "Jarbas"
      — **bloqueado**: conta em revisão manual da Picovoice ("verificação de
      caso de uso comercial"), sem previsão. Ver `teste_04.md`.
- [ ] 7.2 Validar taxa de detecção/falso-positivo da wake word treinada
      (decisão em aberto — só prosseguir após validar) — depende de 7.1
- [x] 7.3 Integrar `porcupine_flutter` em `jarbas_service.dart`
- [x] 7.4 Implementar callback de wake-word-detectada expondo evento para
      a UI/orquestração

## Foreground service

- [x] 8.1 Declarar `foregroundServiceType="microphone"` no manifest
- [x] 8.2 Integrar `flutter_foreground_task`, criar notificação persistente
- [x] 8.3 Implementar start/stop do serviço a partir dos botões
      "Ativar"/"Desativar Modo Jarbas" (RF-15, RF-19)

## Orquestração do fluxo completo

- [x] 9.1 Ao detectar wake word: feedback sonoro/visual (RF-17)
- [x] 9.2 Acionar `speech_to_text` para captura da frase seguinte
- [x] 9.3 Timeout de silêncio configurável (padrão 5s) para evitar espera
      indefinida
- [x] 9.4 Enviar comando capturado via `HaService.sendCommand()` (RF-18)
- [x] 9.5 Retornar ao estado de escuta da wake word após o envio
- [x] 9.6 Indicador visual de estado ativo/inativo na tela principal
      (RF-20)

## Pendente quando a Picovoice liberar a conta (tarefa 7.1)

- [ ] Treinar "OK Jarbas" (idioma Portuguese, plataforma Android) no
      Picovoice Console, baixar `ok_jarbas_android.ppn`
- [ ] Baixar `porcupine_params_pt.pv` (modelo de idioma) do repositório do
      Porcupine
- [ ] Colocar os dois arquivos em `assets/porcupine/` (ver README nessa
      pasta)
- [ ] Adicionar as duas entradas em `flutter: assets:` no `pubspec.yaml`
- [ ] Preencher o AccessKey na tela de Configurações do app
- [ ] Rodar o teste manual completo de `teste_04.md` (detecção, ciclos
      repetidos, timeout de silêncio, consumo de bateria)

## Dependências

Depende de `02-integracao-home-assistant` (`HaService`) e
`03-interface-modo-sob-demanda` (mesmo `speech_to_text`, botão/indicador na
`home_screen.dart`). Fornece a base para a validação final em
`05-testes-e-distribuicao`.
