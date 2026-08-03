# TippTrainer

Ein moderner Zehnfinger-Schreibtrainer für macOS — funktional inspiriert vom
klassischen TIPP10 (dessen macOS-Version seit Catalina nicht mehr läuft),
komplett neu implementiert in Swift/SwiftUI mit eigenständigen Inhalten.

## Funktionen

- 20 aufeinander aufbauende Übungslektionen (Deutsch QWERTZ + Englisch QWERTY)
- Intelligente Diktate: fehlerträchtige Zeichen werden häufiger wiederholt
- Freie Diktate und eigene Lektionen (Satz-/Wortdiktat, Import/Export)
- Laufschrift mit adaptiver Geschwindigkeit, virtuelle Tastatur mit
  Fingerfarben, Tastwegen und Grundstellungsanzeige
- Umfassende Lernstatistik (Bericht, Verlauf, Zeichen-/Finger-Auswertung)
- Buchstabenregen-Spiel

## Build

```sh
xcodebuild -project TippTrainer.xcodeproj -scheme TippTrainer build
```

Benötigt Xcode 26+ / macOS 26.

## Rechtliches

Die Trainingsmechanik ist dem TIPP10-Konzept nachempfunden; sämtlicher Code
und alle Lektionstexte sind eigenständig erstellt. Die Diktattexte stammen aus
gemeinfreien Quellen — Autor und Erscheinungsjahr stehen bei jedem Text in
`TippTrainer/Content/dictations.json` (Goethe 1780, Claudius 1779,
Eichendorff 1837 und weitere) — oder wurden selbst verfasst.

Lizenz: MIT, siehe `LICENSE`.
