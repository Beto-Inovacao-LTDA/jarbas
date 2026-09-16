# Arquitetura — ha_voice_app (Jarbas)

## Estado atual

Specs `00`–`04` implementadas e validadas no Note 9 (spec `04` com uma
ressalva: bloqueada pra validação final da detecção real de wake word — ver
seção "Riscos e mitigação" e `specs/04-modo-jarbas-wake-word-e-servico/
teste_04.md`). Spec `05` (testes e distribuição) ainda não iniciada.

Este documento descreve a arquitetura **como implementada**, não mais um
alvo planejado. Para uma visão geral rápida + instruções de setup, ver o
`README.md` na raiz do projeto.

## Visão arquitetural

```
┌───────────────────────────┐        ┌───────────────────────────┐
│   Modo sob demanda         │        │   Modo Jarbas               │
│   (toque no microfone)     │        │   (wake word contínua)      │
│   isolate principal (UI)   │        │   isolate separada          │
│                            │        │   (flutter_foreground_task) │
└──────────────┬─────────────┘        └──────────────┬─────────────┘
               │                                       │
               │ texto reconhecido                     │ wake word detectada
               │                                       │  → aciona captura
               ▼                                       ▼
        ┌──────────────────────────────────────────────────┐
        │      speech_to_text (mesma classe, instâncias        │
        │      separadas por isolate — sem estado global)      │
        └──────────────────────┬───────────────────────────┘
                                │ texto final
                                ▼
                        ┌───────────────┐
                        │   HaService    │  (instância própria por isolate)
                        └───────┬───────┘
                                │ HTTP + Bearer token
                                ▼
                ┌───────────────────────────────┐
                │         Home Assistant          │
                │ /api/conversation/process       │
                └───────────────────────────────┘
```

Os dois modos convergem no mesmo código de `speech_to_text` e `HaService`,
mas **cada isolate instancia as suas próprias cópias** — não há
compartilhamento de objetos entre a isolate da UI e a isolate do Modo
Jarbas. A comunicação entre elas é só por mensagens primitivas
(`FlutterForegroundTask.sendDataToMain`/`sendDataToTask`), gerenciadas pelo
plugin `flutter_foreground_task`.

## Componentes e responsabilidades

| Componente | Arquivo | Responsabilidade | Spec |
|---|---|---|---|
| Entry point | `lib/main.dart` | Tema, inicialização do `MaterialApp` e da porta de comunicação do foreground task | 00 |
| Persistência | `lib/settings_store.dart` | `Shortcut` + `SettingsStore` sobre `SharedPreferences` (URL, token, atalhos, AccessKey Picovoice, autostart) | 01 |
| Integração HA | `lib/ha_service.dart` | `HaService.sendCommand`/`testConnection`, exceções tipadas | 02 |
| UI principal | `lib/home_screen.dart` | Microfone, atalhos, indicador/switch do Modo Jarbas, navegação | 03 |
| UI configurações | `lib/settings_screen.dart` | URL, token, AccessKey, CRUD de atalhos | 03 |
| Wake word + orquestração | `lib/jarbas_service.dart` | `JarbasTaskHandler`: ciclo de vida do Porcupine, captura pós-wake-word, envio ao HA, roda dentro do foreground service | 04 |

## Contexto de ambiente do usuário

- Home Assistant acessado principalmente pela **rede local** (IP dinâmico
  via DHCP) e também via **Tailscale** (MagicDNS) quando fora de casa —
  HTTP puro nos dois casos (na tailnet já vem criptografado pelo
  WireGuard).
- Aparelho principal: Samsung Galaxy S23 Ultra.
- Aparelho dedicado ao Modo Jarbas: Samsung Galaxy Note 9 (Android 10),
  sempre na tomada, sobre a mesa da sala. Sem Tailscale instalado —
  alcança o HA só pela rede local.
- Idioma: pt-BR. Autenticação: Long-Lived Access Token (Bearer).

## Decisões técnicas centrais

- Cleartext HTTP liberado globalmente (`network_security_config.xml`,
  `base-config cleartextTrafficPermitted="true"`) — o IP do HA muda por
  DHCP e Android não aceita CIDR/IP dinâmico num `domain-config`
  restrito.
- Sem interpretação própria de comando — delega 100% ao Assist do HA
  (spec `02`, RF-13). Qualquer ajuste de "não encontrei o dispositivo X" é
  problema de nomenclatura/alias no HA, não do app (validado na prática:
  nomes de entidade com `_` não são reconhecíveis por voz, porque a fala
  nunca produz o underscore).
- Wake word 100% offline via Porcupine (Picovoice), rodando dentro de um
  foreground service (`flutter_foreground_task`) com isolate própria —
  necessário pra sobreviver com a tela apagada/app em segundo plano.
- Inicialização preguiçosa do `speech_to_text` no modo sob demanda (só no
  primeiro toque do microfone) — evita pedir permissão antes da hora e
  simplifica testes de widget que não tocam no microfone.
- Qualquer chamada de rede que atualiza estado de UI precisa de um `catch`
  genérico como rede de segurança, além dos tipos esperados — lição de um
  bug real encontrado em teste manual (ver `specs/03.../teste_03.md`): um
  `catch` específico demais deixou passar um `ArgumentError` de URL
  inválida e travou a UI com o spinner girando pra sempre, sem crash nem
  mensagem. Esse princípio guiou também o `JarbasTaskHandler`: qualquer
  falha ao iniciar o Porcupine desliga o próprio serviço e notifica a UI,
  nunca fica "pendurado".
- Sem publicação em loja — distribuição via `adb install` (spec `05`).

## Riscos e mitigação

| Risco | Status / Mitigação |
|---|---|
| Falso-positivo/negativo da wake word customizada "OK Jarbas" | **Ainda não validado** — bloqueado pela revisão de conta da Picovoice (ver abaixo). Fallback pesquisado: `open_wake_word` (openWakeWord via ONNX Runtime), sem gatekeeping de conta. |
| Consumo de bateria do foreground service 24/7 | Pendente de validação prolongada no Note 9 (spec `04`/`05`) |
| Compatibilidade do Android antigo com `porcupine_flutter`/`flutter_foreground_task` | Build e instalação confirmados no Note 9 (Android 10); conflito de `compileSdkVersion` entre os dois plugins resolvido via patch no `android/build.gradle.kts` |
| **Conta Picovoice em revisão manual** ("caso de uso comercial"), sem AccessKey liberado | Bloqueio ativo desde 2026-09-16, sem previsão. Código do Modo Jarbas está pronto e validado no cenário de falha controlada (sem AccessKey, o serviço se autodesliga e notifica o usuário — não fica "ativo" sem detecção de verdade). Ver `specs/04-modo-jarbas-wake-word-e-servico/teste_04.md` |

## Índice das specs

Ver `specs/README.md` para a ordem de execução, o padrão de cada spec e o
gate de aprovação.
