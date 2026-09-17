# vosk_flutter_service (spec 04 - wake word) usa JNA para acessar a lib
# nativa do Vosk; exigido pelo README do pacote caso o shrinking (R8) seja
# habilitado no futuro (hoje minifyEnabled não está ativo neste projeto).
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
