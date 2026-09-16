allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// porcupine_flutter e sua dependência flutter_voice_processor (spec 04 -
// wake word) são publicados com compileSdkVersion 31, incompatível com o
// AndroidX moderno exigido por flutter_foreground_task (o AGP recusa a
// build por metadado de AAR incompatível). Não é possível sobrescrever isso
// de fora via DSL porque o AGP já trava o valor quando a variante é criada,
// então corrigimos o arquivo dos pacotes (só metadado, sem efeito no código
// compilado) antes que o Gradle os avalie. Precisa rodar de novo se o pub
// cache for limpo/reparado - por isso reaplicamos aqui a cada build.
val flutterPluginsFile = rootProject.projectDir.parentFile.resolve(".flutter-plugins-dependencies")
if (flutterPluginsFile.exists()) {
    val pluginsWithLowCompileSdk = listOf("flutter_voice_processor", "porcupine_flutter")
    val json = flutterPluginsFile.readText()
    pluginsWithLowCompileSdk.forEach { pluginName ->
        val match = Regex(""""name":"$pluginName","path":"([^"]+)"""").find(json)
        if (match != null) {
            val pluginBuildGradle = file(match.groupValues[1]).resolve("android/build.gradle")
            if (pluginBuildGradle.exists()) {
                val content = pluginBuildGradle.readText()
                val patched = content.replace(Regex("""compileSdkVersion\s+31"""), "compileSdkVersion 36")
                if (patched != content) {
                    pluginBuildGradle.writeText(patched)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
