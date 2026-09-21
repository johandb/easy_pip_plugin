plugins {
    id("com.android.library")
}

android {
    namespace = "com.jdbs.iptv.easy_pip_plugin"
    compileSdk = 36 

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // VOEG DIT GEDEELTE TOE: Dit dwingt Java om ook versie 17 te gebruiken
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Dit dwingt Kotlin om versie 17 te gebruiken
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-ktx:1.8.0")
}
