import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "no.cryptonordic.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "no.cryptonordic.app"
        minSdk = 26
        targetSdk = 36
        // CI sets VERSION_CODE from the run number so every build installs over the last one.
        versionCode = System.getenv("VERSION_CODE")?.toIntOrNull() ?: 1
        versionName = "1.1.0"

        // Push notifications (docs/push.md). The Firebase client settings come from the
        // environment (CI: repository secrets FIREBASE_*) or ~/.gradle/gradle.properties
        // (firebaseAppId, ...). Without them the app keeps the on-device check only.
        fun setting(env: String, prop: String, default: String = "") =
            (System.getenv(env) ?: (project.findProperty(prop) as String?) ?: default).replace("\"", "")
        buildConfigField("String", "FIREBASE_APP_ID", "\"${setting("FIREBASE_APP_ID", "firebaseAppId")}\"")
        buildConfigField("String", "FIREBASE_API_KEY", "\"${setting("FIREBASE_API_KEY", "firebaseApiKey")}\"")
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"${setting("FIREBASE_PROJECT_ID", "firebaseProjectId")}\"")
        buildConfigField("String", "FIREBASE_SENDER_ID", "\"${setting("FIREBASE_SENDER_ID", "firebaseSenderId")}\"")
        buildConfigField("String", "PUSH_SERVER_URL",
            "\"${setting("PUSH_SERVER_URL", "pushServerUrl", "https://nordic-crypto-app-push.nordiccrypto.workers.dev/")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Signed with the upload key from keystore.properties when it exists (see README).
            val props = rootProject.file("keystore.properties")
            if (props.exists()) {
                val p = Properties().apply { props.inputStream().use { load(it) } }
                signingConfig = signingConfigs.create("upload") {
                    storeFile = rootProject.file(p.getProperty("storeFile"))
                    storePassword = p.getProperty("storePassword")
                    keyAlias = p.getProperty("keyAlias")
                    keyPassword = p.getProperty("keyPassword")
                }
            }
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    val compose = "1.12.1"
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui:$compose")
    implementation("androidx.compose.foundation:foundation:$compose")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-session:1.11.1")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.google.firebase:firebase-messaging:25.1.3")
}
