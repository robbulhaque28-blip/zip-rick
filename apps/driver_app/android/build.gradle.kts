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

// --- CRITICAL FIX: Must happen BEFORE the evaluation lock ---
subprojects {
    afterEvaluate {
        project.extensions.findByName("android")?.let { androidExt ->
            val method = androidExt.javaClass.methods.find { 
                it.name == "setCompileSdk" || it.name == "compileSdkVersion" 
            }
            try {
                method?.invoke(androidExt, 36)
            } catch (e: Exception) {
                // Silently skip if a module doesn't support this
            }
        }
    }
}
// ------------------------------------------------------------

// The evaluation lock (Anything after this point crashes)
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}