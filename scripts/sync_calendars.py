#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "pyobjc-framework-EventKit",
#     "pyobjc-framework-Cocoa",
# ]
# ///
"""
Kalender-Sync: Spiegelt Termine aus dem BDV- und DDV-Kalender (Microsoft 365 /
Exchange, via Apple Kalender eingebunden) in den privaten iCloud-Kalender "Guido".

Aufruf:
    uv run sync_calendars.py            # schreibt wirklich
    uv run sync_calendars.py --dry-run  # zeigt nur an, was passieren würde

Jeder gespiegelte Termin bekommt den Präfix "BDV: " bzw. "DDV: " sowie einen
eindeutigen SYNCID-Marker in den Notizen. Darüber erkennt das Skript bei jedem
Lauf, ob ein Termin schon existiert (-> Update), neu ist (-> anlegen) oder in
der Quelle nicht mehr existiert (-> löschen). Termine im Zielkalender ohne
diesen Marker (z. B. manuell von dir angelegte) werden nie angefasst.

Termine, bei denen du laut Teilnehmerliste (noch) nicht zugesagt hast (offen,
vorläufig, abgesagt), werden NICHT gespiegelt. Eigene Termine ohne
Teilnehmerliste werden normal synchronisiert.

BEKANNTE EINSCHRÄNKUNG: Die Bereinigung verwaister Spiegel-Termine funktioniert
nur innerhalb des Sync-Fensters (siehe TAGE_VORAUS). Wird ein Quelltermin so
verschoben, dass er komplett aus dem Fenster herausfällt (z. B. weit in die
Vergangenheit), sieht das Skript weder den alten Quelltermin noch den alten
Zieltermin mehr und kann ihn dann nicht mehr automatisch löschen.
"""

import argparse
import datetime
import hashlib
import re
import sys
import time

from EventKit import (
    EKEntityTypeEvent,
    EKEvent,
    EKEventStore,
    EKParticipantStatusAccepted,
    EKSpanThisEvent,
)
from Foundation import NSDate, NSRunLoop, NSURL

URL_PATTERN = re.compile(r"https?://\S+")

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

# Kalender werden über (Account-Name, Kalender-Titel) aufgeloest, nicht ueber
# eine feste calendarIdentifier - die ist NICHT geraeteuebergreifend stabil,
# sondern gehoert zur lokalen EventKit-Datenbank jedes einzelnen Macs.
ZIEL_ACCOUNT, ZIEL_KALENDER = "iCloud", "Guido"

QUELLEN = [
    (("BDV", "Kalender"), "BDV"),
    (("DDV", "Kalender"), "DDV"),
]

TAGE_VORAUS = 180
MARKER_PREFIX = "SYNCID:"


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

def nsdate(dt: datetime.datetime) -> NSDate:
    return NSDate.dateWithTimeIntervalSince1970_(dt.timestamp())


def request_access(store: EKEventStore) -> bool:
    result = {"done": False, "granted": False}

    def callback(granted, error):
        result["granted"] = granted
        result["done"] = True

    # macOS 14+ (Sonoma) hat Kalenderzugriff in "Vollzugriff" vs. "Nur
    # Schreibzugriff" aufgesplittet. Die alte requestAccessToEntityType:-API
    # kann zu eingeschränkterem Zugriff fuehren als die neue, explizite
    # Full-Access-API - deshalb bevorzugt hier verwenden, wenn vorhanden.
    if hasattr(store, "requestFullAccessToEventsWithCompletion_"):
        store.requestFullAccessToEventsWithCompletion_(callback)
    else:
        store.requestAccessToEntityType_completion_(EKEntityTypeEvent, callback)

    while not result["done"]:
        NSRunLoop.currentRunLoop().runUntilDate_(
            NSDate.dateWithTimeIntervalSinceNow_(0.1)
        )
    return result["granted"]


def normalisiere_titel(quelltitel: str, label: str) -> str:
    # Erkennt einen bereits vorhandenen Prefix wie "ddv :", "DDV:", "Ddv : "
    # (Groß-/Kleinschreibung und Leerzeichen egal) und ersetzt ihn durch den
    # kanonischen Prefix "LABEL: ". Ohne erkannten Prefix wird er einfach
    # vorne angehängt (auch wenn das Wort dann doppelt vorkommt, z. B.
    # "DDV Vorstandssitzung" -> "DDV: DDV Vorstandssitzung").
    pattern = rf"^\s*{re.escape(label)}\s*:\s*"
    rest = re.sub(pattern, "", quelltitel, count=1, flags=re.IGNORECASE)
    if rest != quelltitel:
        return f"{label}: {rest}"
    return f"{label}: {quelltitel}"


