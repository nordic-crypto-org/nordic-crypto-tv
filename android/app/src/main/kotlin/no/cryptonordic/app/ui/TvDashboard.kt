package no.cryptonordic.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import no.cryptonordic.app.*
import java.time.ZonedDateTime

/**
 * The Android TV app, like the Apple TV one: a tab bar with Today (the "Kveldsnytt"
 * page: lead story, cards, agenda and spotlight), Nordic Shield NFT and Contact us.
 * Play/Pause switches the radio, fast forward or OK on the radio chip changes station.
 */
@Composable
fun TvDashboard(store: Store, radio: Radio) {
    val feed by store.feed.collectAsState()
    val lang = Lang.current
    val tabs = listOf("Today", "Nordic Shield NFT", "Contact us")
    var tab by remember { mutableStateOf(0) }
    val todayFocus = remember { FocusRequester() }
    val tick by produceState(0L) { while (true) { value = System.currentTimeMillis() / 1000; delay(1000) } }
    BackHandler(enabled = tab != 0) { tab = 0; runCatching { todayFocus.requestFocus() } }
    LaunchedEffect(Unit) { runCatching { todayFocus.requestFocus() } }

    // Lay out on a fixed 1280 dp wide canvas so 720p, 1080p and 4K TVs show the same page.
    BoxWithConstraints(Modifier.fillMaxSize()) {
    val base = LocalDensity.current
    CompositionLocalProvider(LocalDensity provides Density(base.density * maxWidth.value / 1280f, base.fontScale)) {
    Box(
        Modifier.fillMaxSize().background(NL.ground)
            .onPreviewKeyEvent {
                if (it.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (it.key) {
                    Key.MediaPlayPause, Key.MediaPlay, Key.MediaPause -> { radio.toggle(); true }
                    Key.MediaFastForward, Key.MediaNext -> { radio.next(); true }
                    else -> false
                }
            }
    ) {
        Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Brush.radialGradient(
            listOf(NL.accent.copy(alpha = 0.22f), Color.Transparent),
            center = androidx.compose.ui.geometry.Offset(300f, 0f), radius = 1400f)))
        Column(Modifier.fillMaxSize().padding(horizontal = 48.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                tabs.forEachIndexed { i, name ->
                    TabButton(Lang.tr(name), selected = tab == i, if (i == 0) Modifier.focusRequester(todayFocus) else Modifier) { tab = i }
                }
            }
            when (tab) {
                0 -> {
                    Header(feed, radio, tick)
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(28.dp)) {
                        Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                            Lead(feed, lang, tick, Modifier.weight(1f))
                            Cards(feed, lang, tick, Modifier.height(170.dp))
                        }
                        Column(Modifier.width(440.dp).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Agenda(feed, tick, Modifier.weight(1f))
                            Spotlight(feed, tick, Modifier.fillMaxWidth().height(96.dp))
                            Text("</> " + Lang.tr("Open source on GitHub") + "  github.com/jQrgen/nordic-crypto-tv",
                                color = NL.textTertiary, fontSize = 11.sp, modifier = Modifier.align(Alignment.End))
                        }
                    }
                }
                1 -> TvBadge()
                else -> ContactScreen(large = true)
            }
        }
    }
    }
    }
}

/** A tab that is selected as soon as the remote moves focus onto it, like tvOS. */
@Composable
private fun TabButton(label: String, selected: Boolean, modifier: Modifier, onSelect: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(50)
    Text(
        label,
        color = if (focused) NL.ground else if (selected) NL.textPrimary else NL.textSecondary,
        fontSize = 17.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        modifier = modifier
            .onFocusChanged { focused = it.isFocused; if (it.isFocused) onSelect() }
            .clip(shape)
            .background(if (focused) NL.accent else if (selected) NL.raised else Color.Transparent)
            .clickable(onClick = onSelect)
            .padding(horizontal = 22.dp, vertical = 8.dp),
    )
}

