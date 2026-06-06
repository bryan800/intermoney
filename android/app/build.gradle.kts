plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ← "kotlin-android" is deprecated; use full plugin ID
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.interflex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17" // ← Use string literal directly; JavaVersion.VERSION_17.toString()
    }   //   can return "17" or "VERSION_17" depending on the Kotlin/Java version, 
        //   which may cause a build failure

    defaultConfig {
        applicationId = "com.example.interflex"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // ← Add this if you have 64K method limit issues (common in Flutter)
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false  // ← Explicit is safer; avoids accidental shrinking
            isShrinkResources = false // ← Pair with isMinifyEnabled; must both be false or true
        }
    }
}

flutter {
    source = "../.."
}