# Tasks — Interface do Modo Sob Demanda

## Tela de configurações

- [ ] 4.1 Campos de URL e token (RF-07, RF-08)
- [ ] 4.2 Botão "Testar conexão" (RF-09)
- [ ] 4.3 Botão "Salvar" (RF-10)
- [ ] 4.4 CRUD de atalhos na UI (RF-11)

## Tela principal (modo sob demanda)

- [ ] 5.1 Botão de microfone com estados visuais (RF-01)
- [ ] 5.2 Integração com `speech_to_text`, captura e envio automático ao
      final da fala (RF-02)
- [ ] 5.3 Exibição de texto reconhecido e status (RF-03)
- [ ] 5.4 Grade de atalhos rápidos (RF-04, RF-05)
- [ ] 5.5 Navegação para a tela de configurações (RF-06)

## Dependências

Depende de `01-dados-e-persistencia` e `02-integracao-home-assistant`.
Fornece a tela principal onde `04-modo-jarbas-wake-word-e-servico` adiciona
o botão e o indicador do Modo Jarbas.
