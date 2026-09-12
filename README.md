# TippTrainer

Ein moderner Zehnfinger-Schreibtrainer für macOS — funktional inspiriert vom
klassischen TIPP10 (dessen macOS-Version seit Catalina nicht mehr läuft),
komplett neu implementiert in Swift/SwiftUI mit eigenständigen Inhalten.

## Funktionen

- 20 aufeinander aufbauende Übungslektionen (Deutsch QWERTZ + Englisch QWERTY)
- Lernschritte: Jede Übungslektion beginnt mit einem kleinen Tutorial —
  Grundstellung Finger für Finger, je neue Taste eine Übungszeile mit
  Fingerhinweis und Handgrafik, danach freies Üben
- Intelligente Diktate: fehlerträchtige Zeichen werden häufiger wiederholt
- Freie Diktate und eigene Lektionen (Satz-/Wortdiktat, Import/Export)
- Laufschrift mit adaptiver Geschwindigkeit, virtuelle Tastatur mit
  Fingerfarben, Tastwegen und Grundstellungsanzeige
- Startseite mit Empfehlung („Als Nächstes"), Bestwerten und Lernfortschritt
- Umfassende Lernstatistik (Bericht, Verlauf, Zeichen-Auswertung,
  Fehlerquote je Finger auf einer Handgrafik)
- Ein Einstellungsfenster (Zahnrad oder ⌘,) für Training, Hilfen,
  Darstellung und Daten
- Buchstabenregen-Spiel

## Voraussetzungen

- **macOS 26** oder neuer (die App wird gegen das macOS-26-SDK gebaut und
  läuft nicht auf älteren Systemen)
- **Xcode 26** oder neuer (Swift 6)
- **Kein Apple-Developer-Account nötig.** Die App wird beim Bauen lokal
  ad-hoc signiert; ein kostenpflichtiges Entwicklerprogramm ist nicht
  erforderlich.

## Installation

```sh
git clone https://github.com/milhero/TippTrainer.git ~/Developer/TippTrainer
cd ~/Developer/TippTrainer

xcodebuild -project TippTrainer.xcodeproj -scheme TippTrainer \
           -configuration Release -derivedDataPath build build

cp -R build/Build/Products/Release/TippTrainer.app /Applications/
```

Danach liegt TippTrainer im Programme-Ordner und lässt sich normal starten.
Das Release-Binary ist universal (Apple Silicon und Intel).

> **Wichtig:** Das Repository nicht in einen von iCloud synchronisierten
> Ordner klonen (`~/Documents` und `~/Desktop`, sofern „Schreibtisch &
> Dokumente" in iCloud aktiv ist). iCloud versieht neu angelegte Ordner mit
> erweiterten Attributen, an denen die Code-Signierung scheitert — siehe
> [Fehlerbehebung](#fehlerbehebung). `~/Developer` ist frei von iCloud-Sync.

### Berechtigungen

TippTrainer benötigt **keine Sonderberechtigungen**. Tastatureingaben werden
ausschließlich im eigenen Fenster ausgewertet; die App verwendet keine
globalen Event-Taps und fordert daher weder Bedienungshilfen-Rechte
(Accessibility) noch Eingabeüberwachung an.

### Deinstallation

```sh
rm -rf /Applications/TippTrainer.app
defaults delete de.milanronnenberg.TippTrainer
```

Die App ist nicht sandboxed und legt keine eigenen Dateien an: Einstellungen
und Lernstatistik liegen vollständig in den Benutzereinstellungen
(`~/Library/Preferences/de.milanronnenberg.TippTrainer.plist`). `defaults
delete` ist hier `rm` vorzuziehen, da der Einstellungsdienst eine gelöschte
Datei aus dem Cache zurückschreiben kann.

## Entwicklung

Debug-Build ohne Installation:

```sh
xcodebuild -project TippTrainer.xcodeproj -scheme TippTrainer build
```

Tests ausführen (85 Tests in 12 Suites, Swift Testing):

```sh
xcodebuild -project TippTrainer.xcodeproj -scheme TippTrainer test
```

Die Testsuite nutzt Swift Testing statt XCTest. Die XCTest-Zusammenfassung
am Ende meldet deshalb `Executed 0 tests` — maßgeblich ist die Zeile
`Test run with 85 tests in 12 suites passed`.

### Visuelle Prüfung ohne Mausklick

Die App kennt Startargumente für Screenshots und Sichtprüfungen. Mit
`--memory-store` bleibt die echte Lernstatistik unberührt:

```sh
open -n build/Build/Products/Debug/TippTrainer.app --args \
     --memory-store --seed-demo --auto-training 2 --auto-type --auto-keys 40
```

- `--memory-store` – flüchtiger Datenspeicher (Pflicht für Testläufe)
- `--seed-demo` – Beispielergebnisse für Startseite und Statistik
- `--auto-training <nr>` – Übungslektion direkt öffnen
- `--auto-type` – Anschläge simulieren (`--auto-keys <n>` begrenzt die
  Anzahl, `--auto-full` tippt bis zum Limit)
- `--screen statistics|game|settings` und `--tab report|lessons|progress|characters|fingers|comparison`
- `-lessonLanguage de|en` – Lektionssprache für diesen Start

## Fehlerbehebung

**`xcodebuild: error: 'TippTrainer.xcodeproj' does not exist.`**
Der Befehl wurde außerhalb des Projektordners ausgeführt. `xcodebuild` löst
den Projektpfad relativ zum aktuellen Verzeichnis auf — zuerst `cd` in den
geklonten Ordner.

**`resource fork, Finder information, or similar detritus not allowed`**
Die Code-Signierung bricht ab, weil der Build-Ordner in einem
iCloud-synchronisierten Verzeichnis liegt und dort das erweiterte Attribut
`com.apple.FinderInfo` gesetzt wird. Entweder das Repository außerhalb von
iCloud klonen (empfohlen), oder das Build-Verzeichnis auslagern:

```sh
xcodebuild -project TippTrainer.xcodeproj -scheme TippTrainer \
           -configuration Release -derivedDataPath /tmp/TippTrainer-build build
```

## Rechtliches

Die Trainingsmechanik ist dem TIPP10-Konzept nachempfunden; sämtlicher Code
und alle Lektionstexte sind eigenständig erstellt. Die Diktattexte stammen aus
gemeinfreien Quellen — Autor und Erscheinungsjahr stehen bei jedem Text in
`TippTrainer/Content/dictations.json` (Goethe 1780, Claudius 1779,
Eichendorff 1837 und weitere) — oder wurden selbst verfasst.

`tools/copyright_audit.py` prüft zusätzlich automatisiert, dass keine Texte
aus der Original-TIPP10-Datenbank übernommen wurden (Abgleich über
normalisierte Wort-n-Gramme, Referenz-Dump nicht Teil des Repositories).

Lizenz: MIT, siehe `LICENSE`.
