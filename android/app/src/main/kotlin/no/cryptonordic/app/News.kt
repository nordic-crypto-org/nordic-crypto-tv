package no.cryptonordic.app

import java.time.OffsetDateTime

object News {
    /** Google Play News policy: no stories older than this, by published date. */
    const val MAX_AGE_DAYS = 90L

    fun recent(items: List<NewsItem>, now: OffsetDateTime = OffsetDateTime.now()): List<NewsItem> {
        val cutoff = now.minusDays(MAX_AGE_DAYS)
        return items.filter { it.publishedAt?.isAfter(cutoff) == true }
    }
}
