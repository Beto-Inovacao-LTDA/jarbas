# Tasks — Modo Jarbas (Wake Word e Serviço)

## Wake word

- [ ] 7.1 Criar conta/AccessKey na Picovoice, treinar wake word "Jarbas"
- [ ] 7.2 Validar taxa de detecção/falso-positivo da wake word treinada
      (decisão em aberto — só prosseguir após validar)
- [ ] 7.3 Integrar `porcupine_flutter` em `jarbas_service.dart`
- [ ] 7.4 Implementar callback de wake-word-detectada expondo evento para
      a UI/orquestração

## Foreground service

- [ ] 8.1 Declarar `foregroundServiceType="microphone"` no manifest
- [ ] 8.2 Integrar `flutter_foreground_task`, criar notificação persistente
- [ ] 8.3 Implementar start/stop do serviço a partir dos botões
      "Ativar"/"Desativar Modo Jarbas" (RF-15, RF-19)

## Orquestração do fluxo completo

- [ ] 9.1 Ao detectar wake word: feedback sonoro/visual (RF-17)
- [ ] 9.2 Acionar `speech_to_text` para captura da frase seguinte
- [ ] 9.3 Timeout de silêncio configurável (padrão 5s) para evitar espera
      indefinida
- [ ] 9.4 Enviar comando capturado via `HaService.sendCommand()` (RF-18)
- [ ] 9.5 Retornar ao estado de escuta da wake word após o envio
- [ ] 9.6 Indicador visual de estado ativo/inativo na tela principal
      (RF-20)

## Dependências

Depende de `02-integracao-home-assistant` (`HaService`) e
`03-interface-modo-sob-demanda` (mesmo `speech_to_text`, botão/indicador na
`home_screen.dart`). Fornece a base para a validação final em
`05-testes-e-distribuicao`.
