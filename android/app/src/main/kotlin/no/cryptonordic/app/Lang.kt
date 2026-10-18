package no.cryptonordic.app

import android.content.Context
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Language and translations. The interface strings are read from the same
 * Localizable.xcstrings the Apple apps use, so all platforms say the same
 * thing in all 21 languages.
 */
object Lang {
    /** Languages the API translates its own text into. */
    private val nordic = setOf("nb", "nn", "sv", "da", "fi", "is")
    private val interfaceOnly = setOf("zh", "hi", "es", "fr", "ar", "bn", "pt", "ru", "ur", "id", "de", "ja", "sw", "mr")

    var current: String = "en"
        private set
    private var table: Map<String, String> = emptyMap()

    fun load(context: Context) {
        current = resolve(Locale.getDefault())
        val catalogKey = if (current == "zh") "zh-Hans" else current
        table = runCatching {
            val text = context.assets.open("Localizable.xcstrings").bufferedReader().use { it.readText() }
            val strings = Json.parseToJsonElement(text).jsonObject["strings"]!!.jsonObject
            strings.mapNotNull { (key, value) ->
                val unit = (value as? JsonObject)?.get("localizations")?.jsonObject?.get(catalogKey)
                    ?.jsonObject?.get("stringUnit")?.jsonObject?.get("value")?.jsonPrimitive?.content
                unit?.let { key to it }
            }.toMap()
        }.getOrDefault(emptyMap())
    }

    /** Norwegian (no, nb, nn) reads nynorsk, as does English in Norway. */
    fun resolve(locale: Locale): String {
        val code = locale.language
        return when {
            code in setOf("no", "nb", "nn") -> "nn"
            code in nordic || code in interfaceOnly -> code
            locale.country == "NO" -> "nn"
            else -> "en"
        }
    }

    /** Where to look for a translation, best first: nynorsk falls back to bokmål. */
    fun fallbacks(lang: String): List<String> = if (lang == "nn") listOf("nn", "nb") else listOf(lang)

    fun sameFamily(a: String, b: String): Boolean {
        val norsk = setOf("no", "nb", "nn")
        return a == b || (a in norsk && b in norsk)
    }

    /** Translate an English catalogue key; Swift's %lld/%@ become %d/%s. */
    fun tr(key: String, vararg args: Any): String {
        val pattern = (table[key] ?: key).replace("%lld", "%d").replace("%@", "%s")
        return if (args.isEmpty()) pattern else runCatching { String.format(locale, pattern, *args) }.getOrDefault(pattern)
    }

    val locale: Locale get() = Locale.forLanguageTag(if (current == "en") "en-GB" else current)

    fun time(t: OffsetDateTime?): String =
        t?.atZoneSameInstant(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("HH:mm", locale)) ?: "--:--"

    fun day(t: OffsetDateTime?): String =
        t?.atZoneSameInstant(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("d MMM", locale)) ?: ""

    fun dayNumber(t: OffsetDateTime?): String = t?.atZoneSameInstant(ZoneId.systemDefault())?.dayOfMonth?.toString() ?: "–"

    fun month(t: OffsetDateTime?): String =
        t?.atZoneSameInstant(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("MMM", locale))?.uppercase(locale) ?: ""

    fun weekdayShort(t: OffsetDateTime?): String =
        t?.atZoneSameInstant(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("EEE", locale)) ?: ""

    fun longDate(t: java.time.ZonedDateTime): String =
        t.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale))

    /** Today's stories show the time, older ones the date. */
    fun stamp(t: OffsetDateTime?): String {
        t ?: return ""
        val local = t.atZoneSameInstant(ZoneId.systemDefault()).toLocalDate()
        return if (local == java.time.LocalDate.now()) time(t) else day(t)
    }
}

/** The translation for [lang], following [Lang.fallbacks]. */
fun Map<String, String>.localized(lang: String): String? = Lang.fallbacks(lang).firstNotNullOfOrNull { this[it] }