@Composable
private fun RadioChip(radio: Radio) {
    var focused by remember { mutableStateOf(false) }
    Row(Modifier.onFocusChanged { focused = it.isFocused }.clip(RoundedCornerShape(50))
        .background(if (focused) NL.accent else NL.raised).clickable { radio.next() }
        .padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(if (radio.isOn) "🔊" else "🔇", fontSize = 14.sp)
        Column {
            Text(radio.station.name, color = if (focused) NL.ground else NL.textPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Text(Lang.tr(if (radio.isOn) "Press ⏯ to turn off" else "Press ⏯ to turn on"), color = if (focused) NL.ground else NL.textTertiary, fontSize = 11.sp)
        }
    }
}

private fun <T> rotate(list: List<T>, tick: Long, every: Long, offset: Long = 0): Pair<T, Int>? =
    if (list.isEmpty()) null else ((tick + offset) / every % list.size).toInt().let { list[it] to it }

@Composable
private fun Header(feed: Feed, radio: Radio, tick: Long) {
    val now = ZonedDateTime.now()
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
        Glyph(32.dp)
        Text("Nordic Crypto", color = NL.textPrimary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(Lang.longDate(now), color = NL.textSecondary, fontSize = 14.sp)
        Spacer(Modifier.weight(1f))
        Text("✈ Telegram ${Api.TELEGRAM_HANDLE}", color = NL.textSecondary, fontSize = 14.sp)
        RadioChip(radio)
        Text(Lang.time(now.toOffsetDateTime()), color = NL.textPrimary, fontSize = 34.sp, fontWeight = FontWeight.Bold,
            maxLines = 1, softWrap = false)
    }
}

@Composable
private fun Lead(feed: Feed, lang: String, tick: Long, modifier: Modifier) {
    val (item, index) = rotate(feed.news.take(5), tick, 15) ?: return
    Crossfade(item, modifier, animationSpec = tween(900), label = "lead") { story ->
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CountryChip(story.country, 15)
                SourceLogo(story.sourceName, feed.logo(story), 22.dp)
                Text(listOfNotNull(story.sourceName, Lang.stamp(story.publishedAt)).joinToString(" · "), color = NL.textSecondary, fontSize = 15.sp)
                Spacer(Modifier.weight(1f))
                Text("${index + 1} / ${feed.news.take(5).size}", color = NL.textTertiary, fontSize = 13.sp)
            }
            Text(story.headline(lang), color = NL.textPrimary, fontSize = 58.sp, lineHeight = 62.sp, fontFamily = NL.serif,
                fontWeight = FontWeight.Bold, maxLines = 3, overflow = TextOverflow.Ellipsis)
            story.originalHeadline(lang)?.let { Text(it, color = NL.textTertiary, fontSize = 16.sp, fontStyle = FontStyle.Italic, maxLines = 1) }
            Row(verticalAlignment = Alignment.Bottom) {
                story.summary(lang)?.let {
                    Text(it, color = NL.body, fontSize = 20.sp, lineHeight = 28.sp, maxLines = 3, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f))
                }
                story.url?.let { Spacer(Modifier.width(20.dp)); QrCode(it, 92.dp) }
            }
        }
    }
}

@Composable
private fun Cards(feed: Feed, lang: String, tick: Long, modifier: Modifier) {
    val pages = feed.news.drop(5).chunked(2)
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        val page = rotate(pages, tick, 14, 3)?.first.orEmpty()
        page.forEach { item ->
            Column(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(16.dp)).background(NL.panel).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SourceLogo(item.sourceName, feed.logo(item), 16.dp)
                    Text(listOfNotNull(item.country, item.sourceName).joinToString(" · "), color = NL.country(item.country),
                        fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                }
                Text(item.headline(lang), color = NL.textPrimary, fontSize = 19.sp, lineHeight = 23.sp, fontFamily = NL.serif,
                    fontWeight = FontWeight.SemiBold, maxLines = 4, overflow = TextOverflow.Ellipsis)
            }
        }
        feed.issues.firstOrNull()?.let { latest ->
            val issue = feed.issueDetails[latest.id] ?: latest
            Row(Modifier.width(290.dp).fillMaxHeight().clip(RoundedCornerShape(16.dp)).background(Color(0xFF1A1830)).padding(14.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(Modifier.weight(1f)) {
                    Text("No. ${issue.number ?: 0}", color = NL.accent2, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(issue.title(lang), color = NL.textPrimary, fontSize = 15.sp, fontFamily = NL.serif, maxLines = 4, overflow = TextOverflow.Ellipsis)
                }
                QrCode(Api.SUBSCRIBE, 64.dp)
            }
        }
    }
}

