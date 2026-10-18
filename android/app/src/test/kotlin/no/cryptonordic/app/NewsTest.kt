package no.cryptonordic.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.OffsetDateTime

class NewsTest {
    private val now = OffsetDateTime.parse("2026-10-18T12:00:00+02:00")

    private fun n(id: String, published: String?) = NewsItem(id = id, title = id, published = published)

    @Test fun olderThan90DaysOrUndatedIsHidden() {
        val list = listOf(
            n("new", "2026-10-17T17:43:46+00:00"),
            n("edge", "2026-07-20T10:30:00+00:00"),
            n("old", "2026-07-20T09:59:59+00:00"),
            n("ancient", "2025-01-01T00:00:00Z"),
            n("day", "2026-10-15"),
            n("bad", "yesterday"),
            n("none", null),
        )
        assertEquals(listOf("new", "edge", "day"), News.recent(list, now).map { it.id })
    }

    @Test fun bundledSnapshotIsRecentAndEventsUpcoming() {
        val dir = File("src/main/assets/snapshot")
        val news = Api.json.decodeFromString<NewsFeed>(File(dir, "news.json").readText()).items
        val updated = news.mapNotNull { it.publishedAt }.max()
        assertTrue(news.isNotEmpty())
        assertEquals(news.map { it.id }, News.recent(news, updated).map { it.id })
        val events = Api.json.decodeFromString<EventsFeed>(File(dir, "events.json").readText()).events
        assertTrue(events.none { it.past == true })
    }
}
