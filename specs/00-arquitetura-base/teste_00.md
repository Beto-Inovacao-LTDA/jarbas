# Testes — Arquitetura Base

## Status

Planejado.

## Comando

```bash
flutter analyze
flutter test
```

## Escopo previsto

- `flutter doctor -v` sem erros bloqueantes.
- `flutter analyze` sem erros no projeto recém-criado.
- App compila e instala em um Android limpo (`flutter run` ou
  `flutter build apk --debug` + `adb install`).
- `network_security_config.xml` referenciado corretamente (validar via
  `flutter build apk` sem erro de manifest e inspeção manual do APK, ou
  teste manual de request HTTP cleartext a um host `*.ts.net`).

## Critério de aprovação

App abre sem crash em um Android limpo e nenhuma dependência declarada na
spec falha ao resolver (`flutter pub get` sem conflito de versões).

## Resultado

Pendente.
