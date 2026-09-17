# Tasks — Melhorias de Interface

## Barra superior colorida (RF-22)

- [x] 10.1 Adicionar `appBarTheme` em `main.dart` (fundo =
      `colorScheme.primary`, texto/ícones brancos)
- [x] 10.2 Conferir visualmente `home_screen.dart` e `settings_screen.dart`
      no aparelho real

## Beep de wake word (RF-23)

- [x] 10.3 Gerar asset de beep curto (script, sem áudio externo) em
      `assets/sounds/`
- [x] 10.4 Adicionar dependência `audioplayers` e o novo asset em
      `pubspec.yaml`
- [x] 10.5 Estender `_emitWakeWordFeedback()` em `jarbas_service.dart` pra
      tocar o beep junto com a vibração
- [x] 10.6 Validar no aparelho real (Note 9) que o beep toca de fato ao
      detectar "ok jarbas" no Modo Jarbas
- [x] 10.6.1 (não previsto no plano original) corrigir
      `AudioPlayer()` sendo criado como inicializador de campo — lançava
      "Binding has not yet been initialized" na isolate de segundo plano
      (silenciado pelo `try/catch`, beep nunca tocava); movido pra dentro
      de `onStart()`, ver `design.md`

## Atalhos como caixas arredondadas (RF-24)

- [x] 10.7 Criar widget de atalho (caixa arredondada, cor do tema, texto
      branco)
- [x] 10.8 Trocar `GridView.count` por `GridView.builder` com altura de
      célula fixa em `home_screen.dart`
- [x] 10.9 Testar com 8+ atalhos cadastrados que a grade rola corretamente
      sem cortar a tela — testado com 16, rolagem confirmada

## Validação final

- [x] 10.10 Rodar `flutter analyze`/`flutter test` sem regressões — 19/19
      passando
- [x] 10.11 Build + instalar no aparelho real, conferir visualmente as 3
      mudanças — todas confirmadas no Note 9

## Dependências

Depende de `03-interface-modo-sob-demanda` (tela principal e atalhos) e
`04-modo-jarbas-wake-word-e-servico` (feedback de wake word).