STATUS_NAMEN = {
    0: "unbekannt",
    1: "offen",
    2: "zugesagt",
    3: "abgesagt",
    4: "vorläufig",
    5: "delegiert",
    6: "abgeschlossen",
    7: "in Bearbeitung",
}


def eigener_status(event):
    # Sucht unter den Teilnehmern den Eintrag, der "ich" bin, und liefert
    # dessen participantStatus. None, wenn es gar keinen Teilnehmereintrag
    # fuer mich gibt (typisch bei eigenen, nicht als Einladung angelegten
    # Terminen) - dann wird der Termin ganz normal wie bisher behandelt.
    for a in (event.attendees() or []):
        try:
            if a.isCurrentUser():
                return a.participantStatus()
        except Exception:
            continue
    return None


def find_calendar(store: EKEventStore, account_title: str, calendar_title: str):
    for cal in store.calendarsForEntityType_(EKEntityTypeEvent):
        src = cal.source()
        if (
            src is not None
            and (src.title() or "").strip() == account_title.strip()
            and (cal.title() or "").strip() == calendar_title.strip()
        ):
            return cal
    return None


def find_calendar_mit_retry(
    store: EKEventStore, account_title: str, calendar_title: str,
    versuche: int = 3, wartezeit: float = 1.5,
):
    # Nach Account-Aenderungen (Umbenennung, frisch eingerichtet) braucht
    # macOS' CalendarAgent manchmal einen kurzen Moment, bis die Kalenderliste
    # ueberall konsistent ist. Ein kurzer Retry faengt genau dieses
    # Zeitfenster ab, statt gleich mit "nicht gefunden" aufzugeben.
    for versuch in range(versuche):
        cal = find_calendar(store, account_title, calendar_title)
        if cal is not None:
            return cal
        if versuch < versuche - 1:
            time.sleep(wartezeit)
    return None


def url_als_text(url):
    return url.absoluteString() if url is not None else None


def unveraendert(ziel_event, titel: str, ort: str, url) -> bool:
    return (
        (ziel_event.title() or "") == titel
        and (ziel_event.location() or "") == ort
        and url_als_text(ziel_event.URL()) == url_als_text(url)
    )


