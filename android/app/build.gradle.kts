plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.miagenda.local"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = if (System.getenv("MI_AGENDA_RECOVERY") == "1") "com.miagenda.recuperacion" else "com.miagenda.local"
        manifestPlaceholders["agendaLabel"] = if (System.getenv("MI_AGENDA_RECOVERY") == "1") "Mi Agenda Recuperación" else "Mi Agenda"
        manifestPlaceholders["agendaScheme"] = if (System.getenv("MI_AGENDA_RECOVERY") == "1") "miagendarecuperacion" else "miagenda"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    // Sin configuración release ni credenciales. Solo candidata debug en E1.
}
flutter { source = "../.." }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
