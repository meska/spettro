# Spettro — English (U.S.)

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Audio spectrum in the menu bar` |
| Keyword (100) | `spectrum,analyzer,audio,vumeter,fft,menu bar,music,equalizer,visualizer,decibel` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro puts a spectrum analyzer for your Mac's output audio right in the menu bar: 20 bands from 40 Hz to 16 kHz, vertical segmented bars, green at the bottom and red at the top, with peaks that hang like on the old hi-fi displays.

All in a small piece of menu bar: no window to keep open, no effect on the audio you are listening to.

• 20 log-spaced bands, 40 Hz to 16 kHz
• peak hold, can be turned off
• two display styles: dots or solid bars
• four sensitivities, −30, −48, −66 or −78 dB full scale
• adjustable slope: flat, +3 or +4.5 dB per octave, like an RTA with pink weighting
• four sizes, from compact to max
• adjustable LED colors, like on a real analyzer
• adjustable refresh rate (8-30 per second): the only real lever on power use
• records nothing, stores nothing, sends nothing: it reads a level and draws it
• goes to zero CPU when the room is quiet (measured: ~0.1% idle, ~5% busy)

It needs permission to read the output audio — without it there is nothing to draw. The audio is analyzed in memory and discarded immediately.
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
