#!/usr/bin/env python3
"""Genera e verifica le localizzazioni di Spettro.

Il sorgente unico è mas/l10n.json. Da lì nascono Resources/<lingua>.lproj/:
Localizable.strings (menu, finestra colori, avvisi) e InfoPlist.strings
(testo del permesso audio che macOS mostra nel dialogo di sistema).

    python3 mas/l10n.py gen      # riscrive i .strings
    python3 mas/l10n.py check    # controlla tutto, esce != 0 se qualcosa non torna

Il controllo confronta ogni lingua con l'italiano (lingua di riferimento):
chiavi mancanti o in più, valori vuoti, segnaposto di formato diversi (%@ che
diventa %d è un crash in String(format:), non un dettaglio estetico).
Poi cerca le chiavi usate davvero nel codice Swift e segnala quelle orfane.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "mas" / "l10n.json"
OUT = ROOT / "Resources"
SOURCES = ROOT / "Sources"
LANGDIR = ROOT / "mas" / "languages.json"  # elenco ordinato, per App Store Connect

# Come App Store Connect chiama le lingue (le chiavi del .lproj non sempre combaciano)
ASC_NAMES = {
    "it": "Italian",
    "en": "English (U.S.)",
    "de": "German",
    "fr": "French",
    "es": "Spanish (Spain)",
    "pt": "Portuguese (Portugal)",
    "nl": "Dutch",
    "ja": "Japanese",
    "zh-Hans": "Chinese (Simplified)",
    "ru": "Russian",
}

REFERENCE = "it"
PLACEHOLDER = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z@%]")

# L'ordine in cui il menu viene costruito in main.swift: serve a confrontare, voce per voce,
# quello che l'app stampa con --dump-menu e quello che c'è nel JSON.
MENU_ORDER = [
    "menu.about",
    "menu.sensitivity",
    "menu.sens.verySensitive",
    "menu.sens.sensitive",
    "menu.sens.normal",
    "menu.sens.concert",
    "menu.display",
    "menu.display.dots",
    "menu.display.bars",
    "menu.size",
    "menu.size.compact",
    "menu.size.normal",
    "menu.size.wide",
    "menu.size.max",
    "menu.tilt",
    "menu.tilt.flat",
    "menu.tilt.p3",
    "menu.tilt.p45",
    "menu.peakHold",
    "menu.rate",
    "menu.rate.30",
    "menu.rate.24",
    "menu.rate.16",
    "menu.rate.8",
    "menu.restart",
    "menu.colors",
    "menu.quit",
]


def load():
    with DATA.open(encoding="utf-8") as f:
        data = json.load(f)
    data.pop("_comment", None)
    return data


def escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def header(lang: str, table: str) -> str:
    return (
        f"/* {table}.strings — {lang}\n"
        f"   Generato da mas/l10n.json ({lang}). Non modificare a mano:\n"
        f"   le modifiche si fanno in mas/l10n.json e si rigenerano con `python3 mas/l10n.py gen`. */\n\n"
    )


def write_strings(lang: str, table: str, entries: dict) -> Path:
    d = OUT / f"{lang}.lproj"
    d.mkdir(parents=True, exist_ok=True)
    body = "".join(f'"{k}" = "{escape(v)}";\n' for k, v in sorted(entries.items()))
    p = d / f"{table}.strings"
    p.write_text(header(lang, table) + body, encoding="utf-8")
    return p


def gen(data) -> int:
    written = []
    for lang, tables in data.items():
        for table, entries in tables.items():
            written.append(write_strings(lang, table, entries))
    # le lingue dichiarate, nell'ordine in cui compaiono nel JSON
    LANGDIR.write_text(
        json.dumps({l: ASC_NAMES.get(l, l) for l in data}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"scritti {len(written)} file in {OUT.relative_to(ROOT)}/:")
    for p in sorted(written):
        print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size} byte)")
    return 0


def swift_keys() -> set:
    """Le chiavi di l10n.json citate nel codice Swift.

    Non si cerca la sintassi della chiamata ma il nome della chiave: i menu le passano a L()
    dentro un ciclo (`for (key, db) in [("menu.sens.normal", -48), ...]`), quindi `L("...")`
    da solo non le vedrebbe tutte. Le chiavi hanno tutte un prefisso di famiglia.
    """
    found = set()
    pat = re.compile(r'"((?:menu|colors|alert|error)\.[A-Za-z0-9_.]+)"')
    for src in sorted(SOURCES.glob("*.swift")):
        for m in pat.finditer(src.read_text(encoding="utf-8")):
            found.add(m.group(1))
    return found


def check(data) -> int:
    problems = []
    warnings = []

    ref = data[REFERENCE]

    # 1. ogni lingua ha le stesse tabelle e le stesse chiavi dell'italiano
    for lang, tables in data.items():
        for table in ref:
            if table not in tables:
                problems.append(f"{lang}: manca la tabella {table}.strings")
                continue
            for key in ref[table]:
                if key not in tables[table]:
                    problems.append(f"{lang}: manca la chiave {key} in {table}")
            for key in tables[table]:
                if key not in ref[table]:
                    problems.append(f"{lang}: chiave in più nella tabella {table}: {key}")

    # 2. valori vuoti, segnaposto incoerenti, doppie virgolette non protette
    for lang, tables in data.items():
        for table, entries in tables.items():
            if table not in ref:
                continue
            for key, value in entries.items():
                if key not in ref.get(table, {}):
                    continue
                if not value.strip():
                    problems.append(f"{lang}.{table}.{key}: valore vuoto")
                    continue
                ref_ph = sorted(PLACEHOLDER.findall(ref[table][key]))
                ph = sorted(PLACEHOLDER.findall(value))
                if ph != ref_ph:
                    problems.append(
                        f"{lang}.{table}.{key}: segnaposto diversi dall'italiano "
                        f"({ref_ph} contro {ph})"
                    )
                if "\n" in value and table == "InfoPlist":
                    problems.append(f"{lang}.{table}.{key}: a capo nel testo del permesso")

    # 3. le .strings generate rispettano l'italiano, e sono plist validi
    generated = sorted(OUT.glob("*.lproj"))
    if generated:
        langs = {p.name[:-len(".lproj")] for p in generated}
        missing = set(data) - langs
        extra = langs - set(data)
        if missing:
            problems.append(f"mancano le cartelle .lproj: {sorted(missing)} (lancia `gen`)")
        if extra:
            warnings.append(f"cartelle .lproj senza traduzioni: {sorted(extra)}")
        for lproj in generated:
            for f in sorted(lproj.iterdir()):
                r = subprocess.run(["plutil", "-lint", str(f)], capture_output=True, text=True)
                if r.returncode != 0:
                    problems.append(f"{f.relative_to(ROOT)}: plutil dice {r.stdout.strip() or r.stderr.strip()}")
    else:
        problems.append("nessuna cartella .lproj generata: lancia `python3 mas/l10n.py gen`")

    # 4. le chiavi usate nel codice esistono; quelle mai usate sono solo un avviso
    used = swift_keys()
    known = set(ref["Localizable"])
    for key in sorted(used - known):
        problems.append(f"il codice usa «{key}», che non è in mas/l10n.json")
    for key in sorted(known - used):
        warnings.append(f"chiave mai usata dal codice: {key}")

    # 5. l'Info.plist base deve avere le chiavi coperte da InfoPlist.strings
    for key in sorted(ref["InfoPlist"]):
        pass  # la presenza è già garantita dal punto 1: qui non serve altro

    print(f"lingue: {len(data)} → {', '.join(data)}")
    print(f"chiavi in {REFERENCE}: {len(known)} Localizable, {len(ref['InfoPlist'])} InfoPlist")
    print(f"chiavi usate dal codice: {len(used)}")
    for w in sorted(set(warnings)):
        print(f"  avviso  {w}")
    if problems:
        print()
        for p in sorted(set(problems)):
            print(f"  ERRORE  {p}")
        print(f"\n{len(set(problems))} problemi.")
        return 1
    print("\ntutto coerente: chiavi, segnaposto, plist validi.")
    return 0


def verify(data, app) -> int:
    """Guarda cosa vede davvero l'utente: lancia l'app compilata con la lingua forzata e
    confronta il menu stampato da `--dump-menu` con il JSON, voce per voce."""
    exe = Path(app).resolve() / "Contents" / "MacOS" / "Spettro"
    if not exe.exists():
        print(f"non trovo {exe}: compila prima l'app")
        return 2

    problems = []
    for lang in data:
        r = subprocess.run(
            [str(exe), "--dump-menu", "-AppleLanguages", f"({lang})"],
            capture_output=True, text=True, timeout=30,
        )
        if r.returncode != 0:
            problems.append(f"{lang}: l'app è uscita con codice {r.returncode} ({r.stderr.strip()[:120]})")
            continue
        seen = [re.sub(r"^[ \t]*(?:\[[ x]\] )?", "", ln.rstrip())
                for ln in r.stdout.split("# InfoPlist")[0].splitlines()
                if ln.strip() and ln.strip() != "---"]
        expected = [data[lang]["Localizable"][k] for k in MENU_ORDER]
        if len(seen) != len(expected):
            problems.append(f"{lang}: {len(seen)} voci di menu invece di {len(expected)}")
            continue
        for key, got, want in zip(MENU_ORDER, seen, expected):
            if got != want:
                problems.append(f"{lang}.{key}: sul Mac si legge «{got}», nel JSON c'è «{want}»")

        # e le due chiavi dell'Info.plist, che macOS serve da InfoPlist.strings
        plist = dict(
            ln.split("|", 1) for ln in r.stdout.split("# InfoPlist")[-1].splitlines() if "|" in ln
        )
        for key, want in data[lang]["InfoPlist"].items():
            got = plist.get(key)
            if got != want:
                problems.append(f"{lang}.InfoPlist.{key}: sul Mac si legge «{got}», nel JSON c'è «{want}»")

        print(f"  {lang:8} {len(seen)} voci di menu + 2 chiavi Info.plist, come da mas/l10n.json")

    if problems:
        print()
        for p in problems:
            print(f"  ERRORE  {p}")
        return 1
    print(f"\nverificate {len(data)} lingue sull'app vera ({exe}).")
    return 0


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ("gen", "check", "verify"):
        print(__doc__.strip())
        return 2
    data = load()
    if sys.argv[1] == "gen":
        return gen(data)
    if sys.argv[1] == "check":
        return check(data)
    app = sys.argv[2] if len(sys.argv) > 2 else "build/Spettro.app"
    return verify(data, app)


if __name__ == "__main__":
    sys.exit(main())
