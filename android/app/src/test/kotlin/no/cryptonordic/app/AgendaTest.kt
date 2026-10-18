package no.cryptonordic.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.OffsetDateTime
import java.util.Locale

class AgendaTest {
    private val now = OffsetDateTime.parse("2026-10-18T06:00:00+02:00")

    private fun e(id: String, title: String, start: String, end: String? = null, past: Boolean = false, city: String = "Oslo", country: String = "NO") =
        EventItem(id = id, title = title, start = start, end = end, past = past, city = city, country = country)

    @Test fun sortedByStartPastRemovedAndDeduped() {
        val list = listOf(
            e("c", "Late", "2027-02-05T18:00:00+02:00"),
            e("a", "Stale", "2026-10-15T17:30:00+02:00", "2026-10-15T20:30:00+02:00"),
            e("p", "Flagged", "2026-10-30T18:00:00+01:00", past = true),
            e("b", "Uppsala Bitcoin Meetup", "2026-11-13T18:00:00+01:00"),
            e("b2", "Uppsala bitcoin meetup ", "2026-11-13T18:30:00+01:00"),
            e("b3", "Uppsala Bitcoin Meetup", "2026-12-11T18:00:00+01:00"),
            e("o", "Ongoing", "2026-10-17T09:00:00+02:00", "2026-10-19T17:00:00+02:00"),
            e("c", "Late", "2027-02-05T18:00:00+02:00"),
        )
        assertEquals(listOf("o", "b", "b3", "c"), Agenda.upcoming(list, now).map { it.id })
    }

    @Test fun eventWithoutEndStaysUntilItIsOver() {
        val list = listOf(e("x", "Talk", "2026-10-18T05:00:00+02:00"))
        assertEquals(1, Agenda.upcoming(list, now).size)
        assertTrue(Agenda.upcoming(list, now.plusHours(3)).isEmpty())
    }

    @Test fun pagesFitTheRowsInDateOrder() {
        val list = (0 until 12).map { e("$it", "E$it", "2026-11-${10 + it}T18:00:00+01:00") }.shuffled()
        val pages = Agenda.pages(Agenda.upcoming(list, now))
        assertEquals(listOf(5, 5, 2), pages.map { it.size })
        assertEquals((0 until 12).map { "$it" }, pages.flatten().map { it.id })
    }

    @Test fun datesInTheVenueTimeZone() {
        val en = Locale.forLanguageTag("en-GB")
        assertEquals("Fri 6 Nov · 18:00–21:00", Agenda.dateLine(e("h", "H", "2026-11-06T18:00:00+02:00", "2026-11-06T21:00:00+02:00"), en))
        assertEquals("Tue 25 Aug – Wed 26 Aug", Agenda.dateLine(e("l", "L", "2026-08-25T08:30:00+02:00", "2026-08-26T12:30:00+02:00"), en))
        assertEquals("Fri 20 Nov", Agenda.dateLine(e("d", "D", "2026-11-20"), en))
        assertEquals("Helsinki, Finland", Agenda.place(e("h", "H", "2026-11-06T18:00:00+02:00", city = "Helsinki", country = "FI"), en))
        assertEquals("Lund, Sverige", Agenda.place(e("l", "L", "2026-11-06T18:00:00+02:00", city = "Lund", country = "SE"), Locale.forLanguageTag("nb")))
    }
}
