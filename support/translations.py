#!/usr/bin/env python3
"""Writes NordicCrypto/Localizable.xcstrings from the table below.
Order of each row: nb, nn, sv, da, fi, is. Run from the repo root:
python3 support/translations.py
Our own Norwegian text never says "AI" or "KI" (Nordic Crypto text rule).
"""
import glob
import json
import os

LANGS = ["nb", "nn", "sv", "da", "fi", "is"]
# Brand names that stay as they are.
NO_TRANSLATE = ["Nordic Crypto", "Nordic Shield NFT"]

T = {
    "%@, %lld stories": ["%@, %lld saker", "%@, %lld saker", "%@, %lld nyheter", "%@, %lld historier", "%@, %lld uutista", "%@, %lld fréttir"],
    "%lld stories · %lld upcoming events": ["%lld saker · %lld kommende arrangementer", "%lld saker · %lld komande arrangement", "%lld nyheter · %lld kommande evenemang", "%lld historier · %lld kommende begivenheder", "%lld uutista · %lld tulevaa tapahtumaa", "%lld fréttir · %lld væntanlegir viðburðir"],
    "Latest": ["Siste", "Siste", "Senaste", "Seneste", "Uusimmat", "Nýjast"],
    "Top topics": ["Mest omtalt", "Mest omtalt", "Mest omtalat", "Mest omtalt", "Puhutuimmat aiheet", "Helstu efni"],
    "%lld events": ["%lld arrangementer", "%lld arrangement", "%lld evenemang", "%lld begivenheder", "%lld tapahtumaa", "%lld viðburðir"],
    "%lld stories": ["%lld saker", "%lld saker", "%lld nyheter", "%lld historier", "%lld uutista", "%lld fréttir"],
    "All": ["Alle", "Alle", "Alla", "Alle", "Kaikki", "Allt"],
    "All %lld events": ["Alle %lld arrangementer", "Alle %lld arrangementa", "Alla %lld evenemang", "Alle %lld begivenheder", "Kaikki %lld tapahtumaa", "Allir %lld viðburðir"],
    "By country": ["Etter land", "Etter land", "Per land", "Efter land", "Maittain", "Eftir löndum"],
    "Coming up": ["Kommer snart", "Kjem snart", "På gång", "Snart", "Tulossa", "Fram undan"],
    "Countries": ["Land", "Land", "Länder", "Lande", "Maat", "Lönd"],
    "Country": ["Land", "Land", "Land", "Land", "Maa", "Land"],
    "Denmark": ["Danmark", "Danmark", "Danmark", "Danmark", "Tanska", "Danmörk"],
    "Events": ["Arrangementer", "Arrangement", "Evenemang", "Begivenheder", "Tapahtumat", "Viðburðir"],
    "Finland": ["Finland", "Finland", "Finland", "Finland", "Suomi", "Finnland"],
    "Free": ["Gratis", "Gratis", "Gratis", "Gratis", "Maksuton", "Ókeypis"],
    "Headline © %@. Summary by the Nordic Crypto team. Not investment advice.": [
        "Overskrift © %@. Sammendrag av Nordic Crypto-teamet. Ikke investeringsråd.",
        "Overskrift © %@. Samandrag av Nordic Crypto-laget. Ikkje investeringsråd.",
        "Rubrik © %@. Sammanfattning av Nordic Crypto-teamet. Inte investeringsråd.",
        "Overskrift © %@. Resumé af Nordic Crypto-holdet. Ikke investeringsrådgivning.",
        "Otsikko © %@. Tiivistelmä: Nordic Crypto -tiimi. Ei sijoitusneuvontaa.",
        "Fyrirsögn © %@. Samantekt eftir Nordic Crypto-teymið. Ekki fjárfestingarráðgjöf."],
    "Hide past events": ["Skjul tidligere arrangementer", "Gøym tidlegare arrangement", "Dölj tidigare evenemang", "Skjul tidligere begivenheder", "Piilota menneet tapahtumat", "Fela liðna viðburði"],
    "Iceland": ["Island", "Island", "Island", "Island", "Islanti", "Ísland"],
    "More news": ["Flere nyheter", "Fleire nyheiter", "Fler nyheter", "Flere nyheder", "Lisää uutisia", "Fleiri fréttir"],
    "Newsletter": ["Nyhetsbrev", "Nyheitsbrev", "Nyhetsbrev", "Nyhedsbrev", "Uutiskirje", "Fréttabréf"],
    "Newsreel": ["Nyhetsvideo", "Nyheitsvideo", "Nyhetsvideo", "Nyhedsvideo", "Uutisvideo", "Fréttamyndband"],
    "Next": ["Neste", "Neste", "Nästa", "Næste", "Seuraava", "Næst"],
    "No issues yet": ["Ingen utgaver ennå", "Ingen utgåver enno", "Inga nummer än", "Ingen udgaver endnu", "Ei vielä numeroita", "Engin tölublöð enn"],
    "No stories yet": ["Ingen saker ennå", "Ingen saker enno", "Inga nyheter än", "Ingen historier endnu", "Ei vielä uutisia", "Engar fréttir enn"],
    "No upcoming events": ["Ingen kommende arrangementer", "Ingen komande arrangement", "Inga kommande evenemang", "Ingen kommende begivenheder", "Ei tulevia tapahtumia", "Engir væntanlegir viðburðir"],
    "Nordic Crypto summary": ["Sammendrag fra Nordic Crypto", "Samandrag frå Nordic Crypto", "Sammanfattning från Nordic Crypto", "Resumé fra Nordic Crypto", "Nordic Crypton tiivistelmä", "Samantekt Nordic Crypto"],
    "Norway": ["Norge", "Noreg", "Norge", "Norge", "Norja", "Noregur"],
    "Not investment advice": ["Ikke investeringsråd", "Ikkje investeringsråd", "Inte investeringsråd", "Ikke investeringsrådgivning", "Ei sijoitusneuvontaa", "Ekki fjárfestingarráðgjöf"],
    "Not investment advice · Headlines © their publishers · Summaries by Nordic Crypto": [
        "Ikke investeringsråd · Overskrifter © utgiverne · Sammendrag av Nordic Crypto",
        "Ikkje investeringsråd · Overskrifter © utgjevarane · Samandrag av Nordic Crypto",
        "Inte investeringsråd · Rubriker © respektive utgivare · Sammanfattningar av Nordic Crypto",
        "Ikke investeringsrådgivning · Overskrifter © udgiverne · Resuméer af Nordic Crypto",
        "Ei sijoitusneuvontaa · Otsikot © julkaisijat · Tiivistelmät: Nordic Crypto",
        "Ekki fjárfestingarráðgjöf · Fyrirsagnir © útgefendur · Samantektir eftir Nordic Crypto"],
    "Note": ["Merknad", "Merknad", "Anmärkning", "Bemærkning", "Huomautus", "Athugasemd"],
    "Off": ["Av", "Av", "Av", "Fra", "Pois", "Slökkt"],
    "Offline · showing saved news": ["Frakoblet · viser lagrede nyheter", "Fråkopla · viser lagra nyheiter", "Offline · visar sparade nyheter", "Offline · viser gemte nyheder", "Ei yhteyttä · näytetään tallennetut uutiset", "Ótengt · sýnir vistaðar fréttir"],
    "On": ["På", "På", "På", "Til", "Päällä", "Kveikt"],
    "Online": ["Nett", "Nett", "Online", "Online", "Verkossa", "Á netinu"],
    "Open event page": ["Åpne arrangementssiden", "Opne arrangementssida", "Öppna evenemangssidan", "Åbn begivenhedssiden", "Avaa tapahtumasivu", "Opna viðburðarsíðuna"],
    "Organiser": ["Arrangør", "Arrangør", "Arrangör", "Arrangør", "Järjestäjä", "Skipuleggjandi"],
    "Paid": ["Betalt", "Betalt", "Betalt", "Betalt", "Maksullinen", "Greitt"],
    "Paragraph %lld of %lld": ["Avsnitt %lld av %lld", "Avsnitt %lld av %lld", "Stycke %lld av %lld", "Afsnit %lld af %lld", "Kappale %lld/%lld", "Efnisgrein %lld af %lld"],
    "Past event": ["Tidligere arrangement", "Tidlegare arrangement", "Tidigare evenemang", "Tidligere begivenhed", "Mennyt tapahtuma", "Liðinn viðburður"],
    "Past issues": ["Tidligere utgaver", "Tidlegare utgåver", "Tidigare nummer", "Tidligere udgaver", "Aiemmat numerot", "Eldri tölublöð"],
    "Paywall": ["Betalingsmur", "Betalingsmur", "Betalvägg", "Betalingsmur", "Maksumuuri", "Áskriftarveggur"],
    "QR code linking to %@": ["QR-kode som lenker til %@", "QR-kode som lenkjer til %@", "QR-kod som länkar till %@", "QR-kode, der linker til %@", "QR-koodi, joka johtaa osoitteeseen %@", "QR-kóði sem vísar á %@"],
    "Quiet in %@ — no stories this week": ["Stille i %@ – ingen saker denne uka", "Stille i %@ – ingen saker denne veka", "Tyst i %@ – inga nyheter den här veckan", "Stille i %@ – ingen historier i denne uge", "Hiljaista: %@ – ei uutisia tällä viikolla", "Rólegt í %@ – engar fréttir þessa vikuna"],
    "Press ⏯ to turn off": ["Trykk ⏯ for å skru av", "Trykk ⏯ for å skru av", "Tryck ⏯ för att stänga av", "Tryk ⏯ for at slukke", "Sammuta painamalla ⏯", "Ýttu á ⏯ til að slökkva"],
    "Press ⏯ to turn on": ["Trykk ⏯ for å skru på", "Trykk ⏯ for å skru på", "Tryck ⏯ för att sätta på", "Tryk ⏯ for at tænde", "Käynnistä painamalla ⏯", "Ýttu á ⏯ til að kveikja"],
    "Read at %@": ["Les hos %@", "Les hjå %@", "Läs hos %@", "Læs hos %@", "Lue: %@", "Lesa hjá %@"],
    "Read issue": ["Les utgaven", "Les utgåva", "Läs numret", "Læs udgaven", "Lue numero", "Lesa tölublaðið"],
    "Refresh": ["Oppdater", "Oppdater", "Uppdatera", "Opdater", "Päivitä", "Uppfæra"],
    "Scan to open the event page": ["Skann for å åpne arrangementssiden", "Skann for å opne arrangementssida", "Skanna för att öppna evenemangssidan", "Scan for at åbne begivenhedssiden", "Skannaa ja avaa tapahtumasivu", "Skannaðu til að opna viðburðarsíðuna"],
    "Scan to read the full story": ["Skann for å lese hele saken", "Skann for å lese heile saka", "Skanna för att läsa hela artikeln", "Scan for at læse hele historien", "Skannaa ja lue koko juttu", "Skannaðu til að lesa alla fréttina"],
    "Scan to subscribe": ["Skann for å abonnere", "Skann for å abonnere", "Skanna för att prenumerera", "Scan for at abonnere", "Skannaa ja tilaa", "Skannaðu til að gerast áskrifandi"],
    "Share": ["Del", "Del", "Dela", "Del", "Jaa", "Deila"],
    "Show past events (%lld)": ["Vis tidligere arrangementer (%lld)", "Vis tidlegare arrangement (%lld)", "Visa tidigare evenemang (%lld)", "Vis tidligere begivenheder (%lld)", "Näytä menneet tapahtumat (%lld)", "Sýna liðna viðburði (%lld)"],
    "Sponsor": ["Sponsor", "Sponsor", "Sponsor", "Sponsor", "Sponsori", "Styrktaraðili"],
    "Sponsored": ["Sponset", "Sponsa", "Sponsrat", "Sponsoreret", "Sponsoroitu", "Styrkt"],
    "Stories": ["Saker", "Saker", "Nyheter", "Historier", "Uutiset", "Fréttir"],
    "Subscribe": ["Abonner", "Abonner", "Prenumerera", "Abonner", "Tilaa", "Gerast áskrifandi"],
    "Sweden": ["Sverige", "Sverige", "Sverige", "Sverige", "Ruotsi", "Svíþjóð"],
    "The source may require a subscription": ["Kilden kan kreve abonnement", "Kjelda kan krevje abonnement", "Källan kan kräva prenumeration", "Kilden kan kræve abonnement", "Lähde voi vaatia tilauksen", "Heimildin gæti krafist áskriftar"],
    "Today": ["I dag", "I dag", "I dag", "I dag", "Tänään", "Í dag"],
    "Top stories": ["Toppsaker", "Toppsaker", "Toppnyheter", "Tophistorier", "Pääuutiset", "Helstu fréttir"],
    "Updated %@": ["Oppdatert %@", "Oppdatert %@", "Uppdaterad %@", "Opdateret %@", "Päivitetty %@", "Uppfært %@"],
    "Watch newsreel": ["Se nyhetsvideoen", "Sjå nyheitsvideoen", "Se nyhetsvideon", "Se nyhedsvideoen", "Katso uutisvideo", "Horfa á fréttamyndbandið"],
    "When": ["Når", "Når", "När", "Hvornår", "Milloin", "Hvenær"],
    "Where": ["Hvor", "Kvar", "Var", "Hvor", "Missä", "Hvar"],
    "Yesterday": ["I går", "I går", "I går", "I går", "Eilen", "Í gær"],
    "the publisher": ["utgiveren", "utgjevaren", "utgivaren", "udgiveren", "julkaisija", "útgefandinn"],
}


