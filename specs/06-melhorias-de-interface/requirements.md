# Requirements — Melhorias de Interface

**Status:** Implementada e validada no Note 9 em 2026-09-17. As 3 mudanças
funcionam de ponta a ponta; um bug real foi encontrado e corrigido durante
a validação (`AudioPlayer` inicializado cedo demais na isolate de segundo
plano — ver `design.md`).
**Depende de:** `03-interface-modo-sob-demanda` (tela principal e atalhos
que serão redesenhados), `04-modo-jarbas-wake-word-e-servico` (feedback de
detecção da wake word)

## Objetivo

Melhorar o acabamento visual do app e reforçar o feedback perceptível da
detecção da wake word, a partir de feedback direto do usuário depois de
validar os fluxos funcionais das specs anteriores.

## Contexto do Pedido

Com as specs `00`-`04` funcionando de ponta a ponta no aparelho real, o
usuário apontou três pontos de polimento visual/UX:

1. A barra superior (AppBar) é a padrão do Material, sem identidade visual
   com a cor do app.
2. A vibração sozinha ao detectar "OK Jarbas" (Modo Jarbas, spec `04`) pode
   passar despercebida se o aparelho dedicado estiver longe do usuário no
   cômodo.
3. Os atalhos da tela principal (spec `03`) são botões circulares grandes,
   ocupam muito espaço e limitam quantos cabem na tela sem rolagem.

## Requisitos cobertos

- RF-22: A barra superior (AppBar) do app usa a cor do tema (a mesma dos
  botões primários) como fundo, com o título e ícones em branco. Aplicado
  consistentemente nas telas principal e de Configurações.
- RF-23: Ao detectar a wake word "OK Jarbas" (Modo Jarbas, spec `04`), além
  da vibração já existente, o app emite um beep sonoro curto.
- RF-24: Os atalhos da tela principal são exibidos como caixas retangulares
  de cantos arredondados, com a cor do tema como fundo e texto branco,
  menores que o design atual — em grade de 2 colunas, com altura fixa por
  item de forma que pelo menos ~4 linhas fiquem visíveis e a lista role
  verticalmente quando houver mais atalhos.

## Fora do Escopo / decisões negociadas

- Redesenhar a lista de atalhos da tela de Configurações (CRUD) — continua
  como lista de texto simples; só a exibição na tela principal muda.
- Gravar/licenciar um som customizado para o beep — usar um tom curto
  sintetizado (sem asset de áudio externo baixado), no mesmo espírito de
  como o ícone do app foi gerado programaticamente.
- Tornar a cor do tema configurável pelo usuário — a cor continua fixa
  (`Colors.deepPurple`, já usada hoje); só muda onde ela é aplicada.

## Critérios de Aceite

- [x] Barra superior na cor do tema, com "Jarbas"/título em branco, visível
      nas telas principal e de Configurações.
- [x] Modo Jarbas ativo, ao detectar "OK Jarbas", vibra E emite um beep
      audível — confirmado pelo usuário no aparelho real.
- [x] Atalhos aparecem como caixas arredondadas coloridas com texto branco,
      em 2 colunas; com 8+ atalhos cadastrados, a grade rola verticalmente
      sem cortar a tela — testado com 16 atalhos.
- [x] Nenhuma regressão nos testes automatizados existentes (`flutter
      test`) — 19/19 passando.
