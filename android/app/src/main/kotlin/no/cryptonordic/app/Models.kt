package no.cryptonordic.app

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.OffsetDateTime
import java.time.LocalDate

// Types for the Nordic Crypto data API v1. New fields may appear at any time,
// so everything but ids and titles is optional and unknown keys are ignored.

@Serializable
data class NewsFeed(val items: List<NewsItem> = emptyList(), val updated: String? = null)

@Serializable
data class NewsItem(
    val id: String,
    val title: String,
    val url: String? = null,
    @SerialName("title_en") val titleEn: String? = null,
    val source: String? = null,
    @SerialName("source_name") val sourceName: String? = null,
    @SerialName("source_logo_url") val sourceLogoUrl: String? = null,
    val country: String? = null,
    @SerialName("language_code") val languageCode: String? = null,
    val published: String? = null,
    val topics: List<String> = emptyList(),
    val summary: String? = null,
    @SerialName("summary_i18n") val summaryI18n: Map<String, String> = emptyMap(),
    @SerialName("title_i18n") val titleI18n: Map<String, String> = emptyMap(),
    val paywall: Boolean? = false,
) {
    val publishedAt: OffsetDateTime? get() = published?.let { runCatching { OffsetDateTime.parse(it) }.getOrNull() }

    /** Headline in the reader's language (nynorsk, then bokmål), else English. */
    fun headline(lang: String): String =
        (titleI18n + listOfNotNull(titleEn?.let { "en" to it })).localized(lang, title, languageCode) ?: title

    fun summary(lang: String): String? = summaryI18n.localized(lang, summary)
}

@Serializable
data class EventsFeed(val events: List<EventItem> = emptyList())

@Serializable
data class EventItem(
    val id: String,
    val title: String,
    val start: String? = null,
    val end: String? = null,
    val place: String? = null,
    val city: String? = null,
    val country: String? = null,
    val online: Boolean? = false,
    val organiser: String? = null,
    val url: String? = null,
    val paid: Boolean? = null,
    val sponsored: String? = null,
    val note: String? = null,
    @SerialName("note_i18n") val noteI18n: Map<String, String> = emptyMap(),
    val past: Boolean? = false,
    val going: Int? = null,
    @SerialName("title_original") val titleOriginal: String? = null,
    val description: EventDescription? = null,
) {
    fun note(lang: String): String? = noteI18n.localized(lang, note)
    val startAt: OffsetDateTime? get() = at(start)
    val endAt: OffsetDateTime? get() = at(end)
    /** A date without a time is a whole day. */
    val allDay: Boolean get() = start != null && 'T' !in start
    /** When the event is over; without an end, a whole day or three hours. */
    val finish: OffsetDateTime? get() = startAt?.let { endAt ?: it.plusHours(if (allDay) 24 else 3) }

    /** The organiser's own title when it is in the reader's language. */
    fun title(lang: String) = titleOriginal?.takeIf { description?.lang?.let { l -> Lang.sameFamily(l, lang) } == true } ?: title

    private fun at(s: String?): OffsetDateTime? = s?.let {
        runCatching { OffsetDateTime.parse(it) }.getOrNull()
            ?: runCatching { LocalDate.parse(it).atStartOfDay().atOffset(java.time.ZoneOffset.UTC) }.getOrNull()
    }
}

@Serializable
data class EventDescription(val lang: String? = null)

@Serializable
data class NewslettersFeed(val issues: List<NewsletterIssue> = emptyList())

@Serializable
data class NewsletterEnvelope(val item: NewsletterIssue)

@Serializable
data class NewsletterIssue(
    val id: String,
    val title: String,
    val number: Int? = null,
    val date: String? = null,
    val subtitle: String? = null,
    @SerialName("title_i18n") val titleI18n: Map<String, String> = emptyMap(),
    @SerialName("subtitle_i18n") val subtitleI18n: Map<String, String> = emptyMap(),
    @SerialName("html_url") val htmlUrl: String? = null,
    val text: String? = null,
    @SerialName("text_i18n") val textI18n: Map<String, String> = emptyMap(),
) {
    fun title(lang: String) = titleI18n.localized(lang, title) ?: title
    fun subtitle(lang: String) = subtitleI18n.localized(lang, subtitle)
    fun text(lang: String) = textI18n.localized(lang, text)
    val day: LocalDate? get() = date?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
}

@Serializable
data class OrgChartFeed(val entities: List<OrgEntity> = emptyList())

@Serializable
data class OrgEntity(
    val id: String,
    val name: String,
    val type: String? = null,
    val sector: String? = null,
    val country: String? = null,
    val description: String? = null,
    val role: String? = null,
    val org: String? = null,
    val group: String? = null,
    val logo: CreditedImage? = null,
    val image: CreditedImage? = null,
) {
    val isPerson get() = type == "person"
}

@Serializable
data class CreditedImage(
    @SerialName("file_url") val fileUrl: String? = null,
    val author: String? = null,
    val license: String? = null,
    val credit: String? = null,
) {
    /** Android cannot decode SVG with BitmapFactory; those fall back to a monogram. */
    val displayableUrl: String? get() = fileUrl?.takeUnless { it.lowercase().endsWith(".svg") }
    val creditLine: String? get() = listOfNotNull(author, license, credit).filter { it.isNotBlank() }
        .joinToString(" · ").ifBlank { null }
}

@Serializable
data class SourcesFeed(val sources: List<Source> = emptyList()) {
    @Serializable
    data class Source(val id: String, val name: String? = null, @SerialName("logo_url") val logoUrl: String? = null)
}

enum class Country(val code: String, val englishName: String) {
    NO("NO", "Norway"), SE("SE", "Sweden"), DK("DK", "Denmark"), FI("FI", "Finland"), IS("IS", "Iceland");

    val localName: String get() = Lang.tr(englishName)

    companion object {
        fun of(code: String?) = entries.firstOrNull { it.code == code }
    }
}
