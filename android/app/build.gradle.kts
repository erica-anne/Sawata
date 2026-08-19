plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.sawata"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sawata"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // Native Firebase SDKs for SawataAccessibilityService/DomainBlocklist and
    // the AI classification workers — they all run outside the Flutter
    // engine (must keep working even if it's never started), so they can't
    // use the cloud_firestore/firebase_auth/firebase_ai Dart plugins and talk
    // to Firebase directly instead. Bumped from 33.7.0 so the BoM covers
    // firebase-ai and both App Check provider artifacts too.
    implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-ai")

    // App Check providers — split by build type so the debug provider
    // literally isn't on the classpath for profile/release builds. See
    // src/debug, src/profile, src/release's AppCheckActivator.kt.
    debugImplementation("com.google.firebase:firebase-appcheck-debug")
    "profileImplementation"("com.google.firebase:firebase-appcheck-playintegrity")
    releaseImplementation("com.google.firebase:firebase-appcheck-playintegrity")

    // AppInstallReceiver enqueues here; the actual classification runs in a
    // CoroutineWorker so it survives the app process being killed and gets
    // WorkManager's built-in constraint/retry/backoff handling for free.
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    // .await() on a Firebase Task<T> inside the CoroutineWorkers.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
}
