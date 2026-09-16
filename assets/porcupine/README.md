# Wake word "OK Jarbas"

Arquivos gerados no [Picovoice Console](https://console.picovoice.ai/) (idioma
Portuguese, frase "OK Jarbas", plataforma Android) devem ser colocados aqui:

- `ok_jarbas_android.ppn` — modelo da wake word customizada
- `porcupine_params_pt.pv` — modelo de idioma português (necessário pra
  qualquer wake word não-inglesa; baixar de
  https://github.com/Picovoice/porcupine/tree/master/lib/common)

Depois de colocar os dois arquivos aqui, adicionar em `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/porcupine/ok_jarbas_android.ppn
    - assets/porcupine/porcupine_params_pt.pv
```

Sem esses arquivos, `JarbasService` falha ao iniciar de forma controlada
(RF-16/critério de aceite da spec `04`) — o Modo Jarbas não ativa
silenciosamente, mostra mensagem de erro.

Esta pasta e este README não são segredo (não tem dado sensível, só nomes de
arquivo esperados) — ao contrário de `secrets/`, pode ficar versionada. Os
`.ppn`/`.pv` em si também não são segredo por natureza, mas só devem ser
adicionados aqui quando existirem de verdade.
