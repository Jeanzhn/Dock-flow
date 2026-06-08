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
<<<<<<< HEAD

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(
        newBuildDir.dir(project.name)
    )
}

=======
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
>>>>>>> 5604afa8b389ea01d3eaff1f4a55b942d36afa90
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
<<<<<<< HEAD
}
=======
}
>>>>>>> 5604afa8b389ea01d3eaff1f4a55b942d36afa90
