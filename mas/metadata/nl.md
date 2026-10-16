# Spettro — Dutch

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Audiopectrum in de menubalk` |
| Keyword (100) | `spectrum,analysator,audio,vumeter,fft,menubalk,muziek,equalizer,visualisatie,decibel` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro zet een spectrumanalyzer voor de uitvoeraudio van je Mac in de menubalk: 20 banden van 40 Hz tot 16 kHz, verticale segmentbalken, groen onderaan en rood bovenaan, met pieken die blijven hangen zoals op de oude hi-fi displays.

Alles in een klein stukje menubalk: geen venster dat open moet blijven en geen invloed op de audio die je luistert.

• 20 logaritmisch verdeelde banden, 40 Hz tot 16 kHz
• piek vasthouden, uit te schakelen
• twee weergavestijlen: stippen of volle balken
• vier gevoeligheden, volle schaal −30, −48, −66 of −78 dB
• aanpasbare helling: vlak, +3 of +4,5 dB per octaaf, zoals een RTA met roze weging
• vier groottes, van compact tot maximaal
• aanpasbare LED-kleuren, zoals op een echte analyzer
• aanpasbare vernieuwingsfrequentie (8-30 per seconde): de enige echte knop op het verbruik
• neemt niets op, bewaart niets, stuurt niets: leest een niveau en tekent het
• bij stilte stopt het tekenen en verbruikt het geen CPU (gemeten: ~0,1 % in rust, ~5 % actief)

Het heeft toestemming nodig om de uitvoeraudio te lezen: zonder die toestemming is er niets te tekenen. De audio wordt in het geheugen geanalyseerd en direct weggegooid.
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
