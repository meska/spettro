# Spettro — Spanish (Spain)

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Espectro de audio en la barra` |
| Keyword (100) | `espectro,analizador,audio,vúmetro,fft,barra de menús,música,ecualizador,visualizador,decibelios` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro pone el analizador de espectro del audio de salida de tu Mac en la barra de menús: 20 bandas de 40 Hz a 16 kHz, barras verticales segmentadas, verdes abajo y rojas arriba, con picos que se quedan colgados como en los viejos analizadores de los equipos hi-fi.

Todo en un trocito de la barra de menús: ninguna ventana que dejar abierta y ningún efecto sobre el audio que estás escuchando.

• 20 bandas con espaciado logarítmico, de 40 Hz a 16 kHz
• retención del pico, se puede desactivar
• dos estilos de visualización: puntos o barras llenas
• cuatro sensibilidades, fondo de escala −30, −48, −66 o −78 dB
• pendiente ajustable: plana, +3 o +4,5 dB por octava, como un RTA con ponderación rosa
• cuatro tamaños, de compacta a máxima
• colores de los LED ajustables, como en un analizador de verdad
• frecuencia de actualización ajustable (8-30 por segundo): la única palanca real sobre el consumo
• no graba nada, no guarda nada, no envía nada: lee un nivel y lo dibuja
• con silencio apaga el dibujo y no consume CPU (medido: ~0,1 % en reposo, ~5 % en actividad)

Necesita permiso para leer el audio de salida: sin él no hay nada que dibujar. El audio se analiza en memoria y se descarta al instante.
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
