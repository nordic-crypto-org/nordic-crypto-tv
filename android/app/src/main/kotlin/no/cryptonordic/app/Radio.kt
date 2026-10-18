package no.cryptonordic.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession

/** Radio Norge behind the Android TV screen, like the Apple TV one. Off at launch; it plays only after Play is pressed. The other stations are an easter egg (see [select]). */
class Radio(private val context: Context) {
    data class Station(val name: String, val stream: String)

    companion object {
        val stations = listOf(
            Station("Radio Norge", "https://live-bauerno.sharp-stream.com/radionorge_no_mp3"),
            Station("Techno Underground | Fluxmusic", "https://streams.fluxfm.de/technoug/mp3-128"),
            Station("Berlin Beach House Radio", "https://streams.fluxfm.de/bbeachhouse/mp3-128"),
        )
    }

    var isOn by mutableStateOf(false)
        private set
    var station by mutableStateOf(stations[0])
        private set
    var isPlaying by mutableStateOf(false)
        private set
    private var player: ExoPlayer? = null
    private var session: MediaSession? = null
    private val presses = mutableListOf<Long>()

    fun toggle() {
        isOn = !isOn
        if (isOn) play() else stop()
    }

    /** OK on the radio chip: five quick presses switch to the next station. */
    fun select(now: Long = System.currentTimeMillis()) {
        if (presses.isNotEmpty() && now - presses.last() > 1500) presses.clear()
        presses += now
        if (presses.size < 5) return
        presses.clear()
        next()
    }

    private fun next() {
        station = stations[(stations.indexOf(station) + 1) % stations.size]
        if (isOn) play()
    }

    private fun play() {
        stop()
        val attributes = AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).setUsage(C.USAGE_MEDIA).build()
        val p = ExoPlayer.Builder(context).setAudioAttributes(attributes, true).setHandleAudioBecomingNoisy(true).build().apply {
            setMediaItem(MediaItem.Builder().setUri(station.stream)
                .setMediaMetadata(MediaMetadata.Builder().setTitle(station.name).setArtist("Nordic Crypto").build()).build())
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) { this@Radio.isPlaying = playing }
                // Live streams drop: rejoin the live edge after an error.
                override fun onPlayerError(error: PlaybackException) { if (this@Radio.isOn) this@Radio.play() }
            })
            prepare()
            play()
        }
        player = p
        session = MediaSession.Builder(context, p).build()
    }

    fun stop() {
        session?.release()
        session = null
        player?.release()
        player = null
        isPlaying = false
    }
}
