import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (PRD v2 M8): the Play upload key, described by a
// key.properties file (storeFile, storePassword, keyAlias, keyPassword). Its
// path comes from THUMBPARTY_KEY_PROPERTIES (CI writes it there) or
// android/key.properties. Neither is ever committed. Without it, release
// builds fall back to the debug key, so local builds still work, but Play
// rejects them. See docs/release.md.
val keyPropertiesFile = System.getenv("THUMBPARTY_KEY_PROPERTIES")?.let { file(it) } ?: rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) FileInputStream(keyPropertiesFile).use { load(it) }
}

android {
    namespace = "com.thumbparty.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Shared with the iOS bundle ID. Play never lets an app ID change (PRD v2 Names and IDs).
        applicationId = "com.thumbparty.app"
        // Android 12 (API 31) minimum (PRD v2 C30): the newest API used is VibratorManager (31).
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
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
