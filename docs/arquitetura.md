# Arquitetura — ha_voice_app (Jarbas)

## Estado atual

Specs `00`–`04` e `06` implementadas e validadas de ponta a ponta no Note 9
— incluindo a migração do motor de wake word de Picovoice/Porcupine pra
Vosk (offline, sem gatekeeping de conta) e uma rodada de melhorias visuais
(spec `06`). Spec `05` (testes e distribuição) ainda não iniciada.

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
| Entry point | `lib/main.dart` | Tema (`AppBarTheme` na cor do app), inicialização do `MaterialApp` e da porta de comunicação do foreground task | 00, 06 |
| Persistência | `lib/settings_store.dart` | `Shortcut` + `SettingsStore` sobre `SharedPreferences` (URL, token, atalhos, autostart) | 01 |
| Integração HA | `lib/ha_service.dart` | `HaService.sendCommand`/`testConnection`, exceções tipadas | 02 |
| UI principal | `lib/home_screen.dart` | Microfone, grade de atalhos (caixas arredondadas), indicador/switch do Modo Jarbas, navegação | 03, 06 |
| UI configurações | `lib/settings_screen.dart` | URL, token, CRUD de atalhos | 03 |
| Wake word + orquestração | `lib/jarbas_service.dart` | `JarbasTaskHandler`: ciclo de vida do motor de wake word (Vosk), captura pós-wake-word, envio ao HA, roda dentro do foreground service | 04, 06 |

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
- Wake word 100% offline via Vosk (`vosk_flutter_service`), rodando dentro
  de um foreground service (`flutter_foreground_task`) com isolate própria
  — necessário pra sobreviver com a tela apagada/app em segundo plano.
  Migrado de Picovoice/Porcupine em 2026-09-17 porque a conta na Picovoice
  ficou presa em revisão manual de "caso de uso comercial" sem previsão de
  liberação — Vosk não exige conta/API key. Ver
  `specs/04-modo-jarbas-wake-word-e-servico/design.md`.
- Inicialização preguiçosa do `speech_to_text` no modo sob demanda (só no
  primeiro toque do microfone) — evita pedir permissão antes da hora e
  simplifica testes de widget que não tocam no microfone.
- Qualquer chamada de rede que atualiza estado de UI precisa de um `catch`
  genérico como rede de segurança, além dos tipos esperados — lição de um
  bug real encontrado em teste manual (ver `specs/03.../teste_03.md`): um
  `catch` específico demais deixou passar um `ArgumentError` de URL
  inválida e travou a UI com o spinner girando pra sempre, sem crash nem
  mensagem. Esse princípio guiou também o `JarbasTaskHandler`: qualquer
  falha ao iniciar o motor de wake word desliga o próprio serviço e
  notifica a UI, nunca fica "pendurado".
- **Plugins que dependem de bindings do Flutter só podem ser
  inicializados depois que o ciclo de vida da task de segundo plano
  começa** (dentro de `onStart()`), nunca como inicializador de campo de
  classe nem antes disso — `HapticFeedback`/`SystemSound` (API padrão) não
  funcionam de jeito nenhum numa isolate sem `Activity` (silenciosamente),
  e um `AudioPlayer()` criado cedo demais lançava uma exceção engolida por
  um `try/catch` de best-effort. Ver `specs/06-melhorias-de-interface/
  design.md`.
- **Nunca reiniciar o mesmo `AudioRecord` nativo (Vosk) depois que outro
  app usou o microfone** — a lib nativa lança uma exceção não capturável
  do lado Dart nesse cenário, derrubando o processo inteiro. O
  `JarbasTaskHandler` sempre descarta e recria o `SpeechService` a cada
  ciclo de captura, em vez de reiniciar o antigo. Ver
  `specs/04-modo-jarbas-wake-word-e-servico/design.md`.
- Sem publicação em loja — distribuição via `adb install` (spec `05`).

## Riscos e mitigação

| Risco | Status / Mitigação |
|---|---|
| Falso-positivo/negativo da wake word "OK Jarbas" (Vosk) | Validado em uso normal de sala no Note 9 — detectada corretamente em múltiplos ciclos seguidos. Taxa de falso-positivo em uso prolongado (ruído de fundo constante) ainda não medida. |
| Consumo de bateria do foreground service 24/7 | Pendente de validação prolongada no Note 9 (spec `05`) |
| Compatibilidade do Android antigo com `vosk_flutter_service`/`flutter_foreground_task` | Build e instalação confirmados no Note 9 (Android 10, API 29) — `minSdkVersion 21` do `vosk_flutter_service` é compatível |
| Crash do `SpeechService` nativo do Vosk (`AudioRecord`) ao reiniciar após uso concorrente do microfone | Corrigido — ver "Decisões técnicas centrais" acima e `specs/04.../design.md` |

## Índice das specs

Ver `specs/README.md` para a ordem de execução, o padrão de cada spec e o
gate de aprovação.
