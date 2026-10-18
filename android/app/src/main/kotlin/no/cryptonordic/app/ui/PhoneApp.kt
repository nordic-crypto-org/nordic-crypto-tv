package no.cryptonordic.app.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import no.cryptonordic.app.*

private sealed interface Route {
    data class Story(val item: NewsItem) : Route
    data class Event(val event: EventItem) : Route
    data class Reader(val issue: NewsletterIssue) : Route
}

private enum class Tab(val key: String, val icon: String) {
    TODAY("Today", "☀"), COUNTRIES("Countries", "◎"), EVENTS("Events", "▦"), NEWSLETTER("Newsletter", "✉"),
    CONTACT("Contact us", "☎"),
}

@Composable
fun PhoneApp(store: Store, openStory: String?) {
    val feed by store.feed.collectAsState()
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    val stack = remember { mutableStateListOf<Route>() }
    var showAlerts by remember { mutableStateOf(false) }
    val lang = Lang.current

    LaunchedEffect(openStory, feed.news.size) {
        feed.news.firstOrNull { it.id == openStory }?.let { tab = Tab.TODAY; stack.clear(); stack.add(Route.Story(it)) }
    }
    BackHandler(enabled = stack.isNotEmpty()) { stack.removeAt(stack.lastIndex) }

    MaterialTheme(colorScheme = darkColorScheme(primary = NL.accent, background = NL.bg, surface = NL.panel)) {
        Surface(color = NL.bg, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().systemBarsPadding()) {
                Box(Modifier.weight(1f)) {
                    when (val top = stack.lastOrNull()) {
                        is Route.Story -> StoryDetail(top.item, feed, lang) { stack.removeAt(stack.lastIndex) }
                        is Route.Event -> EventDetail(top.event, lang) { stack.removeAt(stack.lastIndex) }
                        is Route.Reader -> Reader(top.issue, lang) { stack.removeAt(stack.lastIndex) }
                        null -> when (tab) {
                            Tab.TODAY -> Today(feed, lang, { stack.add(it) }, { tab = Tab.EVENTS }, { showAlerts = true })
                            Tab.COUNTRIES -> Countries(feed, lang) { stack.add(Route.Story(it)) }
                            Tab.EVENTS -> Events(feed, lang) { stack.add(Route.Event(it)) }
                            Tab.NEWSLETTER -> Newsletter(feed, lang) { stack.add(Route.Reader(it)) }
                            Tab.CONTACT -> ContactScreen(large = false)
                        }
                    }
                }
                if (stack.isEmpty()) {
                    NavigationBar(containerColor = NL.panel) {
                        Tab.entries.forEach { t ->
                            NavigationBarItem(selected = tab == t, onClick = { tab = t },
                                icon = { Text(t.icon, fontSize = 20.sp) },
                                label = { Text(Lang.tr(t.key), maxLines = 1) })
                        }
                    }
                }
            }
            if (showAlerts) AlertSettings(dismiss = { showAlerts = false }, openContact = { showAlerts = false; tab = Tab.CONTACT })
        }
    }
}

// MARK: Today

@Composable
private fun Today(feed: Feed, lang: String, open: (Route) -> Unit, allEvents: () -> Unit, alerts: () -> Unit) {
    val ctx = LocalContext.current
    val top = feed.news.take(3)
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(Lang.tr("Today"), color = NL.textPrimary, fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.TELEGRAM))) }) { Text("✈", color = NL.telegram, fontSize = 20.sp) }
                TextButton(onClick = alerts) { Text("🔔", fontSize = 18.sp) }
            }
            StatusPill(feed)
        }
        top.firstOrNull()?.let { lead -> item { LeadCard(lead, feed, lang) { open(Route.Story(lead)) } } }
        if (feed.upcoming.isNotEmpty()) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionTitle(Lang.tr("Coming up"))
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = allEvents) { Text(Lang.tr("All")) }
                }
                LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(feed.upcoming.take(8)) { e -> EventMini(e, lang, Modifier.width(280.dp)) { open(Route.Event(e)) } }
                }
            }
        }
        if (top.size > 1) {
            item { SectionTitle(Lang.tr("Top stories")) }
            items(top.drop(1)) { NewsRow(it, feed, lang) { open(Route.Story(it)) } }
        }
        feed.issues.firstOrNull()?.let { issue ->
            item { NewsletterCard(feed.issueDetails[issue.id] ?: issue, lang) { open(Route.Reader(feed.issueDetails[issue.id] ?: issue)) } }
        }
        item { SectionTitle(Lang.tr("More news") + "  " + (feed.news.size - 3).coerceAtLeast(0)) }
        items(feed.news.drop(3)) { NewsRow(it, feed, lang) { open(Route.Story(it)) } }
        item { TelegramCard() }
        item {
            Text("</> " + Lang.tr("Open source on GitHub"), color = NL.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.SOURCE_CODE))) }.padding(vertical = 4.dp))
        }
        item {
            Text(Lang.tr("Not investment advice · Headlines © their publishers · Summaries by Nordic Crypto"),
                color = NL.textTertiary, fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp))
        }
    }
}

