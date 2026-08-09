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

    // Force every Android module (the app AND all Flutter plugin subprojects) to
    // compile against SDK 36. Some plugins (flutter_plugin_android_lifecycle,
    // file_picker) require callers to compile against 36+, but the plugins
    // themselves still default to 34 — failing their AAR metadata check.
    //
    // Registered HERE, in the FIRST subprojects pass — BEFORE the
    // evaluationDependsOn(":app") below forces each subproject to evaluate — so
    // the withPlugin hook is in place before the Android plugin applies and its
    // compileSdk is set. A plain `configureEach` on the variants also catches
    // any module that resolves late.
    val force36 = Action<org.gradle.api.plugins.AppliedPlugin> {
        (extensions.getByName("android") as com.android.build.gradle.BaseExtension)
            .compileSdkVersion(36)
    }
    pluginManager.withPlugin("com.android.library", force36)
    pluginManager.withPlugin("com.android.application", force36)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