# The Nordic Crypto API's further interface languages: support/translations_extra.json maps
# each English key to {lang: text} for zh-Hans, hi, es, fr, ar, bn, pt, ru, ur, id, de, ja, sw, mr.
EXTRA = os.path.join(os.path.dirname(__file__), "translations_extra.json")


def main():
    extra = json.load(open(EXTRA)) if os.path.exists(EXTRA) else {}
    strings = {}
    for key, values in T.items():
        assert len(values) == len(LANGS), key
        for v in values[:2]:
            assert " AI" not in v and " KI" not in v, v
        locs = {l: {"stringUnit": {"state": "translated", "value": v}} for l, v in zip(LANGS, values)}
        for lang, v in extra.get(key, {}).items():
            assert v.count("%@") == key.count("%@") and v.count("%lld") == key.count("%lld"), (key, lang)
            locs[lang] = {"stringUnit": {"state": "translated", "value": v}}
        strings[key] = {"localizations": locs}
    # Later batches: {key: {lang: text}}, merged over earlier ones (batch9_fa_uk_tr adds Persian, Ukrainian and Turkish).
    for batch in sorted(glob.glob(os.path.join(os.path.dirname(__file__), "translations_batch*.json"))):
        for key, langs in json.load(open(batch)).items():
            for lang, v in langs.items():
                assert v.count("%@") == key.count("%@") and v.count("%lld") == key.count("%lld"), (key, lang)
                if lang in ("nb", "nn"):
                    assert " AI" not in v and " KI" not in v, v
            strings.setdefault(key, {"localizations": {}})["localizations"].update(
                {l: {"stringUnit": {"state": "translated", "value": v}} for l, v in langs.items()})
    for key in NO_TRANSLATE:
        strings[key] = {"shouldTranslate": False}
    out = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    path = os.path.join(os.path.dirname(__file__), "..", "NordicCrypto", "Localizable.xcstrings")
    with open(path, "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(len(strings), "keys")


if __name__ == "__main__":
    main()
