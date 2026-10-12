allprojects {
    repositories {
        google()
        mavenCentral()
        // Репозиторий RuStore SDK (нужен и приложению — мы напрямую используем
        // RuStoreMessagingService в нативном BemboxPushService).
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
