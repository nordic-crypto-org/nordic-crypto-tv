package no.cryptonordic.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull
import no.cryptonordic.app.Api
import no.cryptonordic.app.Lang
import java.net.HttpURLConnection
import java.net.URL

private const val BADGE_PAGE = "https://nft.nordiccrypto.no/"

private suspend fun badgeGet(path: String): Pair<Int, String?> = withContext(Dispatchers.IO) {
    runCatching {
        val c = URL(BADGE_PAGE + path).openConnection() as HttpURLConnection
        c.connectTimeout = 10_000; c.readTimeout = 10_000
        c.responseCode to (if (c.responseCode == 200) c.inputStream.bufferedReader().use { it.readText() } else null)
    }.getOrDefault(0 to null)
}

/** The Nordic Crypto Shield badge from nft.nordiccrypto.no, like the Apple TV tab: minted count and a Wally Wallet QR code. */
@Composable
fun TvBadge() {
    var minted by remember { mutableStateOf<Int?>(null) }
    var supply by remember { mutableStateOf(100) }
    var link by remember { mutableStateOf<String?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        var cookie: String? = null
        var issued = 0L
        while (true) {
            val previous = minted
            badgeGet("status").second?.let { s ->
                runCatching { Api.json.parseToJsonElement(s).jsonObject }.getOrNull()?.let {
                    minted = it["minted"]?.jsonPrimitive?.int; supply = it["supply"]?.jsonPrimitive?.int ?: supply
                }
            }
            if (System.currentTimeMillis() - issued > 30 * 60_000) cookie = null
            if (link == null || cookie == null || (previous != null && previous != minted)) {
                val (code, body) = badgeGet("api/session" + (cookie?.let { "?cookie=$it" } ?: ""))
                when (code) {
                    200 -> runCatching { Api.json.parseToJsonElement(body!!).jsonObject }.getOrNull()?.let {
                        val c = it["cookie"]?.jsonPrimitive?.contentOrNull
                        if (c != cookie) issued = System.currentTimeMillis()
                        cookie = c; link = it["link"]?.jsonPrimitive?.contentOrNull; note = null
                    }
                    410 -> { link = null; note = "All 100 badges have been minted." }
                    503 -> { link = null; note = "Minting opens soon." }
                }
            }
            delay(5000)
        }
    }
    Row(Modifier.fillMaxSize().padding(48.dp), horizontalArrangement = Arrangement.spacedBy(64.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Nordic Crypto Shield", color = NL.textPrimary, fontSize = 44.sp, fontFamily = NL.serif, fontWeight = FontWeight.Bold)
            Text(Lang.tr("Edition of 100, while supply lasts."), color = NL.textPrimary, fontSize = 20.sp)
            minted?.let { Text(Lang.tr("%lld / %lld minted", it, supply), color = Color(0xFFD9A034), fontSize = 30.sp, fontWeight = FontWeight.Bold) }
            Text(Lang.tr("Free from Nordic Crypto, you pay a small Nexa network fee yourself."), color = NL.textSecondary, fontSize = 16.sp)
            Text(Lang.tr("Collectible badge, no economic rights."), color = NL.textTertiary, fontSize = 13.sp)
            note?.let { Text(Lang.tr(it), color = NL.accent, fontSize = 18.sp) }
            Text(Lang.tr("Terms and privacy: %@", "nft.nordiccrypto.no"), color = NL.textTertiary, fontSize = 12.sp)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            QrCode(link ?: BADGE_PAGE, 320.dp)
            Text(Lang.tr(if (link == null) "Scan with your phone" else "Scan with Wally Wallet on your phone, then confirm."),
                color = NL.textPrimary, fontSize = 16.sp)
            Text(Lang.tr("Get Wally Wallet from the App Store or Google Play."), color = NL.textSecondary, fontSize = 13.sp)
        }
    }
}
