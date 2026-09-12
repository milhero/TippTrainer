# TippTrainer – Analyse und Überarbeitung (12. September 2026)

## 1. Befund: die gemeldeten Fehler und ihre Ursachen

Alle Ursachen wurden am laufenden Programm reproduziert (Debug-Flags
`--auto-training 1 --auto-type --auto-keys N`, Fenster-Screenshots) und im
Code nachvollzogen.

### 1.1 „Vorschau fehlt / steht in der nächsten Zeile" (Hauptfehler)

**Symptom:** Nach etwa 55 Anschlägen verschwindet das aktuelle Zeichen aus
der Laufschrift oder erscheint in einer zweiten Zeile; die Lektion läuft
weiter, ist aber nicht mehr bedienbar. Die echte Lernstatistik enthält genau
einen Datensatz: Lektion 1, 59 Anschläge, 47 Sekunden, manuell beendet –
exakt an dieser Stelle.

**Ursache:** `TickerView` legt den Diktattext als `Text` in einen
`ZStack`, der die volle Fensterbreite vorschlägt. Der Text bricht deshalb
an Leerzeichen um (zwei Zeilen) und wird ab drei Zeilen abgeschnitten („…").
Die Scroll-Logik rechnet aber mit einer einzigen Zeile
(`cursorX = cursorIndex × Zeichenbreite`). Sobald der Cursor die erste Zeile
verlässt, zeigt der Versatz ins Leere.

**Korrektur:** Der Text wird mit `lineLimit(1)` und
`fixedSize(horizontal: true, vertical: false)` in seiner natürlichen
Einzeilenbreite gesetzt; die Laufschrift verschiebt ihn wie vorgesehen.

### 1.2 Sprachwechsel, Dauer-Auswahl und Schalter reagieren nicht

**Symptom:** Der Wechsel Deutsch/English zeigt keine Wirkung, die
Radiobuttons „Zeitlimit / Zeichenlimit / Ganze Lektion" springen erst nach
mehreren Klicks um, Schalter wirken „verpackt".

**Ursache:** `AppSettings` ist `@Observable`, speichert aber alle Werte in
`@ObservationIgnored @AppStorage`. `@AppStorage` meldet Änderungen nur
innerhalb einer SwiftUI-View; in einer Klasse schreibt es still in
`UserDefaults`. Kein Beobachter erfährt von der Änderung, die Views zeichnen
nicht neu, `onChange(of: settings.language)` feuert nie. Dass der Wert
trotzdem gespeichert wurde, zeigt die Voreinstellung `lessonLanguage = en`
im Nutzerprofil.

**Korrektur:** `AppSettings` hält gewöhnliche beobachtbare Eigenschaften,
die sich per `didSet` selbst in `UserDefaults` sichern (gleiche Schlüssel,
bestehende Werte bleiben erhalten). Test: Änderungen lösen Observation aus
und überleben eine Neuinstanz.

### 1.3 Sitzung bleibt ohne Text hängen

**Ursache:** Nachschub für die Laufschrift gab es nur mit eingeschalteter
Intelligenz. Ohne Intelligenz wurde die ganze Lektion (Lektion 1: ~180
Zeichen) vorab diktiert; danach war `currentCharacter` `nil`, Eingaben
wurden verworfen und nur das Zeitlimit konnte die Sitzung beenden.

**Korrektur:** Die Engine hält unabhängig von der Intelligenz stets
mindestens 25 Zeichen Vorrat; ohne Intelligenz folgen die Bausteine der
Lektionsreihenfolge (mit Wiederholung). Bei „Ganze Lektion" endet die
Sitzung mit dem letzten echten Zeichen (kein unsichtbares Leerzeichen mehr).
Sicherheitsnetz: Geht der Text aus, endet die Sitzung.

### 1.4 Weitere gefundene Fehler

- **Steuertasten zählen als Tippfehler:** Escape, Pfeiltasten und
  Funktionstasten wurden als Zeichen an die Engine gereicht. Sie werden nun
  ignoriert.
- **„Über TippTrainer" tut nichts:** Der Menüpunkt war durch einen leeren
  Button ersetzt. Der Standard-Dialog ist wieder da.
- **Beenden ohne Eingabe:** Solange nichts getippt wurde, schließt
  „Beenden" (auch Escape) das Training ohne Rückfrage.
- **Zeichenlimit:** endet nun nach `n` getippten Zeichen statt beim
  Anzeigen des `n`-ten Zeichens.
- **Verlauf „leer":** Es gab nur einen Datensatz; ein einzelner Punkt ohne
  Linie wirkt leer. Der Verlauf erklärt das jetzt und zeigt Werte ab dem
  ersten Eintrag lesbar.
- **„iOS 26.5 SimRuntime überprüfen":** Dieser Dialog stammt nicht aus
  TippTrainer (kein Simulator-Bezug im Code); vermutlich prüft Xcode bzw.
  CoreSimulator im Hintergrund Laufzeit-Images. Nicht reproduzierbar.

## 2. Überarbeitung

### 2.1 Eine Stelle für Einstellungen

Bisher gab es „Optionen" (Sheet) und „Einstellungen" (⌘,) mit
überlappenden Inhalten (Hilfen doppelt). Neu: **ein** Einstellungsfenster
(Sheet, erreichbar über Zahnrad und ⌘,) mit vier Reitern:
*Training* (Dauer, Fehlerreaktion, Intelligenz, Lernschritte),
*Hilfen* (Tastaturanzeige), *Darstellung* (Laufschrift, Konfetti),
*Daten* (Zurücksetzen). Die Startseite zeigt die aktiven Trainingsoptionen
als Chips und öffnet per Klick den Reiter *Training*. Die Lektionssprache
bleibt allein auf der Startseite.

### 2.2 Lernschritte (Tutorial) in jeder Übungslektion

Jede Übungslektion beginnt mit geführten Schritten, die aus den neuen
Zeichen und dem Tastaturmodell erzeugt werden (`LessonCurriculum`):

- Lektion 1: Grundstellung → f/j → d/k → s/l → a/ö (bzw. a/;) → alles
  zusammen.
- Übrige Lektionen: je neue Taste ein Schritt („Mittelfinger links, von d
  eine Reihe nach oben"), Großbuchstaben gebündelt („Umschalt mit der
  anderen Hand"), Sonderzeichen/Ziffern in kleinen Gruppen, zum Schluss
  die Intro-Zeile.
- Ziffernblock: Grundstellung 456 → obere Reihe → untere Reihe → 0.

Jede Schrittzeile endet mit der Eingabetaste. Über der Laufschrift zeigt
ein Banner „Schritt 2 von 6", Titel, Hinweis und die beteiligten Finger auf
einer Handgrafik. Danach folgt das freie Üben mit Intelligenz wie bisher.
Die Schritte lassen sich in den Trainingsoptionen abschalten. Ein Test
sichert, dass jeder Schritt nur bereits gelernte Zeichen verwendet.

### 2.3 Handgrafik

`HandsView` zeichnet beide Hände (Handfläche und fünf Finger als Pfade).
Sie ersetzt die Textliste „Zeigefinger rechts …" in der Fingerstatistik
(Färbung nach Fehlerquote, Prozentwert am Finger) und zeigt im Training den
gefragten Finger samt Umschalt-Hand.

### 2.4 Startseite, Ergebnis, Statistik

- Startseite: Hero-Karte „Weiter mit Lektion n" (erste Lektion ohne
  Ergebnis in der gewählten Sprache), Lektionskarten mit Bestpunkten,
  Häkchen für absolvierte Lektionen und den neuen Zeichen als Tastenchips.
- Ergebnis: Vergleich mit dem Bestwert, fehlerträchtigste Zeichen der
  Sitzung.
- Training: Schritt-Banner, Handgrafik in der Statusleiste, weniger
  Leerraum.

## 3. Nicht Teil dieser Überarbeitung

- Mehrsprachige Oberfläche (die App bleibt deutsch; Lektionen deutsch oder
  englisch).
- Neue Lektionstexte (die Inhalte bleiben, die Schritte werden generiert).
- Änderungen am Buchstabenregen.

## 4. Verifikation

- Bestehende und neue Swift-Testing-Tests (`xcodebuild … test`).
- Fenster-Screenshots über `--memory-store --auto-training … --auto-keys N`
  (flüchtiger Datenspeicher, damit die echte Statistik unberührt bleibt).

## 5. Stand (12. September 2026, Abend)

Alle Punkte aus Abschnitt 1 und 2 sind umgesetzt. Testsuite: 85 Tests in
12 Suites, alle grün. Sichtprüfung per Fenster-Screenshots: Startseite
(Deutsch/English, Empfehlung, Bestwerte), Einstellungen, Lernschritte
(Lektion 1, 2, 6, 19), freies Üben, Fingerstatistik mit Handgrafik,
Verlauf, Ergebnisdialog. Nicht per Automatik prüfbar: Escape als
Tastaturkürzel für »Beenden« (im Code hinterlegt, manuell zu testen).