def sync_key(event) -> str:
    # NICHT auf calendarItemExternalIdentifier verlassen - das ist bei
    # Exchange-Konten (BDV/DDV) offenbar nicht zuverlässig geräteübergreifend
    # stabil (siehe Vorfall Sept 2026). Stattdessen ein Key rein aus dem
    # sichtbaren Inhalt (Originaltitel + Start + Ende), der auf jedem Mac
    # identisch berechnet wird, weil er nur von Daten abhängt, die per
    # Exchange/iCloud ohnehin überall gleich ankommen.
    basis = (
        f"{event.title() or ''}|"
        f"{int(event.startDate().timeIntervalSince1970())}|"
        f"{int(event.endDate().timeIntervalSince1970())}"
    )
    return hashlib.sha1(basis.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Hauptlogik
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Nur anzeigen, was passieren würde - nichts in die Kalender schreiben.",
    )
    parser.add_argument(
        "--skip-access-request",
        action="store_true",
        help="NUR ZUM DEBUGGEN: request_access() überspringen, direkt auf "
        "bereits erteilte Berechtigung vertrauen (wie im Diagnose-Test).",
    )
    args = parser.parse_args()
    dry_run = args.dry_run

    if dry_run:
        print("=== DRY-RUN: es wird nichts gespeichert oder gelöscht ===\n")

    store = EKEventStore.alloc().init()
    if args.skip_access_request:
        print("(--skip-access-request: request_access() übersprungen)\n")
    elif not request_access(store):
        print("Kein Kalenderzugriff gewährt - Systemeinstellungen prüfen.")
        return 1

    ziel_cal = find_calendar_mit_retry(store, ZIEL_ACCOUNT, ZIEL_KALENDER)
    if ziel_cal is None:
        print(f"Ziel-Kalender '{ZIEL_KALENDER}' im Account '{ZIEL_ACCOUNT}' nicht gefunden.")
        return 1

    jetzt = datetime.datetime.now().astimezone()
    fenster_start = jetzt.replace(hour=0, minute=0, second=0, microsecond=0)
    fenster_ende = fenster_start + datetime.timedelta(days=TAGE_VORAUS)

    print(f"Lauf: {jetzt.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Zeitfenster: {fenster_start.date()} bis {fenster_ende.date()}\n")

    # Bestehende gespiegelte Termine im Ziel-Kalender indizieren
    ziel_predicate = store.predicateForEventsWithStartDate_endDate_calendars_(
        nsdate(fenster_start), nsdate(fenster_ende), [ziel_cal]
    )
    ziel_events = store.eventsMatchingPredicate_(ziel_predicate)

    bestehende = {}
    for ev in ziel_events:
        notes = ev.notes() or ""
        for zeile in notes.splitlines():
            if zeile.startswith(MARKER_PREFIX):
                bestehende[zeile[len(MARKER_PREFIX):].strip()] = ev
                break

    # Fallback-Index nach sichtbarem Inhalt (Titel+Start+Ende), fuer den Fall,
    # dass ein Termin noch mit einem alten Key-Schema markiert ist (z. B. nach
    # einer Aenderung von sync_key). So wird ein inhaltlich identischer Termin
    # wiederverwendet statt geloescht+neu angelegt.
    bestehende_by_content = {}
    for alter_key, ev in bestehende.items():
        content_key = (
            ev.title() or "",
            int(ev.startDate().timeIntervalSince1970()),
            int(ev.endDate().timeIntervalSince1970()),
        )
        bestehende_by_content[content_key] = (alter_key, ev)

    gesehen = set()
    neu, aktualisiert = 0, 0
    alle_quellen_gefunden = True

    for (quell_account, quell_kalender), label in QUELLEN:
        quell_cal = find_calendar_mit_retry(store, quell_account, quell_kalender)
        if quell_cal is None:
            print(
                f"Warnung: Quell-Kalender '{quell_kalender}' im Account "
                f"'{quell_account}' nicht gefunden, übersprungen."
            )
            alle_quellen_gefunden = False
            continue

        predicate = store.predicateForEventsWithStartDate_endDate_calendars_(
            nsdate(fenster_start), nsdate(fenster_ende), [quell_cal]
        )
        quell_events = store.eventsMatchingPredicate_(predicate)
        print(f"Quelle {label} ({quell_kalender} @ {quell_account}): {len(quell_events)} Termine gefunden")

        for src in quell_events:
            key = sync_key(src)

            status_code = eigener_status(src)
            if status_code is not None and status_code != EKParticipantStatusAccepted:
                status_name = STATUS_NAMEN.get(status_code, str(status_code))
                print(f"[ÜBERSPRUNGEN] '{src.title()}' - Status: {status_name} (nicht zugesagt)")
                # Bewusst NICHT zu 'gesehen' hinzufuegen: ein frueher gespiegelter
                # Termin (z. B. nachtraeglich abgesagt) wird dadurch automatisch
                # ueber die Verwaisungs-Logik am Ende entfernt.
                continue

            gesehen.add(key)

            # Manche Termineinladungen bringen den Prefix schon selbst mit,
            # in beliebiger Schreibweise (z. B. "ddv :", "DDV:Termin").
            titel = normalisiere_titel(src.title() or "(ohne Titel)", label)
            ort = src.location() or ""
            url = src.URL()
            url_quelle = "URL-Feld"
            if url is None:
                match = URL_PATTERN.search(src.notes() or "")
                if match:
                    gefunden = match.group(0).rstrip(">).,;\"'")
                    url = NSURL.URLWithString_(gefunden)
                    url_quelle = "aus Notizen extrahiert"
            zeitraum = f"{src.startDate()} - {src.endDate()}"

            ziel_event = bestehende.get(key)
            ist_neu = ziel_event is None
            migriert = False

            if ist_neu:
                content_key = (
                    titel,
                    int(src.startDate().timeIntervalSince1970()),
                    int(src.endDate().timeIntervalSince1970()),
                )
                fallback = bestehende_by_content.get(content_key)
                if fallback is not None:
                    alter_key, ziel_event = fallback
                    ist_neu = False
                    migriert = True
                    # Verhindert, dass die Verwaisungs-Logik diesen jetzt
                    # wiederverwendeten alten Eintrag spaeter faelschlich loescht.
                    bestehende.pop(alter_key, None)

            # Bei einem bereits existierenden (nicht migrierten) Treffer erst
            # pruefen, ob sich ueberhaupt etwas geaendert hat - nur dann wird
            # wirklich geschrieben. Bei einer Migration wird immer geschrieben,
            # weil zumindest der Marker in den Notizen aktualisiert werden muss.
            keine_aenderung = (
                not ist_neu and not migriert and unveraendert(ziel_event, titel, ort, url)
            )

            if dry_run:
                if keine_aenderung:
                    aktion = "UNVERÄNDERT"
                elif migriert:
                    aktion = "MIGRIEREN"
                elif ist_neu:
                    aktion = "ANLEGEN"
                else:
                    aktion = "AKTUALISIEREN"
                url_info = f"'{url}' ({url_quelle})" if url is not None else "keine"
                print(
                    f"[DRY-RUN] {aktion}: '{titel}' ({zeitraum}, "
                    f"Ort: '{ort}', URL: {url_info})"
                )
                if ist_neu:
                    neu += 1
                elif not keine_aenderung:
                    aktualisiert += 1
                continue

            if keine_aenderung:
                print(f"[UNVERÄNDERT] '{titel}' ({zeitraum})")
                continue

            if ist_neu:
                ziel_event = EKEvent.eventWithEventStore_(store)
                ziel_event.setCalendar_(ziel_cal)
                neu += 1
            else:
                aktualisiert += 1

            ziel_event.setTitle_(titel)
            ziel_event.setStartDate_(src.startDate())
            ziel_event.setEndDate_(src.endDate())
            ziel_event.setAllDay_(src.isAllDay())
            ziel_event.setLocation_(ort)
            ziel_event.setNotes_(f"{MARKER_PREFIX}{key}")
            if url is not None:
                ziel_event.setURL_(url)

            ok, err = store.saveEvent_span_commit_error_(
                ziel_event, EKSpanThisEvent, False, None
            )
            aktion = "MIGRIERT" if migriert else ("ANGELEGT" if ist_neu else "AKTUALISIERT")
            status = "OK" if ok else f"FEHLER: {err}"
            url_info = f"{url} ({url_quelle})" if url is not None else "keine"
            print(
                f"[{aktion}] '{titel}' ({zeitraum}, Ort: '{ort}', "
                f"URL: {url_info}) -> {status}"
            )

    # Verwaiste Mirror-Termine löschen - aber NUR, wenn wirklich alle Quellen
    # in diesem Lauf gefunden wurden. Fehlt eine Quelle (z. B. Account auf
    # diesem Mac nicht eingerichtet), waeren deren bisher gespiegelte Termine
    # faelschlich als "verwaist" erkannt worden - das waere ein Datenverlust
    # durch einen reinen Konfigurations-/Umgebungsfehler, kein echtes Loeschen
    # in der Quelle. Deshalb hier zur Sicherheit lieber gar nichts loeschen.
    if not alle_quellen_gefunden:
        print(
            "\nACHTUNG: Mindestens ein Quell-Kalender wurde in diesem Lauf "
            "nicht gefunden - Löschen von verwaisten Terminen wird komplett "
            "übersprungen, um nichts fälschlich zu entfernen."
        )
        print(f"\nZusammenfassung: {neu} angelegt, {aktualisiert} aktualisiert, 0 gelöscht (Löschen übersprungen).")
        if dry_run:
            return 0
        ok, err = store.commit_(None)
        if not ok:
            print(f"Fehler beim finalen Commit: {err}")
            return 1
        return 0

    geloescht = 0
    for key, ev in bestehende.items():
        if key not in gesehen:
            if dry_run:
                print(f"[DRY-RUN] würde LÖSCHEN: '{ev.title()}'")
                geloescht += 1
                continue
            ok, err = store.removeEvent_span_commit_error_(
                ev, EKSpanThisEvent, False, None
            )
            status = "OK" if ok else f"FEHLER: {err}"
            print(f"[GELÖSCHT] '{ev.title()}' -> {status}")
            if ok:
                geloescht += 1

    if dry_run:
        print(
            f"\n=== DRY-RUN Ende: {neu} würden angelegt, "
            f"{aktualisiert} aktualisiert, {geloescht} gelöscht. "
            f"Nichts wurde geschrieben. ==="
        )
        return 0

    ok, err = store.commit_(None)
    if not ok:
        print(f"Fehler beim finalen Commit: {err}")
        return 1

    print(f"\nZusammenfassung: {neu} angelegt, {aktualisiert} aktualisiert, {geloescht} gelöscht.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
