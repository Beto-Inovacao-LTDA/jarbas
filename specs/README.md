# Specs — ha_voice_app (Comando de Voz HA / Jarbas)

Este diretório organiza a implementação do zero do `ha_voice_app` seguindo
**Spec-Driven Development (SDD)**, mesmo padrão usado nos projetos
`Corpus-Shaped` e `simulador-gas`.

## Ordem de execução

1. `00-arquitetura-base`
2. `01-dados-e-persistencia`
3. `02-integracao-home-assistant`
4. `03-interface-modo-sob-demanda`
5. `04-modo-jarbas-wake-word-e-servico`
6. `05-testes-e-distribuicao`

Ordem por dependência funcional: `00` estabelece esqueleto/config Android;
`01` e `02` são a camada de dados/integração usada por toda a UI; `03`
entrega o modo sob demanda (usa `01`+`02`); `04` entrega o Modo Jarbas
(reaproveita o fluxo de voz e o `HaService` de `03`/`02`); `05` valida e
empacota tudo.

## Padrão de cada spec

Cada pasta `NN-nome/` contém:

- `requirements.md` — objetivo, contexto, requisitos funcionais/não-funcionais
  cobertos, fora de escopo e critérios de aceite;
- `design.md` — visão da solução, módulos/arquivos, fluxo, decisões técnicas
  e riscos com mitigação;
- `tasks.md` — checklist de tarefas da etapa e dependências;
- `teste_0N.md` — plano/registro dos testes da etapa, usando o índice da
  pasta.

## Gate de aprovação da spec

Antes de qualquer implementação, cada spec precisa passar por este gate.

### Checklist obrigatório

#### 1. Alcance e objetivo
- [ ] O objetivo da funcionalidade está claro.
- [ ] O problema real a ser resolvido está identificado.
- [ ] O impacto para o usuário final está descrito.

#### 2. Risco técnico
- [ ] Os módulos afetados foram listados.
- [ ] Dependências de outras specs/pacotes externos foram identificadas.
- [ ] Os riscos de implementação foram descritos.

#### 3. Mitigação
- [ ] Existe plano de mitigação para os principais riscos.
- [ ] Há critérios para validação parcial antes de seguir para a próxima spec.

#### 4. Impacto operacional
- [ ] Os passos de execução e dependências foram documentados.
- [ ] Há indicação clara de permissões, dados e integrações envolvidas.
- [ ] O processo de validação (comando de teste) foi definido.

#### 5. Critérios de aceite
- [ ] A entrega pode ser testada objetivamente.
- [ ] Os resultados esperados são verificáveis.
- [ ] A implementação fica pronta para revisão sem suposições ocultas.

### Regra de aprovação

A spec só pode seguir para execução quando todos os itens obrigatórios forem
atendidos, os riscos principais estiverem documentados, a mitigação tiver
sido descrita antes da implementação e os critérios de aceite forem
verificáveis. Se algum item crítico falhar, a spec retorna para revisão.

> Status atual: **todas as specs (00–05) estão em rascunho, aguardando
> aprovação explícita antes do início da Fase 00.**

## Versionamento e ramificação

Este diretório (`/home/beto/projetos/mobile-dev/Jarbas`) ainda não é um
repositório git. Recomendação:

- rodar `git init` antes de iniciar a implementação da spec `00`;
- um commit (ou branch) por spec concluída, referenciando o número da spec;
- registrar riscos e mitigação no corpo do commit/PR quando o projeto ganhar
  um remoto.
