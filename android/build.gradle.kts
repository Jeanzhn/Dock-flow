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
    afterEvaluate { project ->
        if (project.extensions.findByName("android") != null) {
            @Suppress("UnstableApiUsage")
            project.extensions.configure("android") {
                compileSdk 34
                buildToolsVersion "34.0.0"
                
                defaultConfig {
                    targetSdk 34
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
