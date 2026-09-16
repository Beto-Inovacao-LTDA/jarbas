# Requirements — Testes e Distribuição

**Status:** Rascunho — aguardando aprovação antes de implementar
**Depende de:** `00`, `01`, `02`, `03`, `04` (todas as specs anteriores)

## Objetivo

Validar o app de ponta a ponta nos dois aparelhos reais e distribuí-lo sem
loja de aplicativos, via `adb install`.

## Contexto do Pedido

Esta é a spec final: consolida a validação de todos os fluxos (modo sob
demanda, atalhos, Modo Jarbas, persistência, erros) e o empacotamento do
APK para os dois aparelhos (S23 Ultra e o celular dedicado).

## Requisitos cobertos

- RNF-04: App funcional sem publicação em loja — instalação via `adb
  install` ou `flutter run`.
- Critérios de aceite gerais do produto (seção 6 do `requirements.md`
  original do projeto).

## Fora do Escopo / decisões negociadas

- Publicação em loja de aplicativos.
- Autostart do Modo Jarbas ao ligar o aparelho.

## Critérios de Aceite
- [ ] App instala e abre em um Android limpo, sem erros.
- [ ] Comando de voz simples funciona ponta a ponta no modo sob demanda.
- [ ] Atalho configurado dispara o mesmo resultado sem usar o microfone.
- [ ] Modo Jarbas, ativado no aparelho dedicado, completa o fluxo completo
      sem interação manual além da fala.
- [ ] Configuração de URL/token sobrevive a reiniciar o app.
- [ ] Cenários de erro (token inválido, HA inacessível) tratados sem crash.
- [ ] APK instalado via `adb install` nos dois aparelhos, com URL/token
      configurados em cada um.
