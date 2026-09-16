# Arquitetura — ha_voice_app (Jarbas)

## Estado atual

Esqueleto padrão gerado por `flutter create` (só `lib/main.dart` com o
contador de exemplo), sem dependências além das defaults do template. Nenhum
componente descrito abaixo existe ainda — este documento descreve a
**arquitetura alvo**, planejada em `specs/00`–`05`.

## Visão arquitetural alvo

```
┌───────────────────────────┐        ┌───────────────────────────┐
│   Modo sob demanda         │        │   Modo Jarbas               │
│   (toque no microfone)     │        │   (wake word contínua)      │
└──────────────┬─────────────┘        └──────────────┬─────────────┘
               │                                       │
               │ texto reconhecido                     │ wake word detectada
               │                                       │  → aciona captura
               ▼                                       ▼
        ┌──────────────────────────────────────────────────┐
        │           speech_to_text (compartilhado)           │
        └──────────────────────┬───────────────────────────┘
                                │ texto final
                                ▼
                        ┌───────────────┐
                        │   HaService    │
                        └───────┬───────┘
                                │ HTTP + Bearer token
                                ▼
                ┌───────────────────────────────┐
                │ Home Assistant (via Tailscale) │
                │ /api/conversation/process       │
                └───────────────────────────────┘
```

Os dois modos convergem no mesmo `speech_to_text` e no mesmo `HaService` —
a única diferença é o que dispara a captura de voz (toque manual vs. wake
word).

## Componentes e responsabilidades

| Componente | Arquivo | Responsabilidade | Spec |
|---|---|---|---|
| Entry point | `lib/main.dart` | Tema, inicialização do `MaterialApp` | 00 |
| Persistência | `lib/settings_store.dart` | Modelo `Shortcut` + `SharedPreferences` | 01 |
| Integração HA | `lib/ha_service.dart` | Chamadas HTTP ao Home Assistant | 02 |
| UI principal | `lib/home_screen.dart` | Microfone, atalhos, indicador do Modo Jarbas | 03 |
| UI configurações | `lib/settings_screen.dart` | URL, token, CRUD de atalhos | 03 |
| Wake word + orquestração | `lib/jarbas_service.dart` | Ciclo de vida do Porcupine, coordena captura pós-wake-word | 04 |

## Contexto de ambiente do usuário

- Home Assistant acessado via **Tailscale** (MagicDNS), HTTP puro dentro da
  tailnet (já criptografado pelo WireGuard).
- Aparelho principal: Samsung Galaxy S23 Ultra.
- Aparelho dedicado ao Modo Jarbas: celular Android antigo, sempre na
  tomada, sobre a mesa da sala.
- Idioma: pt-BR. Autenticação: Long-Lived Access Token (Bearer).

## Decisões técnicas centrais

- Cleartext HTTP liberado só para `*.ts.net` via `network_security_config`
  (spec `00`).
- Sem interpretação própria de comando — delega 100% ao Assist do HA
  (spec `02`).
- Wake word 100% offline via Porcupine, rodando em foreground service
  (spec `04`).
- Sem publicação em loja — distribuição via `adb install` (spec `05`).

## Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Falso-positivo/negativo da wake word customizada "Jarbas" | Validar taxa de detecção antes de integrar (spec `04`, tarefa 7.2); ter wake word pronta da Picovoice como fallback |
| Consumo de bateria do foreground service 24/7 | Validar em teste prolongado no aparelho dedicado (spec `04`/`05`); orientar desativar otimização de bateria |
| Compatibilidade do Android antigo com `porcupine_flutter`/`flutter_foreground_task` | Validar cedo na spec `04`, antes de investir na orquestração completa |

## Índice das specs

Ver `specs/README.md` para a ordem de execução, o padrão de cada spec e o
gate de aprovação.
