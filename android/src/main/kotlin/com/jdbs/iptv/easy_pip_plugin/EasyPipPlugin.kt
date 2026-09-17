package com.jdbs.iptv.easy_pip_plugin

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.ArrayList

class EasyPipPlugin: FlutterPlugin, ActivityAware, EasyPipApi {
    private var activity: Activity? = null
    private var context: Context? = null
    private var flutterApi: EasyPipFlutterApi? = null
    private var receiver: PipActionReceiver? = null
    
    // Status om bij te houden of de video momenteel speelt of gepauzeerd is
    private var isVideoPlaying: Boolean = true
    
    // Onthoud de laatst gekozen aspect ratio om de knoppen correct te kunnen verversen
    private var lastWidth: Int = 16
    private var lastHeight: Int = 9

    // NIEUW: Variabele om de urlStr op te slaan als dit nodig is voor de native player
    private var currentUrlStr: String? = null
    
    // Coroutine scope om de suspend functies van Pigeon veilig op de Main thread aan te roepen
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        EasyPipApi.setUp(binding.binaryMessenger, this)
        flutterApi = EasyPipFlutterApi(binding.binaryMessenger)

        // GEFIXT: Maak de receiver aan en registreer deze met de juiste vlaggen voor Android 14+
        receiver = PipActionReceiver().apply {
            PipActionReceiver.onActionTriggered = {
                activity?.runOnUiThread {
                    mainScope.launch {
                        try {
                            flutterApi?.onPlayPauseActionTriggered()
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            }
        }

        val filter = IntentFilter("com.jdbs.iptv.easy_pip_plugin.ACTION_PLAY_PAUSE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Context.RECEIVER_NOT_EXPORTED is verplicht vanaf Android 14 voor interne broadcasts
            context?.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(receiver, filter)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        EasyPipApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        
        // GEFIXT: Netjes de receiver ontkoppelen om memory leaks te voorkomen
        try {
            context?.unregisterReceiver(receiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        PipActionReceiver.onActionTriggered = null
        receiver = null
        context = null
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

        lastWidth = width.toInt()
        lastHeight = height.toInt()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = createPipParams(lastWidth, lastHeight, isVideoPlaying)
            currentActivity.enterPictureInPictureMode(params)
        } else {
            currentActivity.enterPictureInPictureMode()
        }
        
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
	
    override fun minimizeApp() {
        // Alleen nodig voor iOS, doet niets op Android
    }

    override fun setupAutoPiP(width: Long, height: Long, urlStr: String) {
        val currentActivity = activity ?: return
        if (!isPiPSupported()) return

        lastWidth = width.toInt()
        lastHeight = height.toInt()
        currentUrlStr = urlStr

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val params = createPipParams(lastWidth, lastHeight, isVideoPlaying)
            currentActivity.setPictureInPictureParams(params)
        }
    }

    override fun updatePlaybackState(isPlaying: Boolean) {
        this.isVideoPlaying = isPlaying
        val currentActivity = activity ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val isInPip = currentActivity.isInPictureInPictureMode
            if (isInPip) {
                val params = createPipParams(lastWidth, lastHeight, isPlaying)
                currentActivity.setPictureInPictureParams(params)
            }
        }
    }

    // --- Helper Methode voor Native Knoppen & Beeldverhouding ---
    private fun createPipParams(width: Int, height: Int, isPlaying: Boolean): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        
        val rational = Rational(width, height)
        builder.setAspectRatio(rational)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(isPlaying)
        }

        // GEFIXT: Maak de intent expliciet door hem hard te koppelen aan je PipActionReceiver klasse.
        // Dit voorkomt dat Android 14+ de achtergrond-click weigert uit te voeren.
        val intent = Intent(activity, PipActionReceiver::class.java).apply {
            action = "com.jdbs.iptv.easy_pip_plugin.ACTION_PLAY_PAUSE"
            `package` = activity?.packageName
        }
        
        // GEFIXT: Gebruik FLAG_IMMUTABLE in plaats van FLAG_MUTABLE.
        // Omdat we geen extra veranderbare data meesturen, eist Android 14+ hier onveranderbaarheid.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getBroadcast(activity, 0, intent, flags)

        val iconRes = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val title = if (isPlaying) "Pauze" else "Afspelen"

        val icon = Icon.createWithResource(activity, iconRes)
        val action = RemoteAction(icon, title, title, pendingIntent)

        val actions = ArrayList<RemoteAction>()
        actions.add(action)
        builder.setActions(actions)

        return builder.build()
    }

    private fun sendPipStatusToFlutter(isActive: Boolean) {
        mainScope.launch {
            try {
                flutterApi?.onPiPStatusChanged(isActive)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
