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

    // Force every Android module (app + plugins) to compile against SDK 36,
    // which newer plugins (file_picker -> flutter_plugin_android_lifecycle)
    // require. Registered before evaluationDependsOn so projects aren't yet
    // evaluated.
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
                as? com.android.build.gradle.BaseExtension
            androidExt?.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