@Composable
private fun StatusPill(feed: Feed) {
    val label = if (feed.live || feed.updated != null) Lang.tr("Updated %@", Lang.time(feed.updated)) else Lang.tr("Offline · showing saved news")
    Row(Modifier.padding(top = 4.dp).background(Color(0x14FFFFFF), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).background(if (feed.live) NL.accent else NL.textTertiary, RoundedCornerShape(50)))
        Spacer(Modifier.width(6.dp))
        Text(label, color = NL.textSecondary, fontSize = 12.sp)
    }
}

@Composable
private fun SectionTitle(text: String) =
    Text(text, color = NL.textPrimary, fontSize = 22.sp, fontWeight = FontWeight.Bold)

@Composable
private fun Kicker(item: NewsItem, feed: Feed) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        CountryChip(item.country)
        SourceLogo(item.sourceName, feed.logo(item), 18.dp)
        Text(listOfNotNull(item.sourceName, Lang.stamp(item.publishedAt)).joinToString(" · "),
            color = NL.textSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (item.paywall == true) Text("🔒", fontSize = 11.sp)
    }
}

@Composable
private fun LeadCard(item: NewsItem, feed: Feed, lang: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(420.dp).clip(RoundedCornerShape(20.dp)).clickable(onClick = onClick)) {
        AuroraArt(item.id, NL.country(item.country), NL.topic(item.topics.firstOrNull()), Modifier.matchParentSize())
        Column(Modifier.align(Alignment.BottomStart).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Kicker(item, feed)
            Text(item.headline(lang), color = NL.textPrimary, fontSize = 30.sp, lineHeight = 34.sp,
                fontWeight = FontWeight.Bold, fontFamily = NL.serif, maxLines = 4, overflow = TextOverflow.Ellipsis)
            item.originalHeadline(lang)?.let { Text(it, color = NL.textSecondary, fontSize = 14.sp, fontStyle = FontStyle.Italic, maxLines = 1) }
        }
    }
}

@Composable
private fun NewsRow(item: NewsItem, feed: Feed, lang: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(NL.panel).clickable(onClick = onClick)) {
        Box(Modifier.width(4.dp).height(96.dp).background(NL.country(item.country)))
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Kicker(item, feed)
            Text(item.headline(lang), color = NL.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                fontFamily = NL.serif, maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun DateTile(e: EventItem, size: Int = 56) {
    Column(Modifier.size(size.dp).background(NL.country(e.country).copy(alpha = 0.15f), RoundedCornerShape(14.dp)),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(Lang.dayNumber(e.startAt), color = NL.textPrimary, fontSize = (size * 0.42).sp, fontWeight = FontWeight.Bold)
        Text(Lang.month(e.startAt), color = NL.country(e.country), fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

private fun entry(e: EventItem): Pair<String, Color>? = when {
    e.sponsored != null -> Lang.tr("Sponsored") to NL.warning
    e.online == true -> Lang.tr("Online") to NL.accent2
    e.paid == true -> Lang.tr("Paid") to NL.textSecondary
    e.paid == false -> Lang.tr("Free") to NL.accent
    else -> null
}

@Composable
private fun EventMini(e: EventItem, lang: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(modifier.clip(RoundedCornerShape(16.dp)).background(NL.panel).clickable(onClick = onClick).padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        DateTile(e)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(e.title, color = NL.textPrimary, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(listOfNotNull(if (e.online == true) Lang.tr("Online") else e.city, Lang.time(e.startAt)).joinToString(" · "),
                color = NL.textSecondary, fontSize = 12.sp)
            e.going?.takeIf { it > 0 }?.let { Text("👥 " + Lang.tr("%lld going", it), color = NL.accent, fontSize = 12.sp) }
        }
    }
}

@Composable
private fun NewsletterCard(issue: NewsletterIssue, lang: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(20.dp)).clickable(onClick = onClick)) {
        AuroraArt(issue.id, NL.accent2, NL.accent, Modifier.matchParentSize())
        Column(Modifier.align(Alignment.BottomStart).padding(16.dp)) {
            Text("No. ${issue.number ?: 0} · ${issue.date ?: ""}", color = NL.accent2, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            Text(issue.title(lang), color = NL.textPrimary, fontSize = 20.sp, fontFamily = NL.serif, fontWeight = FontWeight.SemiBold, maxLines = 2)
        }
    }
}

@Composable
private fun TelegramCard() {
    val ctx = LocalContext.current
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(NL.panel)
        .clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.TELEGRAM))) }.padding(14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(48.dp).background(NL.telegram, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            Text("✈", color = Color.White, fontSize = 22.sp)
        }
        Column(Modifier.weight(1f)) {
            Text(Lang.tr("Join the Nordic Crypto chat on Telegram"), color = NL.textPrimary, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(Api.TELEGRAM_HANDLE, color = NL.textSecondary, fontSize = 13.sp)
        }
        Text("↗", color = NL.textTertiary)
    }
}

// MARK: Countries, Events, Newsletter

@Composable
private fun Countries(feed: Feed, lang: String, open: (NewsItem) -> Unit) {
    var selected by rememberSaveable { mutableStateOf(Country.NO) }
    val items = feed.inCountry(selected)
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text(Lang.tr("Countries"), color = NL.textPrimary, fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Country.entries.forEach { c ->
                    FilterChip(selected = c == selected, onClick = { selected = c },
                        label = { Text("${c.code} ${feed.inCountry(c).size}") })
                }
            }
        }
        item {
            Box(Modifier.fillMaxWidth().height(130.dp).clip(RoundedCornerShape(20.dp))) {
                AuroraArt(selected.code, NL.country(selected.code), NL.accent2, Modifier.matchParentSize())
                Text(selected.localName, color = NL.textPrimary, fontSize = 26.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.align(Alignment.BottomStart).padding(16.dp))
            }
        }
        if (items.isEmpty()) item { Text(Lang.tr("Quiet in %@ — no stories this week", selected.localName), color = NL.textTertiary) }
        items(items) { NewsRow(it, feed, lang) { open(it) } }
    }
}

