package com.azancoth.tidypics

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Infos sur l'appareil dont l'app a besoin (ex. Android 12+ pour
        // « Gestion des médias »), sans dépendance supplémentaire.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tidypics/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }
}
