# Requirements — Arquitetura Base

**Status:** Rascunho — aguardando aprovação antes de implementar
**Depende de:** nenhuma (spec inicial)

## Objetivo

Estabelecer o esqueleto do projeto Flutter, suas dependências e a
configuração básica de rede/permissões Android que servem de base para todas
as demais specs (`01`–`05`).

## Contexto do Pedido

O app `ha_voice_app` controla o Home Assistant por voz, em dois modos (sob
demanda e Modo Jarbas), acessando o HA via Tailscale (MagicDNS) com HTTP
puro dentro da tailnet. Aparelho principal: Samsung Galaxy S23 Ultra.
Aparelho dedicado ao Modo Jarbas: celular Android antigo, sempre na tomada.
Idioma: pt-BR. Autenticação: Long-Lived Access Token (Bearer).

## Escopo desta spec

- Ambiente de desenvolvimento (Flutter SDK, Android SDK).
- Esqueleto do projeto (`flutter create`) e dependências em `pubspec.yaml`.
- Permissões base e `network_security_config` liberando cleartext apenas
  para `*.ts.net` (Tailscale).

## Fora do Escopo / decisões negociadas

- Lógica de persistência, integração HA, UI e Modo Jarbas — cobertas pelas
  specs `01`–`04`.
- Publicação em loja de aplicativos (RNF-04: instalação via `adb install`
  ou `flutter run`).

## Critérios de Aceite
- [ ] `flutter doctor -v` sem erros bloqueantes.
- [ ] Projeto `ha_voice_app` compila e abre em um Android limpo
      (`flutter run`), ainda com a tela padrão do `flutter create`.
- [ ] `pubspec.yaml` declara todas as dependências da seção 4 do
      `design.md` desta spec.
- [ ] `AndroidManifest.xml` declara as permissões base e referencia o
      `network_security_config`.
- [ ] Tráfego HTTP cleartext só é aceito para `*.ts.net` (RNF-03).