@Composable
private fun Agenda(feed: Feed, tick: Long, modifier: Modifier) {
    val events = feed.upcoming
    Column(modifier.clip(RoundedCornerShape(20.dp)).background(NL.aside).padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(Lang.tr("Coming up"), color = NL.textPrimary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            Text(Lang.tr("%lld events", events.size), color = NL.textTertiary, fontSize = 13.sp)
        }
        if (events.isEmpty()) { Text(Lang.tr("No upcoming events"), color = NL.textTertiary); return@Column }
        val i = rotate(events.indices.toList(), tick, 15, 7)!!.first
        val f = events[i]
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(NL.raised).padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(56.dp)) {
                Text(Lang.dayNumber(f.startAt), color = NL.textPrimary, fontSize = 34.sp, fontWeight = FontWeight.Bold)
                Text(Lang.month(f.startAt), color = NL.country(f.country), fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            Column(Modifier.weight(1f)) {
                Text(listOfNotNull(Lang.weekdayShort(f.startAt), Lang.time(f.startAt) + (f.endAt?.let { "–" + Lang.time(it) } ?: ""))
                    .joinToString(" · ") + (f.going?.takeIf { it > 0 }?.let { " · " + Lang.tr("%lld going", it) } ?: ""),
                    color = NL.accent, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                Text(f.title, color = NL.textPrimary, fontSize = 20.sp, fontFamily = NL.serif, fontWeight = FontWeight.Bold, maxLines = 2)
                Text(listOfNotNull(f.city, f.organiser).joinToString(" · "), color = NL.textSecondary, fontSize = 12.sp, maxLines = 1)
            }
            f.url?.let { QrCode(it, 70.dp) }
        }
        (1 until minOf(7, events.size)).forEach { k ->
            val e = events[(i + k) % events.size]
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(vertical = 2.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(44.dp)) {
                    Text(Lang.dayNumber(e.startAt), color = NL.textPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text(Lang.month(e.startAt), color = NL.country(e.country), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Column(Modifier.weight(1f)) {
                    Text(e.title, color = NL.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(listOfNotNull(e.city, Lang.time(e.startAt), e.organiser).joinToString(" · "), color = NL.textTertiary, fontSize = 11.sp, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun Spotlight(feed: Feed, tick: Long, modifier: Modifier) {
    val (item, _) = rotate(feed.spotlight, tick, 12, 5) ?: return
    val e = (item as SpotlightItem.Entity).e
    val image = e.image ?: e.logo
    Column(modifier.clip(RoundedCornerShape(18.dp)).background(NL.panel).padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val photo = rememberRemoteImage(image?.displayableUrl)
            if (photo != null) {
                androidx.compose.foundation.Image(photo, null, Modifier.size(52.dp).clip(if (e.isPerson) circle() else RoundedCornerShape(12.dp))
                    .background(if (e.isPerson) Color.Transparent else Color.White),
                    contentScale = if (e.isPerson) androidx.compose.ui.layout.ContentScale.Crop else androidx.compose.ui.layout.ContentScale.Fit)
            } else SourceLogo(e.name, null, 52.dp, if (e.isPerson) circle() else RoundedCornerShape(12.dp))
            Column {
                val kind = when { e.isPerson -> "Person"; e.sector == "public" -> "Public body"; else -> "Company" }
                Text("${Lang.tr("Spotlight")} · ${Lang.tr(kind)} · ${e.country ?: ""}", color = NL.accent2, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text(e.name, color = NL.textPrimary, fontSize = 17.sp, fontFamily = NL.serif, fontWeight = FontWeight.Bold, maxLines = 1)
                val org = e.org?.let { feed.entities[it]?.name }
                Text(listOfNotNull(e.role, org ?: e.group).joinToString(" · "), color = NL.textSecondary, fontSize = 11.sp, maxLines = 1)
            }
        }
        image?.takeIf { it.displayableUrl != null && it.license?.lowercase() != "public domain" }?.creditLine?.let {
            Text(Lang.tr(if (e.image != null) "Photo: %@" else "Logo: %@", it), color = NL.textTertiary, fontSize = 9.sp, maxLines = 1)
        }
    }
}
