allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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


buildscript {

    repositories {
      // Make sure that you have the following two repositories
      google()  // Google's Maven repository
      mavenCentral()  // Maven Central repository
      gradlePluginPortal()  // Add this for plugin resolution 

    }
    dependencies {

      // Add the Maven coordinates and latest version of the plugin
      classpath ("com.google.gms:google-services:4.4.2")
      classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
      classpath("com.android.tools.build:gradle:8.1.4")
    


    }
}

plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.4.2" apply false

}