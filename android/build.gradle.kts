allprojects {
    repositories {
        google()
        mavenCentral()
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

// --- Petal: force compileSdk on all subprojects ---
// A real CI failure proved every Flutter plugin subproject (file_picker,
// flutter_plugin_android_lifecycle, etc.) resolves its OWN compileSdk
// independently of the app module's build.gradle(.kts) — patching only the
// app module left plugins on Flutter's old default (android-34) while a
// plugin dependency required 36+. This reaches into every subproject after
// it evaluates and force-sets compileSdk uniformly, app + plugins alike.
subprojects {
    pluginManager.withPlugin("com.android.application") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(36)
        }
    }

    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(36)
        }
    }
}
