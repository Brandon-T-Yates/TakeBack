package com.tyleryates.takeback

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var restrictions: AndroidRestrictionsBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        restrictions = AndroidRestrictionsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        restrictions?.dispose()
        restrictions = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        restrictions?.onActivityResult(requestCode, resultCode)
    }
}
