# Requirements — Dados e Persistência

**Status:** Rascunho — aguardando aprovação antes de implementar
**Depende de:** `00-arquitetura-base`

## Objetivo

Persistir localmente a URL do Home Assistant, o token de acesso e a lista
de atalhos, sobrevivendo a fechar/abrir o app.

## Contexto do Pedido

Tanto a tela de configurações quanto a tela principal (specs `02` e `03`)
precisam ler/gravar URL, token e atalhos. Esta spec centraliza esse modelo
e a camada de persistência para evitar duplicação.

## Requisitos cobertos

- RF-05: Atalhos padrão na primeira execução: "Acender luzes", "Apagar
  luzes", "Trancar tudo" (editáveis pelo usuário).
- RF-11: Gerenciamento de atalhos: adicionar (nome + frase) e remover
  (modelo de dados; a UI fica na spec `03`).
- RF-21: URL do HA, token e lista de atalhos persistidos localmente.

## Fora do Escopo / decisões negociadas

- Criptografia adicional do token além da persistência local padrão
  (fora de escopo geral do produto).
- UI de configurações e CRUD visual de atalhos — spec `03`.
- Chamadas HTTP ao HA — spec `02`.

## Critérios de Aceite
- [ ] Modelo `Shortcut` serializa/desserializa corretamente (`toJson`/`fromJson`).
- [ ] `SettingsStore` lê e grava URL, token e atalhos via `SharedPreferences`.
- [ ] Na primeira execução (sem dados salvos), a lista de atalhos vem
      preenchida com os 3 padrões de RF-05.
- [ ] Configuração de URL/token/atalhos sobrevive a fechar e reabrir o app.
