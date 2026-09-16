# Tasks — Testes e Distribuição

## Testes e validação

- [ ] 10.1 Testar fluxo completo do modo sob demanda ponta a ponta (mic →
      HA → resposta exibida)
- [ ] 10.2 Testar cada atalho configurado
- [ ] 10.3 Testar Modo Jarbas no aparelho dedicado: detecção da wake word,
      captura do comando, envio, retorno ao estado de escuta
- [ ] 10.4 Testar persistência: fechar e reabrir o app, configurações e
      atalhos devem continuar salvos
- [ ] 10.5 Testar cenários de erro: token inválido, Home Assistant
      inacessível (Tailscale desconectado)
- [ ] 10.6 Validar consumo de bateria do Modo Jarbas em repouso por um
      período prolongado (ex: algumas horas) no aparelho dedicado

## Build e distribuição

- [ ] 11.1 `flutter build apk --release`
- [ ] 11.2 Instalar via `adb install` nos dois aparelhos (principal e
      dedicado ao Modo Jarbas)
- [ ] 11.3 Configurar URL/token em cada aparelho
- [ ] 11.4 Orientar desativação de otimização de bateria no aparelho
      dedicado ao Modo Jarbas

## Dependências

Depende de todas as specs anteriores (`00`–`04`) estarem implementadas e
com seus próprios testes aprovados.
