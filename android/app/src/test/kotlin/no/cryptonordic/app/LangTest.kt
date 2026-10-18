package no.cryptonordic.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LangTest {
    @Test fun resolvesDeviceLanguage() {
        assertEquals("sv", Lang.resolve(listOf("sv-SE")))
        assertEquals("de", Lang.resolve(listOf("de-DE")))
        assertEquals("en", Lang.resolve(listOf("ko-KR")))
        assertEquals("en", Lang.resolve(listOf("en-NO")))
        assertEquals("en", Lang.resolve(listOf("en-NO", "nb-NO")))
        assertEquals("nn", Lang.resolve(listOf("nb-NO")))
        assertEquals("nn", Lang.resolve(listOf("no")))
        assertEquals("nn", Lang.resolve(listOf("nn-NO")))
        assertEquals("da", Lang.resolve(listOf("ko-KR", "da-DK")))
        assertEquals("id", Lang.resolve(listOf("id-ID")))
        assertEquals("en", Lang.resolve(emptyList()))
    }

    @Test fun contentFallsBackToEnglish() {
        val item = NewsItem(
            id = "a", title = "Så kan Sverige", titleEn = "How Sweden", languageCode = "sv",
            titleI18n = mapOf("nn" to "Slik kan Sverige"), summary = "Summary",
            summaryI18n = mapOf("nb" to "Sammendrag", "sv" to "Sammanfattning"),
        )
        assertEquals("Så kan Sverige", item.headline("sv"))
        assertEquals("Slik kan Sverige", item.headline("nn"))
        assertEquals("How Sweden", item.headline("da"))
        assertEquals("How Sweden", item.headline("de"))
        assertEquals("Sammendrag", item.summary("nn"))
        assertEquals("Summary", item.summary("de"))
        assertEquals("Bokmål", NewsItem(id = "b", title = "Bokmål", titleEn = "English", languageCode = "no").headline("nn"))
        assertEquals("Online", mapOf("sv" to "Nät").localized("da", "Online"))
        assertNull(mapOf("sv" to "Nät").localized("da"))
    }
}
