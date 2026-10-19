package no.cryptonordic.app

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.OffsetDateTime

/** Everything the screens show, from the network, a cached copy or the bundled snapshot. */
data class Feed(
    val news: List<NewsItem> = emptyList(),
    val events: List<EventItem> = emptyList(),
    val issues: List<NewsletterIssue> = emptyList(),
    val issueDetails: Map<String, NewsletterIssue> = emptyMap(),
    val sourceLogos: Map<String, String> = emptyMap(),
    val spotlight: List<SpotlightItem> = emptyList(),
    val entities: Map<String, OrgEntity> = emptyMap(),
    val updated: OffsetDateTime? = null,
    val live: Boolean = false,
) {
    val upcoming get() = Agenda.upcoming(events)
    fun inCountry(c: Country) = news.filter { it.country == c.code }
    fun logo(item: NewsItem) = item.sourceLogoUrl ?: item.source?.let { sourceLogos[it] }
}

sealed interface SpotlightItem {
    val key: String
    data class Entity(val e: OrgEntity) : SpotlightItem { override val key = "e-" + e.id }
}

object Api {
    val bases = listOf(
        "https://nordiccrypto.no/api/v1/",
        "https://cryptonordic.no/api/v1/",
        "https://raw.githubusercontent.com/jQrgen/nordic-crypto/gh-pages/api/v1/",
    )
    const val TELEGRAM = "https://t.me/nordiccryptochat"
    const val TELEGRAM_HANDLE = "@nordiccryptochat"
    const val SUBSCRIBE = "https://cryptonordic.substack.com/subscribe"
    const val SOURCE_CODE = "https://github.com/nordic-crypto-org/nordic-crypto-tv"
    /** News publisher shown on the Contact us screen and in the Play listing. */
    const val PUBLISHER = "Nordic Crypto"
    const val PUBLISHER_COMPANY = "jQrgenCorp"
    const val PUBLISHER_ORG_NO = "org.nr. 919 057 343"
    const val CONTACT_EMAIL = "jqrgen@nordiccrypto.no"
    const val CONTACT_MAILTO = "mailto:jqrgen@nordiccrypto.no"
    const val WEBSITE = "https://nordiccrypto.no"
    const val CONTACT_PAGE = "https://nordiccrypto.no/contact/"

    val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; explicitNulls = false }

    /** Live document, trying each base in turn; the last good copy is cached. */
    suspend fun fetch(context: Context, path: String): String? = withContext(Dispatchers.IO) {
        for (base in bases) {
            val text = runCatching {
                val c = URL(base + path).openConnection() as HttpURLConnection
                c.connectTimeout = 10_000; c.readTimeout = 15_000
                c.setRequestProperty("User-Agent", "NordicCrypto-Android/1.1")
                if (c.responseCode != 200) null else c.inputStream.bufferedReader().use { it.readText() }
            }.getOrNull()
            if (text != null) {
                runCatching { cacheFile(context, path).writeText(text) }
                return@withContext text
            }
        }
        null
    }

    fun offline(context: Context, path: String): String? =
        cacheFile(context, path).takeIf { it.exists() }?.readText()
            ?: runCatching { context.assets.open("snapshot/$path").bufferedReader().use { it.readText() } }.getOrNull()

    private fun cacheFile(context: Context, path: String) = File(context.cacheDir, "api-v1-" + path.replace("/", "-"))
}

class Store(private val context: Context) {
    private val _feed = MutableStateFlow(Feed())
    val feed: StateFlow<Feed> = _feed.asStateFlow()
    private val shuffleSeed = System.nanoTime()

    init { _feed.value = build(::offline, live = false) }

    private fun offline(path: String) = Api.offline(context, path)

    suspend fun run() {
        while (true) {
            refresh()
            delay(10 * 60 * 1000L)
        }
    }

    suspend fun refresh() {
        val paths = listOf("news.json", "events.json", "newsletters.json", "sources.json", "orgchart.json")
        val fetched = paths.associateWith { Api.fetch(context, it) }
        val live = fetched["news.json"] != null
        val issues = runCatching { Api.json.decodeFromString<NewslettersFeed>(fetched["newsletters.json"] ?: offline("newsletters.json")!!) }.getOrNull()
        issues?.issues?.firstOrNull()?.let { Api.fetch(context, "newsletters/${it.id}.json") }
        _feed.value = build({ fetched[it] ?: offline(it) }, live)
        if (live) Alerts.process(context, _feed.value.news)
    }

    private fun build(read: (String) -> String?, live: Boolean): Feed {
        fun <T> parse(path: String, f: (String) -> T): T? = read(path)?.let { runCatching { f(it) }.getOrNull() }
        val news = parse("news.json") { Api.json.decodeFromString<NewsFeed>(it) }
        val events = parse("events.json") { Api.json.decodeFromString<EventsFeed>(it) }?.events.orEmpty()
        val issues = parse("newsletters.json") { Api.json.decodeFromString<NewslettersFeed>(it) }?.issues.orEmpty()
            .sortedByDescending { it.number ?: 0 }
        val details = issues.mapNotNull { i ->
            parse("newsletters/${i.id}.json") { Api.json.decodeFromString<NewsletterEnvelope>(it) }?.item?.let { i.id to it }
        }.toMap()
        val sources = parse("sources.json") { Api.json.decodeFromString<SourcesFeed>(it) }?.sources.orEmpty()
        val org = parse("orgchart.json") { Api.json.decodeFromString<OrgChartFeed>(it) }?.entities.orEmpty()
        return Feed(
            news = News.recent(news?.items.orEmpty()).sortedByDescending { it.publishedAt },
            events = events,
            issues = issues,
            issueDetails = details,
            sourceLogos = sources.mapNotNull { s -> s.logoUrl?.let { s.id to it } }.toMap(),
            spotlight = org.map { SpotlightItem.Entity(it) }.shuffled(java.util.Random(shuffleSeed)),
            entities = org.associateBy { it.id },
            updated = news?.updated?.let { runCatching { OffsetDateTime.parse(it) }.getOrNull() },
            live = live,
        )
    }
}
