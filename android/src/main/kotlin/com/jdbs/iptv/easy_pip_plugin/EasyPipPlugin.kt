package com.jdbs.iptv.easy_pip_plugin

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class EasyPipPlugin: FlutterPlugin, ActivityAware, EasyPipApi {
    private var activity: Activity? = null
    private var context: Context? = null
    private var flutterApi: EasyPipFlutterApi? = null
    
    // Coroutine scope om de suspend functies van Pigeon veilig op de Main thread aan te roepen
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        EasyPipApi.setUp(binding.binaryMessenger, this)
        flutterApi = EasyPipFlutterApi(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = null
        EasyPipApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
    }

    // --- ActivityAware lifecycle methoden ---
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- EasyPipApi (Pigeon) Implementatie ---

    override fun isPiPSupported(): Boolean {
        return context?.packageManager?.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE) ?: false
    }

    override fun enterPiP(width: Long, height: Long) {
        val currentActivity = activity ?: return
        if (!isPiPSupported()) return

        val rational = Rational(width.toInt(), height.toInt())
        
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(rational)
            .setAutoEnterEnabled(true) 

        currentActivity.enterPictureInPictureMode(builder.build())
        
        // Direct na het triggeren sturen we de status alvast mee
        sendPipStatusToFlutter(true)
    }

    override fun getPiPStatus(): PipStatus {
        val currentActivity = activity
        val isActive = if (currentActivity != null) {
            currentActivity.isInPictureInPictureMode
        } else {
            false
        }
        
        return PipStatus(
            isSupported = isPiPSupported(),
            isActive = isActive
        )
    }
	
	override fun setupAutoPiP(width: Long, height: Long) {
		// No-op: Android heeft dit niet apart nodig omdat we 
		// setAutoEnterEnabled(true) al gebruiken in enterPiP.
	}
	

    // Handige helper om de status veilig naar Flutter te sturen binnen een Coroutine
    private fun sendPipStatusToFlutter(isActive: Boolean) {
        mainScope.launch {
            try {
                // Pigeon's suspend functie correct aanroepen zonder extra callbacks
                flutterApi?.onPiPStatusChanged(isActive)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
