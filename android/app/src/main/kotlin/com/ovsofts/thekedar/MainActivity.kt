package com.ovsofts.thekedar

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // What no plugin gives the app: the Play Store install referrer, which is
        // how a friend's Share & Earn code survives the trip through the store.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallReferrer" -> readInstallReferrer(result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Answers with the raw referrer string the Play Store recorded for this
     * install (e.g. `utm_source=referral&ref=KW7X2PQR`), or null when there is
     * none or the store cannot be asked. Exactly one answer, on the UI thread.
     */
    private fun readInstallReferrer(result: MethodChannel.Result) {
        var answered = false
        var client: InstallReferrerClient? = null

        fun answer(value: String?) {
            if (answered) return
            answered = true
            runOnUiThread { result.success(value) }
            try {
                client?.endConnection()
            } catch (e: Exception) {
                // Already closed — nothing to clean up.
            }
        }

        try {
            val c = InstallReferrerClient.newBuilder(applicationContext).build()
            client = c
            c.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    val referrer = if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            c.installReferrer.installReferrer
                        } catch (e: Exception) {
                            null
                        }
                    } else {
                        null
                    }
                    answer(referrer)
                }

                override fun onInstallReferrerServiceDisconnected() = answer(null)
            })
        } catch (e: Exception) {
            answer(null)
        }
    }

    companion object {
        private const val CHANNEL = "kaamji/app"
    }
}
