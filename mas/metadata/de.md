# Spettro — German

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Spektrum in der Menüleiste` |
| Keyword (100) | `spektrum,analysator,audio,vumeter,fft,menüleiste,musik,equalizer,visualisierung,dezibel` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro legt einen Spektrumanalysator für das Ausgangsaudio deines Macs direkt in die Menüleiste: 20 Bänder von 40 Hz bis 16 kHz, senkrechte Segmentbalken, unten grün und oben rot, mit Spitzen, die wie bei den alten Hi-Fi-Anzeigen hängen bleiben.

Alles in einem kleinen Stück Menüleiste: kein Fenster, das offen bleiben muss, kein Einfluss auf das Audio, das du gerade hörst.

• 20 logarithmisch verteilte Bänder, 40 Hz bis 16 kHz
• Peak-Hold, abschaltbar
• zwei Anzeigestile: Punkte oder volle Balken
• vier Empfindlichkeiten, Vollausschlag −30, −48, −66 oder −78 dB
• einstellbare Neigung: flach, +3 oder +4,5 dB pro Oktave, wie ein RTA mit rosa Bewertung
• vier Größen, von kompakt bis maximal
• einstellbare LED-Farben, wie bei einem echten Analysator
• einstellbare Aktualisierungsrate (8-30 pro Sekunde): der einzige echte Hebel beim Verbrauch
• zeichnet nichts auf, speichert nichts, sendet nichts: liest einen Pegel und zeichnet ihn
• bei Stille wird das Zeichnen abgeschaltet (gemessen: ~0,1 % im Ruhezustand, ~5 % bei Aktivität)

Es braucht die Erlaubnis, das Ausgangsaudio zu lesen — ohne sie gibt es nichts zu zeichnen. Das Audio wird im Speicher analysiert und sofort verworfen.
```

## Note per la review (in inglese, le leggono loro)

```
The app reads the level of the OUTPUT audio (Core Audio process tap on a private
aggregate device) only to draw a spectrum analyzer in the menu bar.

It does not record, does not write to disk and does not transmit anything: the tap produces FFT
magnitudes and peaks, which are drawn and immediately overwritten. There is no networking code in
the app.

The system audio recording permission is requested on first launch; without it there is nothing to
draw (the reason is declared in NSAudioCaptureUsageDescription in Info.plist).

To see something during review, just play any track: the bars move.
```
