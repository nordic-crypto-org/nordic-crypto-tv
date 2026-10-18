package no.cryptonordic.app

import java.text.Normalizer
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** The TV calendar: upcoming events once each, in date order, in pages that fit the panel. */
object Agenda {
    const val ROWS = 5

    /** Drops ended events (stale snapshot or cache) and the same event listed twice, then sorts by start. */
    fun upcoming(events: List<EventItem>, now: OffsetDateTime = OffsetDateTime.now()): List<EventItem> {
        val seen = HashSet<String>()
        return events.filter { it.past != true && it.finish?.isAfter(now) == true }
            .sortedWith(compareBy({ it.startAt!!.toInstant() }, { it.title }))
            .filter { seen.add(it.id) && seen.add(key(it)) }
    }

    fun pages(events: List<EventItem>) = events.chunked(ROWS)

    /** Same title on the same day is the same event. */
    fun key(e: EventItem): String =
        Normalizer.normalize(e.title, Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").lowercase()
            .filter { it.isLetterOrDigit() } + "|" + e.startAt?.toLocalDate()

    /** Days and times are the venue's, as the feed gives them. */
    fun sameDay(a: EventItem, b: EventItem) = a.startAt?.toLocalDate() == b.startAt?.toLocalDate()

    /** "Wed 28 Oct · 17:00–19:00" or "Tue 25 Aug – Wed 26 Aug"; [dayPattern] is the locale's best "EEEdMMM". */
    fun dateLine(e: EventItem, locale: Locale, dayPattern: String = "EEE d MMM"): String {
        val start = e.startAt ?: return ""
        val day = DateTimeFormatter.ofPattern(dayPattern, locale)
        val time = DateTimeFormatter.ofPattern("HH:mm", locale)
        val end = e.endAt
        return when {
            end != null && end.toLocalDate() != start.toLocalDate() -> "${start.format(day)} – ${end.format(day)}"
            e.allDay -> start.format(day)
            else -> start.format(day) + " · " + start.format(time) + (end?.let { "–" + it.format(time) } ?: "")
        }
    }

    /** "Oslo, Norway" or "Online". */
    fun place(e: EventItem, locale: Locale): String =
        if (e.online == true) Lang.tr("Online")
        else listOfNotNull(e.city?.takeIf { it.isNotBlank() }, e.country?.let { Locale("", it).getDisplayCountry(locale) }?.takeIf { it.isNotBlank() })
            .joinToString(", ")
}
