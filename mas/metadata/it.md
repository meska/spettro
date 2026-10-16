# Spettro — Italian  (lingua primaria)

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Analizzatore audio nella barra` |
| Keyword (100) | `spettro,analizzatore,audio,vumeter,fft,menu bar,musica,equalizzatore,visualizzatore,decibel` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro mette l'analizzatore di spettro dell'audio in uscita nella barra dei menu del Mac: 20 bande da 40 Hz a 16 kHz, barre verticali a segmenti, verdi in basso e rosse in alto, con i picchi che restano appesi come sui vecchi analizzatori dei cassoni hi-fi.

Tutto in un pezzetto di barra dei menu: nessuna finestra da tenere aperta, nessun impatto sull'audio che stai ascoltando.

• 20 bande, spaziatura logaritmica da 40 Hz a 16 kHz
• picco che resta appeso (peak hold), disattivabile
• due stili di display: a punti o a barre piene
• quattro sensibilità, fondo scala −30, −48, −66 o −78 dB
• pendenza regolabile: piatta, +3 o +4,5 dB per ottava, come un RTA con pesatura rosa
• quattro dimensioni, da compatta a massima
• colori dei LED regolabili, come su un analizzatore vero
• frequenza di aggiornamento regolabile (8-30 al secondo): è l'unica leva sul consumo
• non registra, non salva, non manda niente in rete: legge un livello e lo disegna
• con il silenzio spegne il disegno e non consuma CPU (misurato: ~0,1% fermo, ~5% in attività)

Serve il permesso di leggere l'audio in uscita: senza, l'app non ha nulla da disegnare. L'audio viene analizzato in memoria e buttato via nello stesso istante.
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