@Composable
private fun Events(feed: Feed, lang: String, open: (EventItem) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text(Lang.tr("Events"), color = NL.textPrimary, fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif) }
        if (feed.upcoming.isEmpty()) item { Text(Lang.tr("No upcoming events"), color = NL.textTertiary) }
        items(feed.upcoming) { e ->
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(NL.panel).clickable { open(e) }.padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                DateTile(e)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(e.title, color = NL.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, fontFamily = NL.serif)
                    Text(listOfNotNull(if (e.online == true) Lang.tr("Online") else e.city, Lang.time(e.startAt), e.organiser).joinToString(" · "),
                        color = NL.textTertiary, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    e.going?.takeIf { it > 0 }?.let { Text("👥 " + Lang.tr("%lld going", it), color = NL.accent, fontSize = 12.sp) }
                }
                entry(e)?.let { (label, color) -> Text(label, color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                CountryChip(e.country)
            }
        }
    }
}

@Composable
private fun Newsletter(feed: Feed, lang: String, open: (NewsletterIssue) -> Unit) {
    val ctx = LocalContext.current
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { Text(Lang.tr("Newsletter"), color = NL.textPrimary, fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif) }
        if (feed.issues.isEmpty()) item { Text(Lang.tr("No issues yet"), color = NL.textTertiary) }
        items(feed.issues) { i ->
            val full = feed.issueDetails[i.id] ?: i
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(NL.panel).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("No. ${i.number ?: 0} · ${i.date ?: ""}", color = NL.accent2, fontWeight = FontWeight.Bold)
                Text(full.title(lang), color = NL.textPrimary, fontSize = 24.sp, fontFamily = NL.serif, fontWeight = FontWeight.Bold)
                full.subtitle(lang)?.let { Text(it, color = NL.textSecondary) }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (full.text(lang) != null) Button(onClick = { open(full) }) { Text(Lang.tr("Read issue")) }
                    OutlinedButton(onClick = { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.SUBSCRIBE))) }) { Text(Lang.tr("Subscribe")) }
                }
            }
        }
    }
}

// MARK: Details

@Composable
private fun BackRow(title: String, back: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = back) { Text(if (LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl) "→" else "←", fontSize = 22.sp, color = NL.textPrimary) }
        Text(title, color = NL.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun SourceButtons(url: String?, label: String) {
    val ctx = LocalContext.current
    url ?: return
    Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Button(onClick = { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }, modifier = Modifier.weight(1f)) { Text(label) }
        OutlinedButton(onClick = {
            ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, url), null))
        }) { Text(Lang.tr("Share")) }
    }
}

