package com.zero.app.zero

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.kurban.flutter_vap_plugin.FlutterVapViewFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            flutterEngine.platformViewsController.registry.registerViewFactory(
                "flutter_vap_plugin",
                FlutterVapViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
        } catch (e: IllegalStateException) {
            // Already registered by GeneratedPluginRegistrant — ignore
        }
    }
}
