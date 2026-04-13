plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")           // ✅ use o ID canônico do plugin Kotlin
    // O Flutter plugin deve vir depois de Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")         // ✅ necessário para Firebase
}

android {
    namespace = "com.titans.titans_bjj"
    compileSdk = flutter.compileSdkVersion

    // ✅ mantenha a do Flutter OU fixe para a versão estável do NDK usada por muitas integrações
    // ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.titans.titans_bjj"
        // ✅ Firebase exige minSdk 23. Garante mesmo se o Flutter estiver menor.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            // Ajuste sua signingConfig para produção depois
            signingConfig = signingConfigs.getByName("debug")
            // (opcional) habilite shrinker/proguard conforme seu caso
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
