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
// Some plugins (e.g. file_picker) hardcode an older compileSdk than their own
// transitive deps (flutter_plugin_android_lifecycle) now require. Force every
// Android plugin subproject up to the app's compileSdk. Registered BEFORE the
// evaluationDependsOn block below so no subproject is evaluated yet. Reflection
// avoids importing AGP types (not on the root build script's classpath).
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            ext.javaClass.methods
                .firstOrNull {
                    it.name == "setCompileSdkVersion" &&
                        it.parameterTypes.size == 1 &&
                        it.parameterTypes[0] == Int::class.javaPrimitiveType
                }
                ?.invoke(ext, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
