plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

dependencies {
    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "com.example.akonssquare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.akonssquare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
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

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            // Use a provider or lazy evaluation to get the latest BN during execution/finalization
            val counterFile = file("build_counter.txt")
            val bn = if (counterFile.exists()) counterFile.readText().trim() else "0"
            val newName = "AkonsSquare_V${variant.versionName}_${variant.versionCode}_BN${bn}_${variant.buildType.name}.apk"
            output.outputFileName = newName
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

tasks.register("incrementBuildNumber") {
    doFirst {
        val taskNames = project.gradle.startParameter.taskNames
        // Increment for all assemble/build tasks, or if explicitly called
        val shouldIncrement = taskNames.any { 
            it.contains("assemble", ignoreCase = true) || 
            it.contains("build", ignoreCase = true) || 
            it.contains("bundle", ignoreCase = true) ||
            it.contains("run", ignoreCase = true)
        }
        
        if (!shouldIncrement && taskNames.isNotEmpty()) {
            println("BN: Skipping increment for tasks: $taskNames")
            return@doFirst
        }

        val counterFile = file("build_counter.txt")
        if (!counterFile.exists()) {
            counterFile.writeText("0")
        }
        val currentBuild = counterFile.readText().trim().toIntOrNull() ?: 0
        val newBuild = currentBuild + 1
        counterFile.writeText(newBuild.toString())
        println("BN: Incremented to $newBuild")
        
        // Parse pubspec.yaml to get the version name automatically
        val pubspecFile = file("../../pubspec.yaml")
        var pubspecVersion = "1.0.0"
        if (pubspecFile.exists()) {
            val lines = pubspecFile.readLines()
            for (line in lines) {
                if (line.trim().startsWith("version:")) {
                    pubspecVersion = line.split(":")[1].trim()
                    break
                }
            }
        }
        
        val dartFile = file("../../lib/Common/build_config.dart")
        dartFile.parentFile.mkdirs()
        dartFile.writeText("const int buildNumber = $newBuild;\nconst String appVersion = \"$pubspecVersion\";\n")
    }
}

tasks.named("preBuild") {
    dependsOn("incrementBuildNumber")
}
