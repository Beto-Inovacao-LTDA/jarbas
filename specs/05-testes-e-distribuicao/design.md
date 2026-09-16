# Design — Testes e Distribuição

## Visão geral da solução

Nenhum módulo novo. Esta spec só consolida a validação manual/automatizada
do que as specs `00`–`04` entregaram, e o processo de build/instalação nos
dois aparelhos.

## Fluxo de validação

1. Rodar as suítes automatizadas de todas as specs anteriores
   (`teste_00`–`teste_04`).
2. Testar o fluxo completo do modo sob demanda ponta a ponta (mic → HA →
   resposta exibida) no S23 Ultra.
3. Testar cada atalho configurado.
4. Testar Modo Jarbas no aparelho dedicado: detecção da wake word, captura
   do comando, envio, retorno ao estado de escuta.
5. Testar persistência: fechar e reabrir o app, configurações e atalhos
   devem continuar salvos.
6. Testar cenários de erro: token inválido, Home Assistant inacessível
   (Tailscale desconectado).
7. Validar consumo de bateria do Modo Jarbas em repouso por um período
   prolongado no aparelho dedicado.

## Build e distribuição

1. `flutter build apk --release`.
2. Instalar via `adb install` nos dois aparelhos (principal e dedicado ao
   Modo Jarbas).
3. Configurar URL/token em cada aparelho.
4. Orientar desativação de otimização de bateria no aparelho dedicado ao
   Modo Jarbas (necessário para o foreground service sobreviver 24/7).

## Decisões Técnicas

- Sem CI/pipeline automatizado no MVP — build e instalação manuais via
  `adb`, coerente com RNF-04 (sem publicação em loja).

## Riscos / pontos em aberto

- Nenhum novo além dos já registrados nas specs `00`–`04`.
