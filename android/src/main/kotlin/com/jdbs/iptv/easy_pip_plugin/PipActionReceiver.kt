package com.jdbs.iptv.easy_pip_plugin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PipActionReceiver : BroadcastReceiver() {
    companion object {
        var onActionTriggered: (() -> Unit)? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.jdbs.iptv.easy_pip_plugin.ACTION_PLAY_PAUSE") {
            // Vuur de callback af richting de hoofdklasse van de plugin
            onActionTriggered?.invoke()
        }
    }
}
