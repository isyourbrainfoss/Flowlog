import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadKeystoreProperties = Properties().apply {
    val propsFile = rootProject.file("upload-key.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.flowlog.flowlog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flowlog.flowlog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            keyAlias = uploadKeystoreProperties.getProperty("keyAlias")
            keyPassword = uploadKeystoreProperties.getProperty("keyPassword")
            storeFile = uploadKeystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = uploadKeystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
