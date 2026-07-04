#!/usr/bin/env python3
"""Copyright-Audit: prüft, dass keine Lektions- oder Diktattexte aus der
Original-TIPP10-Datenbank übernommen wurden.

Vergleicht alle Segmente der eigenen Content-JSONs mit den Segmenten des
GPL-Original-Dumps über normalisierte Wort-n-Gramme. Ein Treffer eines
langen wörtlichen n-Gramms (>= NGRAM Wörter) gilt als potenzielle
Übernahme und lässt den Audit fehlschlagen.

Aufruf:
    python3 tools/copyright_audit.py <original_dump.sql>

Der Original-Dump ist NICHT Teil des Repos (nur Referenz während der
Entwicklung). Fehlt er, überspringt der Audit den Abgleich und meldet das.
"""
import json
import pathlib
import re
import sys

NGRAM = 6  # Wörtliche Wortfolgen ab dieser Länge gelten als verdächtig.
CONTENT_DIR = pathlib.Path(__file__).resolve().parent.parent / "TippTrainer" / "Content"


def normalize(text: str) -> list[str]:
    text = text.lower()
    text = re.sub(r"[^\wäöüß ]", " ", text)
    return text.split()


def ngrams(words: list[str], n: int) -> set[tuple[str, ...]]:
    return {tuple(words[i : i + n]) for i in range(len(words) - n + 1)}


def own_segments() -> list[str]:
    segments: list[str] = []
    for path in CONTENT_DIR.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        entries = data if isinstance(data, list) else [data]
        for entry in entries:
            segments.extend(entry.get("segments", []))
            if entry.get("intro"):
                segments.append(entry["intro"])
    return segments


def original_ngrams(dump_path: pathlib.Path) -> set[tuple[str, ...]]:
    content_re = re.compile(r"VALUES\(\d+,'(.*)',\d+\);")
    grams: set[tuple[str, ...]] = set()
    for line in dump_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        match = content_re.search(line)
        if not match:
            continue
        words = normalize(match.group(1).replace("''", "'"))
        grams |= ngrams(words, NGRAM)
    return grams


def main() -> int:
    own = own_segments()
    print(f"Eigene Segmente geprüft: {len(own)}")

    if len(sys.argv) < 2:
        print("Kein Original-Dump angegeben – Abgleich übersprungen.")
        print("Formale Prüfung (eigene Inhalte vorhanden):", "OK" if own else "LEER")
        return 0 if own else 1

    dump_path = pathlib.Path(sys.argv[1])
    if not dump_path.exists():
        print(f"Original-Dump nicht gefunden: {dump_path} – Abgleich übersprungen.")
        return 0

    original = original_ngrams(dump_path)
    print(f"Original-{NGRAM}-Gramme geladen: {len(original)}")

    matches: list[tuple[str, tuple[str, ...]]] = []
    for segment in own:
        for gram in ngrams(normalize(segment), NGRAM):
            if gram in original:
                matches.append((segment, gram))

    if matches:
        print(f"\n❌ AUDIT FEHLGESCHLAGEN: {len(matches)} verdächtige Übernahme(n):")
        for segment, gram in matches[:20]:
            print(f"  »{segment}«  ⟶  {' '.join(gram)}")
        return 1

    print(f"\n✅ AUDIT BESTANDEN: keine wörtlichen {NGRAM}-Wort-Folgen aus dem Original.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
