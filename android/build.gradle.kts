allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Register afterEvaluate HERE — before evaluationDependsOn(":app") below forces :app
    // to evaluate. This ensures the callback is queued on every subproject (including :app)
    // before any of them actually evaluate, preventing the "project already evaluated" error.
    afterEvaluate {
        // Force Java 21 on every Android plugin subproject so it matches the Kotlin JVM target.
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileOptions?.apply {
            sourceCompatibility = JavaVersion.VERSION_21
            targetCompatibility = JavaVersion.VERSION_21
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Lazily override the Kotlin JVM target to 11 across all subprojects.
// configureEach is lazy and does not trigger evaluation, so it is safe here.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
