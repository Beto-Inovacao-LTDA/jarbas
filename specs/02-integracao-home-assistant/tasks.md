# Tasks — Integração com o Home Assistant

- [ ] 3.1 Implementar `HaService.sendCommand()` (RF-12, RF-13)
- [ ] 3.2 Implementar `HaService.testConnection()`
- [ ] 3.3 Implementar tratamento de erros (RF-14): 401, timeout, falha de
      conexão, resposta inesperada

## Dependências

Depende de `00-arquitetura-base` (pacote `http`) e `01-dados-e-persistencia`
(URL/token vêm do `SettingsStore`). Fornece a base para
`03-interface-modo-sob-demanda` e `04-modo-jarbas-wake-word-e-servico`.
