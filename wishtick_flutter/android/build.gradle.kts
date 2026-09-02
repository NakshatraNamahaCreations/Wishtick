plugins {
    // Reads `android/app/google-services.json` and turns it into the resources
    // the Firebase SDKs look up at runtime. Declared here and applied in
    // `app/build.gradle.kts` — `apply false` means "resolve the version for
    // the whole build, but do not apply it to the root project", which has no
    // Android plugin for it to hook into.
    //
    // The build FAILS if `google-services.json` is missing, by design: a
    // Firebase app that silently starts with no config is worse than one that
    // will not compile.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

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
