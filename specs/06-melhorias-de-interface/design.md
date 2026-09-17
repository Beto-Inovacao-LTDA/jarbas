# Design — Melhorias de Interface

## Visão geral da solução

Três mudanças independentes de UI/UX, todas dentro de arquivos já
existentes (sem novos módulos):

1. `AppBarTheme` global em `main.dart` — aplica cor de fundo e cor de
   texto/ícone a todas as `AppBar`s do app (`home_screen.dart`,
   `settings_screen.dart`), sem precisar customizar cada tela
   individualmente.
2. `lib/jarbas_service.dart` — estender `_emitWakeWordFeedback()` (spec
   `04`) pra tocar um beep, além de vibrar.
3. `lib/home_screen.dart` — trocar os `OutlinedButton` circulares do grid
   de atalhos por um `GridView.builder` com células de altura fixa e um
   widget de atalho customizado (caixa arredondada colorida).

## Módulos afetados

- `lib/main.dart` — tema global (`AppBarTheme`).
- `lib/home_screen.dart` — grid de atalhos.
- `lib/jarbas_service.dart` — feedback de wake word (beep).
- `pubspec.yaml` — nova dependência de áudio + novo asset (ver "Beep de
  wake word").
- `test/home_screen_test.dart` — o `Key('shortcut_${s.label}')` é
  preservado, mas o tipo do widget muda de `OutlinedButton` pra um widget
  customizado; conferir que os finders continuam funcionando.

## Barra superior colorida (RF-22)

Em `main.dart`, adicionar ao `ThemeData`:

```dart
final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
ThemeData(
  colorScheme: colorScheme,
  appBarTheme: AppBarTheme(
    backgroundColor: colorScheme.primary,
    foregroundColor: Colors.white,
  ),
)
```

Isso cobre título, ícones de ação (`settings_button`) e a seta de voltar em
todas as telas com `AppBar` — hoje `home_screen.dart` e
`settings_screen.dart` — sem duplicar a configuração em cada uma.

## Beep de wake word (RF-23)

Mesma armadilha já resolvida na spec `04`: o feedback roda dentro do
`JarbasTaskHandler`, numa isolate de segundo plano sem `Activity` —
`SystemSound.play()` não funciona nesse contexto (motivo pelo qual a
vibração já foi trocada pelo pacote `vibration`, ver `04/design.md`). Um
tocador de áudio baseado em `MediaPlayer`/`ExoPlayer` (não em
`SystemChannels.platform`) funciona nesse contexto do mesmo jeito que o
`vibration` funcionou — plugins Flutter registrados via
`GeneratedPluginRegistrant` ficam disponíveis na isolate de segundo plano
do `flutter_foreground_task` (confirmado na prática com o `vibration`).

Pacote proposto: [`audioplayers`](https://pub.dev/packages/audioplayers)
(`^6.8.1`) — checado antes de propor pra evitar o mesmo tipo de conflito de
dependência que já aconteceu 2x com pacotes de wake word: `compileSdk 36`,
`minSdkVersion 19`, `http: >=0.13.1 <2.0.0` (compatível com as versões já
travadas pela migração da spec `04`, sem conflito esperado). Toca um asset
de áudio local curto.

Precisa de um asset de beep: gerar um tom curto sintetizado (ex.:
`assets/sounds/wake_beep.wav`, ~150-200ms, seno simples, gerado por script
em tempo de implementação) — mesmo espírito de como o ícone do app foi
gerado programaticamente (via script, não arquivo externo baixado).

`_emitWakeWordFeedback()` em `jarbas_service.dart` passa a disparar
vibração e beep em paralelo, cada um com seu próprio `try/catch` — a falha
de um não deve impedir o outro.

### Bug encontrado na validação: `AudioPlayer()` como inicializador de campo

A primeira versão declarava `final AudioPlayer _beepPlayer = AudioPlayer();`
como campo da classe `JarbasTaskHandler`. Isso roda no instante em que
`JarbasTaskHandler()` é construído dentro de `startJarbasTaskCallback()` —
**antes** da isolate de segundo plano terminar de inicializar os bindings
do Flutter. O construtor de `AudioPlayer` acessa `GlobalAudioScope`, que por
sua vez chama um `MethodChannel`, e lançava `Unhandled Exception: Binding
has not yet been initialized` (visível em `adb logcat`, tag `flutter`). O
`try/catch` de `_playBeep()` engolia o efeito colateral (o player ficava
"quebrado" silenciosamente) e o beep simplesmente nunca tocava — sem
nenhum erro visível pro usuário nem crash.

Mesma classe de armadilha do feedback tátil (spec `04`): qualquer plugin
que precise de binding do Flutter só pode ser inicializado depois que o
ciclo de vida da task começa (dentro de `onStart()`), nunca como
inicializador de campo. Diferença chave com o `vibration`: `Vibration.
hasVibrator()`/`vibrate()` só são chamados de dentro do fluxo assíncrono
disparado por `onStart()`, nunca na construção do objeto — por isso
funcionaram de primeira.

**Fix:** campo trocado pra `AudioPlayer? _beepPlayer` (nulo até então) e a
instância criada como a primeira linha de `onStart()`, antes de qualquer
outra coisa.

## Atalhos como caixas arredondadas (RF-24)

Troca em `home_screen.dart`:

- Remove o `GridView.count(crossAxisCount: 2, ...)` de `OutlinedButton`.
- Usa `GridView.builder` com
  `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
  crossAxisSpacing: 8, mainAxisSpacing: 8, mainAxisExtent: <altura fixa,
  ex. 56-64>)` — altura fixa por célula (em vez de esticar pra caber a
  área disponível) é o que faz a grade ficar compacta e rolar quando há
  mais itens, em vez de redimensionar os botões pra preencher o espaço
  (causa do problema atual, onde poucos atalhos ficam gigantes).
- Cada atalho vira um widget próprio (`Material` + `InkWell` + `Container`
  com `BoxDecoration(color: colorScheme.primary, borderRadius:
  BorderRadius.circular(12))`, `Text` branco centralizado, `Key`
  `shortcut_${s.label}` preservada pros testes).
- Mantém `Expanded` em volta do `GridView.builder` pra limitar a área
  rolável ao espaço restante da tela.

## Decisões Técnicas

- Cor do tema aplicada via `AppBarTheme` global (não hardcoded em cada
  `AppBar`) — fonte única de verdade, mais fácil de ajustar depois.
- Altura fixa de célula do grid de atalhos (`mainAxisExtent`) escolhida em
  vez de `childAspectRatio`, pra garantir tamanho consistente independente
  da largura/altura da tela.
- Beep gerado por script (sem depender de asset externo/licenciado).

## Riscos e mitigação

- **Pacote de áudio pode ter conflito de dependência transitiva** (como já
  aconteceu 2x com pacotes de wake word na spec `04`) — mitigado
  verificando `compileSdk`/`minSdk`/`environment.sdk` do `audioplayers`
  antes de codar (já feito, ver acima); se `flutter pub get` mesmo assim
  falhar, plano B é um pacote de áudio alternativo mais simples ou um
  `MethodChannel` próprio pra `ToneGenerator` nativo.
- **Beep pode não tocar em isolate de segundo plano** por algum motivo não
  previsto (mesma classe de risco do feedback tátil na spec `04`) —
  mitigado testando no aparelho real antes de considerar a task concluída,
  com o mesmo processo de diagnóstico via `adb logcat` já validado nessa
  spec.
- **Alterar o widget dos atalhos pode quebrar os testes de widget
  existentes** — mitigado preservando as mesmas `Key`s
  (`shortcut_${label}`), rodando `flutter test` antes de considerar a spec
  concluída.

## Riscos legados e mitigação

Não aplicável (mudanças isoladas em telas/serviços já existentes, sem
código legado nesta camada).
