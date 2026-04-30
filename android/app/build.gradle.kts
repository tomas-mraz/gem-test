plugins {
    id("com.android.application")
}

android {
    namespace = "com.tomasmraz.gemtest"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.tomasmraz.gemtest"
        minSdk = 34
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a")
            isUniversalApk = false
        }
    }

    packaging {
        jniLibs {
            keepDebugSymbols += "**/*.so"
        }
    }
}
