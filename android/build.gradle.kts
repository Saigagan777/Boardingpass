import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            extensions.configure<BaseExtension> {
                compileSdkVersion(36)
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
subprojects {
    val configureProject: (Project) -> Unit = { p ->
        val ext = p.extensions.findByName("android")
        if (ext != null) {
            val methods = ext.javaClass.methods
            var invoked = false
            for (m in methods) {
                if (m.name == "compileSdkVersion" && m.parameterCount == 1 && (m.parameterTypes[0] == Integer.TYPE || m.parameterTypes[0] == java.lang.Integer::class.java)) {
                    m.invoke(ext, 36)
                    invoked = true
                    break
                }
            }
            if (!invoked) {
                for (m in methods) {
                    if ((m.name == "compileSdk" || m.name == "setCompileSdk") && m.parameterCount == 1 && (m.parameterTypes[0] == Integer.TYPE || m.parameterTypes[0] == java.lang.Integer::class.java)) {
                        m.invoke(ext, 36)
                        break
                    }
                }
            }
        }
    }
    if (project.state.executed) {
        configureProject(project)
    } else {
        project.afterEvaluate {
            configureProject(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
