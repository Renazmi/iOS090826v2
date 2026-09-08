plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Read version directly from pubspec.yaml — Gradle-only builds were stuck on an old versionCode.
val pubspecFile = rootProject.projectDir.parentFile.resolve("pubspec.yaml")
val pubspecText = pubspecFile.readText()
val versionMatch = Regex("""version:\s*([\d.]+)\+(\d+)""").find(pubspecText)
    ?: throw GradleException("Could not read version from ${pubspecFile.absolutePath}")
val trackitVersionName = versionMatch.groupValues[1]
val trackitVersionCode = versionMatch.groupValues[2].toInt()

android {
    namespace = "com.trackit.trackit_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.trackit.trackit_mobile"
        // Android 8.0+ Oreo (API 26). Blocks all Nougat (7.0/7.1) and below.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = trackitVersionCode
        versionName = trackitVersionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    if (buildType.name == "release") {
        outputs.configureEach {
            (this as ApkVariantOutputImpl).outputFileName = "TrackIT.apk"
        }
    }
}

flutter {
    source = "../.."
}

val mobileProjectDir = rootProject.projectDir.parentFile!!
val releasesDir = mobileProjectDir.parentFile.resolve("releases")

tasks.register("exportTrackITApk") {
    dependsOn("assembleRelease")
    doLast {
        val outputDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val namedApk = outputDir.resolve("TrackIT.apk")
        val legacyApk = outputDir.resolve("app-release.apk")
        val source = when {
            namedApk.exists() -> namedApk
            legacyApk.exists() -> legacyApk
            else -> throw GradleException("Release APK not found in ${outputDir.absolutePath}")
        }
        releasesDir.mkdirs()
        val releasesDest = releasesDir.resolve("TrackIT.apk")
        source.copyTo(releasesDest, overwrite = true)
        logger.lifecycle("Exported release APK to ${releasesDest.absolutePath}")
    }
}

tasks.register("exportTrackITAab") {
    dependsOn("bundleRelease")
    doLast {
        val outputDir = layout.buildDirectory.dir("outputs/bundle/release").get().asFile
        val source = outputDir.resolve("app-release.aab")
        if (!source.exists()) {
            throw GradleException("Release AAB not found in ${outputDir.absolutePath}")
        }
        releasesDir.mkdirs()
        val releasesDest = releasesDir.resolve("TrackIT.aab")
        source.copyTo(releasesDest, overwrite = true)
        logger.lifecycle("Exported release AAB to ${releasesDest.absolutePath}")
    }
}
