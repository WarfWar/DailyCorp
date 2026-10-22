plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.dailycorp.nativegame"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.dailycorp.nativegame.rebuilt"
        minSdk = 26
        targetSdk = 35
        versionCode = 25
        versionName = "0.24.0-alpha-3d"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    signingConfigs {
        create("dailycorpAlpha") {
            storeFile = rootProject.file(".android-signing/dailycorp.jks")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeType = "PKCS12"
        }
    }
    buildTypes {
        getByName("debug") { signingConfig = signingConfigs.getByName("dailycorpAlpha") }
        getByName("release") {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("dailycorpAlpha")
        }
    }
}

dependencies {
    implementation(project(":minecore"))
    testImplementation("junit:junit:4.13.2")
}
