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
        versionCode = 9
        versionName = "0.9.0-alpha"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildTypes { getByName("release") { isMinifyEnabled = false } }
}

dependencies {
    implementation(project(":minecore"))
    testImplementation("junit:junit:4.13.2")
}
