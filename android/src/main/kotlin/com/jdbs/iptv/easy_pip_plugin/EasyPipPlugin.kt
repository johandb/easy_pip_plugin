package com.jdbs.iptv.easy_pip_plugin

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.Context
import android.content.Intent
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
    
    // Status om bij te houden of de video momenteel speelt of gepauzeerd is
    private var isVideoPlaying: Boolean = true
    
    // Onthoud de laatst gekozen aspect ratio om de knoppen correct te kunnen verversen
    private var lastWidth: Int = 16
    private var lastHeight: Int = 9
    
    // Coroutine scope om de suspend functies van Pigeon veilig op de Main thread aan te roepen
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        EasyPipApi.setUp(binding.binaryMessenger, this)
        flutterApi = EasyPipFlutterApi(binding.binaryMessenger)

        // Koppel de klik van de native Android BroadcastReceiver aan de Pigeon Flutter API
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = null
        EasyPipApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        PipActionReceiver.onActionTriggered = null
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
	
    override fun setupAutoPiP(width: Long, height: Long) {
        val currentActivity = activity ?: return
        if (!isPiPSupported()) return

        lastWidth = width.toInt()
        lastHeight = height.toInt()

        // Android 12+ (API 31) vereist dat we params vooraf registreren voor de swipe-to-home actie
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val params = createPipParams(lastWidth, lastHeight, isVideoPlaying)
            currentActivity.setPictureInPictureParams(params)
        }
    }

    // NIEUW: Update de afspeelstatus en ververs direct de native knoppen als we in PiP zitten
    override fun updatePlaybackState(isPlaying: Boolean) {
        this.isVideoPlaying = isPlaying
        val currentActivity = activity ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val isInPip = currentActivity.isInPictureInPictureMode
            if (isInPip) {
                // Ververs het PiP venster met de nieuwe Play of Pause knop lay-out
                val params = createPipParams(lastWidth, lastHeight, isPlaying)
                currentActivity.setPictureInPictureParams(params)
            }
        }
    }

    // --- Helper Methode voor Native Knoppen & Beeldverhouding ---
    private fun createPipParams(width: Int, height: Int, isPlaying: Boolean): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        
        // Stel de beeldverhouding in
        val rational = Rational(width, height)
        builder.setAspectRatio(rational)

        // Android 12+ auto enter ondersteuning inschakelen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(true)
        }

        // Maak de intent die afgevuurd wordt zodra de gebruiker op de knop drukt
        val intent = Intent("com.jdbs.iptv.easy_pip_plugin.ACTION_PLAY_PAUSE").apply {
            `package` = activity?.packageName
        }
        
        // Mutability flags verplicht vanaf Android 12+
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getBroadcast(activity, 0, intent, flags)

        // Bepaal het juiste native icoon en tekst
        val iconRes = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val title = if (isPlaying) "Pauze" else "Afspelen"

        val icon = Icon.createWithResource(activity, iconRes)
        val action = RemoteAction(icon, title, title, pendingIntent)

        // Voeg de actie toe aan de knoppenbalk
        val actions = ArrayList<RemoteAction>()
        actions.add(action)
        builder.setActions(actions)

        return builder.build()
    }

    // Handige helper om de status veilig naar Flutter te sturen binnen een Coroutine
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
