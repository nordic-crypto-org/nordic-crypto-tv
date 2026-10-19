#!/usr/bin/env python3
"""App Store listing text for Nordic Crypto, in the fastlane `deliver` layout:
support/appstore/metadata/<locale>/<field>.txt. Run: python3 support/appstore/listing.py
App Store Connect has no Nynorsk or Icelandic, so those UI languages fall back to "no" and "en-GB".
Our own Norwegian text never says "AI" or "KI".
"""
import json
import os

SUPPORT_URL = "https://nordiccrypto.no/contact/"
PRIVACY_URL = "https://nordiccrypto.no/privacy/"
MARKETING_URL = "https://nordiccrypto.no/"

LISTING = {
    "en-GB": {
        "name": "Nordic Crypto",
        "subtitle": "Crypto news from the Nordics",
        "promotional_text": "Bitcoin, crypto and blockchain news from Norway, Sweden, Denmark, Finland and Iceland, summarised in your language, with events and the newsletter.",
        "keywords": "bitcoin,crypto,blockchain,news,norway,sweden,denmark,finland,iceland,mica,nordic,events",
        "description": """Nordic Crypto collects bitcoin, crypto and blockchain news from Norway, Sweden, Denmark, Finland and Iceland in one calm place.

Every story gets a short summary written by the Nordic Crypto team, in English, Norwegian, Swedish, Danish, Finnish and Icelandic, with a link to the original source. Drafts are checked before anything is published.

TODAY
• The three biggest stories first, then everything else by day
• Upcoming meetups and conferences right on the front page
• Story art generated from each country's and topic's colours

COUNTRIES
• One view per country, with the local time and the latest stories
• Regulation, MiCA, tax, crime, business and more, tagged by topic

EVENTS
• Meetups, conferences and talks across the Nordics, sorted by date
• Clear labels for free, paid, sponsored and online events

NEWSLETTER
• The weekly Nordic Crypto issue to read in the app
• The newsreel video for each issue

ON EVERY SCREEN
• iPhone and iPad, with Dynamic Type and VoiceOver
• Mac, in its own window with a sidebar
• Apple Vision Pro, with the newsreel in a window of its own
• Apple TV as an information screen: lead stories, events, a row per country and the latest headlines, each rotating on its own, with Radio Norge in the background. Play/Pause on the remote switches the radio on or off.

PRIVATE BY DESIGN
No account, no tracking, no ads. Notifications are opt-in: our push server keeps only the device's push token, the countries you pick and your language, and deletes them when you turn notifications off.

Headlines belong to their publishers. Nordic Crypto is news, not investment advice.""",
    },
    "no": {
        "name": "Nordic Crypto",
        "subtitle": "Kryptonyheter fra Norden",
        "promotional_text": "Nyheter om bitcoin, krypto og blokkjede fra Norge, Sverige, Danmark, Finland og Island, oppsummert på ditt språk, med arrangementer og nyhetsbrev.",
        "keywords": "bitcoin,krypto,blokkjede,nyheter,norge,sverige,danmark,finland,island,mica,norden,kryptovaluta",
        "description": """Nordic Crypto samler nyheter om bitcoin, krypto og blokkjede fra Norge, Sverige, Danmark, Finland og Island på ett rolig sted.

Hver sak får et kort sammendrag skrevet av Nordic Crypto-teamet, på norsk, svensk, dansk, finsk, islandsk og engelsk, med lenke til den opprinnelige kilden. Utkast blir kontrollert før noe publiseres.

I DAG
• De tre største sakene først, deretter resten dag for dag
• Kommende meetups og konferanser rett på forsiden
• Egen fargekunst for hver sak, laget av landets og temaets farger

LAND
• Én visning per land, med lokal tid og de siste sakene
• Regulering, MiCA, skatt, kriminalitet, næringsliv og mer, merket etter tema

ARRANGEMENTER
• Meetups, konferanser og foredrag i hele Norden, sortert etter dato
• Tydelig merket gratis, betalt, sponset og digitalt

NYHETSBREV
• Det ukentlige Nordic Crypto-nyhetsbrevet, til å lese i appen
• Nyhetsvideoen til hver utgave

PÅ ALLE SKJERMER
• iPhone og iPad, med dynamisk tekststørrelse og VoiceOver
• Mac, i eget vindu med sidefelt
• Apple Vision Pro, med nyhetsvideoen i eget vindu
• Apple TV som infoskjerm: hovedsaker, arrangementer, en rad per land og de siste overskriftene, som hver bytter innhold for seg, med Radio Norge i bakgrunnen. Play/Pause på fjernkontrollen skrur radioen av og på.

PERSONVERN FRA START
Ingen konto, ingen sporing, ingen reklame. Varsler slår du på selv: push-serveren vår lagrer bare push-tokenet til enheten, landene du velger og språket ditt, og sletter dem når du slår av varsler.

Overskriftene tilhører utgiverne. Nordic Crypto er nyheter, ikke investeringsråd.""",
    },
    "sv": {
        "name": "Nordic Crypto",
        "subtitle": "Kryptonyheter från Norden",
        "promotional_text": "Nyheter om bitcoin, krypto och blockkedjor från Norge, Sverige, Danmark, Finland och Island, sammanfattade på ditt språk, med evenemang och nyhetsbrev.",
        "keywords": "bitcoin,krypto,blockkedja,nyheter,norge,sverige,danmark,finland,island,mica,norden",
        "description": """Nordic Crypto samlar nyheter om bitcoin, krypto och blockkedjor från Norge, Sverige, Danmark, Finland och Island på ett lugnt ställe.

Varje nyhet får en kort sammanfattning skriven av Nordic Crypto-teamet, på svenska, norska, danska, finska, isländska och engelska, med länk till originalkällan. Utkast granskas innan något publiceras.

IDAG
• De tre största nyheterna först, sedan resten dag för dag
• Kommande meetups och konferenser direkt på förstasidan

LÄNDER
• En vy per land, med lokal tid och de senaste nyheterna

EVENEMANG
• Meetups, konferenser och föredrag i hela Norden, sorterade efter datum
• Tydliga märkningar för gratis, betalt, sponsrat och online

NYHETSBREV
• Veckans Nordic Crypto-nummer att läsa i appen, med nyhetsvideo

PÅ ALLA SKÄRMAR
• iPhone, iPad, Mac och Apple Vision Pro
• Apple TV som informationsskärm med roterande moduler och Radio Norge i bakgrunden. Play/Pause på fjärrkontrollen slår av och på radion.

INTEGRITET
Inget konto, ingen spårning, ingen reklam.

Rubrikerna tillhör sina utgivare. Nordic Crypto är nyheter, inte investeringsråd.""",
    },
    "da": {
        "name": "Nordic Crypto",
        "subtitle": "Kryptonyheder fra Norden",
        "promotional_text": "Nyheder om bitcoin, krypto og blockchain fra Norge, Sverige, Danmark, Finland og Island, opsummeret på dit sprog, med begivenheder og nyhedsbrev.",
        "keywords": "bitcoin,krypto,blockchain,nyheder,norge,sverige,danmark,finland,island,mica,norden",
        "description": """Nordic Crypto samler nyheder om bitcoin, krypto og blockchain fra Norge, Sverige, Danmark, Finland og Island ét roligt sted.

Hver historie får et kort resumé skrevet af Nordic Crypto-holdet, på dansk, norsk, svensk, finsk, islandsk og engelsk, med link til den oprindelige kilde. Udkast bliver tjekket, før noget udgives.

I DAG
• De tre største historier først, derefter resten dag for dag
• Kommende meetups og konferencer direkte på forsiden

LANDE
• Én visning pr. land med lokal tid og de seneste historier

BEGIVENHEDER
• Meetups, konferencer og foredrag i hele Norden, sorteret efter dato
• Tydelig mærkning af gratis, betalt, sponsoreret og online

NYHEDSBREV
• Ugens Nordic Crypto-udgave til at læse i appen, med nyhedsvideo

PÅ ALLE SKÆRME
• iPhone, iPad, Mac og Apple Vision Pro
• Apple TV som informationsskærm med skiftende moduler og Radio Norge i baggrunden. Play/Pause på fjernbetjeningen tænder og slukker radioen.

PRIVATLIV
Ingen konto, ingen sporing, ingen reklamer.

Overskrifterne tilhører deres udgivere. Nordic Crypto er nyheder, ikke investeringsrådgivning.""",
    },
    "fi": {
        "name": "Nordic Crypto",
        "subtitle": "Pohjoismaiden kryptouutiset",
        "promotional_text": "Bitcoin-, krypto- ja lohkoketjuuutiset Norjasta, Ruotsista, Tanskasta, Suomesta ja Islannista omalla kielelläsi tiivistettyinä, tapahtumineen ja uutiskirjeineen.",
        "keywords": "bitcoin,krypto,lohkoketju,uutiset,norja,ruotsi,tanska,suomi,islanti,mica,pohjoismaat",
        "description": """Nordic Crypto kokoaa bitcoin-, krypto- ja lohkoketjuuutiset Norjasta, Ruotsista, Tanskasta, Suomesta ja Islannista yhteen rauhalliseen paikkaan.

Jokainen uutinen saa Nordic Crypto -tiimin kirjoittaman lyhyen tiivistelmän suomeksi, norjaksi, ruotsiksi, tanskaksi, islanniksi ja englanniksi sekä linkin alkuperäiseen lähteeseen. Luonnokset tarkistetaan ennen julkaisua.

TÄNÄÄN
• Kolme suurinta uutista ensin, sitten loput päivittäin
• Tulevat tapaamiset ja konferenssit suoraan etusivulla

MAAT
• Oma näkymä jokaiselle maalle, paikallisaika ja uusimmat uutiset

TAPAHTUMAT
• Tapaamiset, konferenssit ja esitelmät koko Pohjolassa päivämäärän mukaan
• Selkeät merkinnät maksuttomille, maksullisille, sponsoroiduille ja verkkotapahtumille

UUTISKIRJE
• Viikoittainen Nordic Crypto -numero luettavaksi sovelluksessa, uutisvideon kera

KAIKILLA NÄYTÖILLÄ
• iPhone, iPad, Mac ja Apple Vision Pro
• Apple TV infonäyttönä vaihtuvine osioineen ja Radio Norge taustalla. Kaukosäätimen Play/Pause-painike kytkee radion päälle ja pois.

YKSITYISYYS
Ei tiliä, ei seurantaa, ei mainoksia.

Otsikot kuuluvat julkaisijoilleen. Nordic Crypto on uutispalvelu, ei sijoitusneuvontaa.""",
    },
}

