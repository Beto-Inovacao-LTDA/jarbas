# Tasks — Arquitetura Base

## Ambiente

- [x] 0.1 Instalar dependências de sistema (`curl`, `git`, `unzip`,
      `xz-utils`, `libglu1-mesa`)
- [x] 0.2 Instalar Flutter SDK (canal stable) e validar com
      `flutter --version`
- [x] 0.3 Instalar Android SDK / `cmdline-tools`, definir
      `ANDROID_HOME`/`ANDROID_SDK_ROOT`
- [x] 0.4 Rodar `flutter doctor --android-licenses` e `flutter doctor -v`,
      resolver todos os erros bloqueantes
- [ ] 0.5 Conectar o aparelho principal (S23 Ultra) via USB, confirmar
      `adb devices` autorizado

## Esqueleto do projeto

- [x] 1.1 `flutter create --org com.betoinovacao --project-name
      ha_voice_app ha_voice_app`
- [ ] 1.2 Configurar `pubspec.yaml` com as dependências da seção
      "Dependências" do `design.md`
- [ ] 1.3 `flutter pub get`

## Configuração de rede/permissões Android

- [ ] 6.1 Adicionar permissões base no `AndroidManifest.xml` (INTERNET,
      RECORD_AUDIO, BLUETOOTH_CONNECT, FOREGROUND_SERVICE,
      FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS)
- [ ] 6.2 Criar `network_security_config.xml` liberando cleartext para
      `*.ts.net`
- [ ] 6.3 Referenciar o `network_security_config` na tag `<application>`
- [ ] 6.4 Testar acesso HTTP ao HA via Tailscale a partir do app (ex.: uma
      chamada manual/curl a partir do dispositivo, ou um teste manual em
      `main.dart` temporário)

## Dependências

Nenhuma — esta é a spec inicial. Fornece a base para `01`, `02`, `03`, `04`
e `05`.
