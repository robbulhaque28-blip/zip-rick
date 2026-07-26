allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The Gradle root project here is the `android` folder, so "../../build"
// resolves to <app>/build - which is exactly where the Flutter tool looks for
// the APK. Do NOT change this to "../build": that puts the output in
// <app>/android/build and the build fails with
// "Gradle build failed to produce an .apk file".
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ---------------------------------------------------------------------------
// Force every Android module - including Flutter plugins such as
// firebase_messaging that hardcode an old compileSdk - to compile against 36.
//
// The previous version of this block did:
//     methods.find { it.name == "setCompileSdk" || it.name == "compileSdkVersion" }
//     try { method?.invoke(androidExt, 36) } catch (e: Exception) { }
//
// Two problems with that:
//   1. Class.getMethods() has NO defined order, and compileSdkVersion has both
//      an (int) and a (String) overload. If the String overload was returned
//      first, invoke(ext, 36) threw IllegalArgumentException.
//   2. The catch block was empty, so that failure was completely silent and
//      the module quietly stayed on android-33.
//
// This version tries each known API in turn, matching the parameter type
// exactly, then reads the value back and PRINTS it for every module.
// ---------------------------------------------------------------------------
val forcedCompileSdk = 36

subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            val cls = androidExt.javaClass
            var appliedBy = "none"

            fun tryCall(name: String, argType: Class<*>, arg: Any): Boolean {
                if (appliedBy != "none") return true
                val m = cls.methods.firstOrNull {
                    it.name == name && it.parameterCount == 1 && it.parameterTypes[0] == argType
                }
                if (m == null) return false
                return try {
                    m.invoke(androidExt, arg)
                    appliedBy = name + "(" + argType.simpleName + ")"
                    true
                } catch (e: Exception) {
                    println("VYBE-SDK  " + project.name + ": " + name + " threw " + e.javaClass.simpleName)
                    false
                }
            }

            tryCall("setCompileSdk", java.lang.Integer::class.java, forcedCompileSdk)
            tryCall("setCompileSdk", Int::class.javaPrimitiveType!!, forcedCompileSdk)
            tryCall("setCompileSdkVersion", Int::class.javaPrimitiveType!!, forcedCompileSdk)
            tryCall("compileSdkVersion", Int::class.javaPrimitiveType!!, forcedCompileSdk)
            tryCall("setCompileSdkVersion", String::class.java, "android-" + forcedCompileSdk)
            tryCall("compileSdkVersion", String::class.java, "android-" + forcedCompileSdk)

            var readBack = "unknown"
            try {
                var g = cls.methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
                if (g == null) {
                    g = cls.methods.firstOrNull { it.name == "getCompileSdkVersion" && it.parameterCount == 0 }
                }
                if (g != null) {
                    val v = g.invoke(androidExt)
                    readBack = if (v == null) "null" else v.toString()
                }
            } catch (e: Exception) {
                readBack = "unreadable"
            }

            println("VYBE-SDK  " + project.name + " -> compileSdk=" + readBack + "  (set via " + appliedBy + ")")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
