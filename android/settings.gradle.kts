pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Held at 8.x, with Gradle 8.11.1 in gradle-wrapper.properties. AGP 9
    // requires Gradle 9, and Gradle 9 removed `Project.exec()`, which the
    // cargokit build script inside irondash_engine_context (a super_clipboard
    // dependency) still calls. Both packages are already at their newest
    // published versions, so there is no upgrade out of it: raising these two
    // again breaks `flutter build apk` until cargokit is fixed upstream.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
