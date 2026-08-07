plugins {
    // ...
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    val rootBuildDir = file("${project.rootDir}/../build")
    layout.buildDirectory.set(rootBuildDir.resolve(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
