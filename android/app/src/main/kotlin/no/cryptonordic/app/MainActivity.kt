package no.cryptonordic.app

import android.app.UiModeManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import no.cryptonordic.app.ui.PhoneApp
import no.cryptonordic.app.ui.TvDashboard

class MainActivity : ComponentActivity() {
    companion object {
        /** While the app is on screen nothing is announced. */
        @Volatile var inForeground = false
    }

    private lateinit var store: Store
    private var radio: Radio? = null
    private var openStory by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Lang.load(this)
        store = Store(applicationContext)
        openStory = intent?.getStringExtra("story")
        lifecycleScope.launch { store.run() }

        val isTv = getSystemService(UiModeManager::class.java).currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        if (isTv) {
            // An information screen: it never hands over to the screensaver.
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val r = Radio(applicationContext).also { radio = it }
            setContent { TvDashboard(store, r) }
        } else {
            enableEdgeToEdge()
            if (Alerts.enabled(this)) Alerts.schedule(this)
            // Registers with the push server, or tells it to forget this device.
            if (Push.configured) Push.syncLater(this)
            setContent { PhoneApp(store, openStory) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openStory = intent.getStringExtra("story")
    }

    override fun onResume() { super.onResume(); inForeground = true }
    override fun onPause() { super.onPause(); inForeground = false }

    override fun onDestroy() {
        radio?.stop()
        super.onDestroy()
    }
}