LIMITS = {"name": 30, "subtitle": 30, "promotional_text": 170, "keywords": 100, "description": 4000}

# Further languages from the Nordic Crypto API (listing_extra.json), keyed by app language code,
# published under these App Store Connect locales.
ASC_LOCALE = {"zh-Hans": "zh-Hans", "hi": "hi", "es": "es-ES", "fr": "fr-FR", "ar": "ar-SA", "bn": "bn-BD",
              "pt": "pt-BR", "ru": "ru", "ur": "ur-PK", "id": "id", "de": "de-DE", "ja": "ja", "sw": "sw",
              "mr": "mr-IN"}
EXTRA = os.path.join(os.path.dirname(__file__), "listing_extra.json")
if os.path.exists(EXTRA):
    for lang, fields in json.load(open(EXTRA)).items():
        LISTING[ASC_LOCALE.get(lang, lang)] = fields


def fit_keywords(text, limit=100):
    """App Store Connect counts the keyword limit in UTF-8 bytes; drop terms from the end to fit."""
    terms = [t.strip() for t in text.split(",") if t.strip()]
    while terms and len(",".join(terms).encode()) > limit:
        terms.pop()
    return ",".join(terms)


def main():
    root = os.path.join(os.path.dirname(__file__), "metadata")
    for locale, fields in LISTING.items():
        d = os.path.join(root, locale)
        os.makedirs(d, exist_ok=True)
        for field, text in fields.items():
            if field == "keywords":
                text = fit_keywords(text)
            assert len(text) <= LIMITS[field], f"{locale}/{field} is {len(text)} > {LIMITS[field]}"
            if locale == "no":
                assert " AI" not in text and " KI" not in text
            with open(os.path.join(d, field + ".txt"), "w") as f:
                f.write(text + "\n")
        for field, url in (("support_url", SUPPORT_URL), ("privacy_url", PRIVACY_URL), ("marketing_url", MARKETING_URL)):
            with open(os.path.join(d, field + ".txt"), "w") as f:
                f.write(url + "\n")
        print(locale, {k: len(v) for k, v in fields.items()})


if __name__ == "__main__":
    main()
