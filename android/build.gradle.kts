import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// ===== Firebase / Google Services =====
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

// ===== Repositories for all projects =====
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ===== Custom build directory (Flutter standard tweak) =====
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ===== Ensure app is evaluated first =====
subprojects {
    project.evaluationDependsOn(":app")
}

// ===== Clean task =====
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
