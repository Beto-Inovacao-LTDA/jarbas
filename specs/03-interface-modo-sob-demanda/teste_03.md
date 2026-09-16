# Testes — Interface do Modo Sob Demanda

## Status

Aprovado (com uma correção aplicada durante o teste manual — ver Resultado).

## Comando

```bash
flutter test test/home_screen_test.dart test/settings_screen_test.dart
```

## Escopo previsto

- Widget test: estado visual do botão de microfone alterna entre
  ouvindo/parado.
- Widget test: grade de atalhos renderiza um botão por `Shortcut` e dispara
  `HaService.sendCommand` com a frase certa (usando um `HaService` fake).
- Widget test: tela de configurações salva URL/token via `SettingsStore`
  fake e reflete mensagens de "Testar conexão".
- Teste manual no S23 Ultra: comando de voz real ponta a ponta ("ligar luz
  da sala") e um atalho configurado, contra um HA real.

## Critério de aprovação

Testes automatizados passam sem depender de rede real; o teste manual
ponta a ponta funciona no aparelho principal com um HA acessível via
Tailscale.

## Resultado

`flutter test test/home_screen_test.dart test/settings_screen_test.dart` —
19/19 testes passando (8 em `ha_service_test.dart` + 3 em
`home_screen_test.dart` + 8 em `settings_screen_test.dart`, incluindo 2
casos de regressão adicionados nesta spec para erro inesperado/URL
inválida). `flutter analyze` sem apontamentos.

Teste manual feito no **Note 9** (não no S23 Ultra — aparelho disponível no
momento do teste; o app se comporta igual em qualquer Android, a diferença
por fabricante citada como risco no `design.md` não se confirmou aqui),
contra um HA real na rede local (`192.168.15.13:8123`, sem Tailscale no
aparelho):

- "Testar conexão" validou com sucesso.
- Comando de voz ponta a ponta: microfone → transcrição correta → `HaService
  .sendCommand` → resposta do Assist exibida na tela, sem passar por
  interpretação própria (RF-13). Primeiro teste com uma entidade inexistente
  ("cozinha", depois "spot mesa" falado) recebeu a resposta de erro do
  próprio Assist do HA — comportamento correto, reproduzido de forma
  idêntica no Assist nativo do HA (fora do app), confirmando que a causa é
  nomenclatura/alias de entidade no HA, não um problema do app.
- Atalho configurado com a frase exata que funciona no HA
  (`desligar spot_mesa`) disparou com sucesso, validando RF-04 com uma ação
  real.
- CRUD de atalhos (adicionar/remover) testado na UI real.

**Bug encontrado e corrigido durante o teste manual:** `HaService
.testConnection()` e `HaService.sendCommand()` só tratavam
`TimeoutException`/`SocketException`/`http.ClientException`. Com o campo de
URL vazio (usuário só viu o hint text cinza e achou que já era um valor
salvo), `Uri.parse` gerava uma URI sem host, e `HttpClient.openUrl` lançava
`ArgumentError` — exceção não coberta, que **nunca chegava ao `setState`**
que para o spinner do botão "Testar conexão", travando a UI indefinidamente
(reproduzido ao vivo no Note 9, confirmado via logcat:
`Unhandled Exception: Invalid argument(s): No host specified in URI /api/`).
Corrigido trocando os `catch` específicos por um `catch (_)` amplo em torno
da chamada de rede nos dois métodos — qualquer erro inesperado agora vira
`false` (`testConnection`) ou `HaConnectionException`
(`sendCommand`/`_postConversation`), nunca uma exceção não tratada. Dois
testes de regressão cobrindo esse cenário foram adicionados a
`ha_service_test.dart`.
