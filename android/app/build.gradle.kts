import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    val rawProps = Properties()
    FileInputStream(keystorePropertiesFile).use { rawProps.load(it) }
    for ((k, v) in rawProps) {
        val cleanKey = k.toString().replace("\uFEFF", "").trim()
        val cleanVal = v.toString().trim()
        keystoreProperties.setProperty(cleanKey, cleanVal)
    }
}

android {
    namespace = "com.scorebot.score_bot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.scorebot.score_bot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Le Play Store exige un versionCode unique et croissant pour chaque envoi.
    // On le dérive du numéro de build de pubspec.yaml (version: x.y.z+N) :
    //   téléphone = N * 100 + 1, montre = N * 100 + 2
    // → il suffit d'incrémenter "+N" dans pubspec.yaml avant chaque publication.
    val baseVersionCode = flutter.versionCode
    flavorDimensions += "device"
    productFlavors {
        create("phone") {
            dimension = "device"
            versionCode = baseVersionCode * 100 + 1
        }
        create("watch") {
            dimension = "device"
            versionCode = baseVersionCode * 100 + 2
        }
    }

    val releaseStoreFile = keystoreProperties.getProperty("storeFile")
        ?.let { file(it) }
        ?.takeIf { it.exists() }
    val isReleaseTaskRequested = gradle.startParameter.taskNames
        .any { it.contains("Release", ignoreCase = true) }

    // Un bundle signé avec la clé debug est systématiquement refusé par le Play Store :
    // on échoue explicitement plutôt que de produire un .aab inutilisable.
    if (releaseStoreFile == null && isReleaseTaskRequested) {
        throw GradleException(
            "Keystore de release introuvable. Vérifiez android/key.properties " +
                "(storeFile=${keystoreProperties.getProperty("storeFile")})."
        )
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFile != null) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            } else {
                // Builds debug/profile uniquement : la clé debug suffit.
                val debugSigning = signingConfigs.getByName("debug")
                keyAlias = debugSigning.keyAlias
                keyPassword = debugSigning.keyPassword
                storeFile = debugSigning.storeFile
                storePassword = debugSigning.storePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