@Composable
private fun StoryDetail(item: NewsItem, feed: Feed, lang: String, back: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        BackRow(item.sourceName ?: "", back)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(20.dp))) {
                AuroraArt(item.id, NL.country(item.country), NL.topic(item.topics.firstOrNull()), Modifier.matchParentSize())
            }
            Kicker(item, feed)
            Text(item.headline(lang), color = NL.textPrimary, fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif)
            item.originalHeadline(lang)?.let { Text(it, color = NL.textSecondary, fontStyle = FontStyle.Italic) }
            item.summary(lang)?.let {
                Column(Modifier.fillMaxWidth().background(NL.panel, RoundedCornerShape(16.dp)).padding(16.dp)) {
                    Text(Lang.tr("Nordic Crypto summary"), color = NL.accent, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(Modifier.height(6.dp))
                    Text(it, color = NL.textPrimary, fontSize = 17.sp, lineHeight = 24.sp)
                }
            }
            if (item.paywall == true) Text("🔒 " + Lang.tr("The source may require a subscription"), color = NL.warning, fontSize = 13.sp)
            Text(Lang.tr("Headline © %@. Summary by the Nordic Crypto team. Not investment advice.", item.sourceName ?: Lang.tr("the publisher")),
                color = NL.textTertiary, fontSize = 12.sp)
        }
        SourceButtons(item.url, Lang.tr("Read at %@", item.sourceName ?: "source"))
    }
}

@Composable
private fun EventDetail(e: EventItem, lang: String, back: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        BackRow(e.city ?: "", back)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                DateTile(e, 72)
                Text(e.title, color = NL.textPrimary, fontSize = 28.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif)
            }
            Column(Modifier.fillMaxWidth().background(NL.panel, RoundedCornerShape(16.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Info(Lang.tr("When"), listOfNotNull(Lang.day(e.startAt), Lang.time(e.startAt) + (e.endAt?.let { "–" + Lang.time(it) } ?: "")).joinToString(" · "))
                Info(Lang.tr("Where"), if (e.online == true) Lang.tr("Online") else e.place ?: e.city ?: "")
                e.organiser?.let { Info(Lang.tr("Organiser"), it) }
                e.going?.takeIf { it > 0 }?.let { Info("👥", Lang.tr("%lld going", it)) }
                e.sponsored?.takeIf { it.isNotBlank() }?.let { Info(Lang.tr("Sponsor"), it) }
                (e.noteI18n.localized(lang) ?: e.note)?.let { Info(Lang.tr("Note"), it) }
            }
        }
        SourceButtons(e.url, Lang.tr("Open event page"))
    }
}

@Composable
private fun Info(label: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(label, color = NL.textTertiary, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(96.dp))
        Text(value, color = NL.textPrimary)
    }
}

@Composable
private fun Reader(issue: NewsletterIssue, lang: String, back: () -> Unit) {
    val paragraphs = (issue.text(lang) ?: "").split("\n\n").map { it.trim() }.filter { it.isNotEmpty() }
    Column(Modifier.fillMaxSize()) {
        BackRow(issue.title(lang), back)
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text(issue.title(lang), color = NL.textPrimary, fontSize = 30.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif) }
            items(paragraphs) { p ->
                val heading = p.length < 110 && !p.contains('\n') && !p.endsWith('.')
                Text(p, color = if (heading) NL.textPrimary else NL.textSecondary,
                    fontSize = if (heading) 20.sp else 17.sp, lineHeight = if (heading) 26.sp else 26.sp,
                    fontWeight = if (heading) FontWeight.SemiBold else FontWeight.Normal, fontFamily = NL.serif)
            }
        }
    }
}

// MARK: Notifications

@Composable
private fun AlertSettings(dismiss: () -> Unit, openContact: () -> Unit) {
    val ctx = LocalContext.current
    var enabled by remember { mutableStateOf(Alerts.enabled(ctx)) }
    var countries by remember { mutableStateOf(Alerts.countries(ctx)) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        Alerts.setEnabled(ctx, granted); enabled = granted
    }
    AlertDialog(
        onDismissRequest = dismiss,
        confirmButton = { TextButton(onClick = dismiss) { Text(Lang.tr("Done")) } },
        dismissButton = { TextButton(onClick = openContact) { Text(Lang.tr("Contact us")) } },
        title = { Text(Lang.tr("Notifications")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(Lang.tr("Notify me about new stories"), Modifier.weight(1f))
                    Switch(checked = enabled, onCheckedChange = { on ->
                        if (on && Build.VERSION.SDK_INT >= 33 && !Alerts.canNotify(ctx)) {
                            permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else { Alerts.setEnabled(ctx, on); enabled = on }
                    })
                }
                Text(Lang.tr("Countries"), fontWeight = FontWeight.Bold)
                Country.entries.forEach { c ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CountryChip(c.code); Spacer(Modifier.width(10.dp))
                        Text(c.localName, Modifier.weight(1f))
                        Checkbox(checked = c.code in countries, enabled = enabled,
                            onCheckedChange = { Alerts.toggle(ctx, c); countries = Alerts.countries(ctx) })
                    }
                }
                if (Push.configured) {
                    Text(Lang.tr("New stories arrive as push notifications, delivered by Apple or Google. Our push server keeps only this device's push token, the countries you pick and your language. Turning notifications off deletes them."),
                        style = MaterialTheme.typography.bodySmall)
                }
            }
        },
    )
}
