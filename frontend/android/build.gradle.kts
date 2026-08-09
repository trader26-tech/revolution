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

// Force every Android module (the app AND all Flutter plugin subprojects) to
// compile against SDK 36. Some plugins (flutter_plugin_android_lifecycle,
// file_picker) require callers to compile against 36+, but the plugins
// themselves still default to 34 — which fails their AAR metadata check. We do
// it in afterEvaluate (once each subproject's Android extension exists) via the
// common BaseExtension, so it covers both library and application modules.
subprojects {
    // Hook fires when the Android Gradle plugin is applied to the subproject —
    // its `android` extension exists by then, and this runs before the project
    // finishes evaluating (so it's not "already evaluated" like afterEvaluate).
    pluginManager.withPlugin("com.android.library") {
        (extensions.getByName("android") as com.android.build.gradle.BaseExtension)
            .compileSdkVersion(36)
    }
    pluginManager.withPlugin("com.android.application") {
        (extensions.getByName("android") as com.android.build.gradle.BaseExtension)
            .compileSdkVersion(36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
