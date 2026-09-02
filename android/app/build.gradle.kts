import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun signingValue(property: String, environment: String): String? =
    signingProperties.getProperty(property)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environment)?.takeIf { it.isNotBlank() }

val uploadStoreFile = signingValue("storeFile", "KIBOARD_UPLOAD_STORE_FILE")
val uploadStorePassword = signingValue("storePassword", "KIBOARD_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = signingValue("keyAlias", "KIBOARD_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = signingValue("keyPassword", "KIBOARD_UPLOAD_KEY_PASSWORD")
val releaseSigningConfigured =
    listOf(uploadStoreFile, uploadStorePassword, uploadKeyAlias, uploadKeyPassword).all { it != null }
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release signing is not configured. Run tool/setup-android-signing.ps1 or provide " +
            "the KIBOARD_UPLOAD_* environment variables.",
    )
}

android {
    namespace = "com.kiboard.kiboard_app"
    // Google Play requires API 36 for new apps and updates from 31 August 2026.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kiboard.kiboard_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = rootProject.file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug key: Play uses this signature to identify the publisher.
            signingConfig = signingConfigs.getByName("release")
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
