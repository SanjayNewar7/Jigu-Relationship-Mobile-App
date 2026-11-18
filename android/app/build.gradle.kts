import java.util.Properties
import java.io.FileInputStream
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) FileInputStream(signingFile).use { signingProperties.load(it) }
fun signingValue(name: String, env: String): String? =
    System.getenv(env) ?: signingProperties.getProperty(name)
val releaseStore = signingValue("storeFile", "JIGU_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "JIGU_STORE_PASSWORD")
val releaseAlias = signingValue("keyAlias", "JIGU_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "JIGU_KEY_PASSWORD")
val signingReady = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword).all { !it.isNullOrBlank() }
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !signingReady) {
    throw GradleException("Release signing is missing. Run tool/configure_signing.ps1 locally. Debug signing is never used for release.")
}
android {
    namespace = "com.sanjaya.jigu"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.sanjaya.jigu"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            if (signingReady) {
                storeFile = rootProject.file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }
flutter { source = "../.." }
