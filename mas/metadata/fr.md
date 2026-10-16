# Spettro — French

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Analyseur de spectre audio` |
| Keyword (100) | `spectre,analyseur,audio,vumètre,fft,barre de menus,musique,égaliseur,visualiseur,décibels` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro installe l'analyseur de spectre de l'audio de sortie de votre Mac dans la barre des menus : 20 bandes de 40 Hz à 16 kHz, barres verticales segmentées, vert en bas et rouge en haut, avec des crêtes qui restent accrochées comme sur les vieux analyseurs des chaînes hi-fi.

Le tout dans un petit morceau de barre des menus : aucune fenêtre à laisser ouverte, aucun effet sur l'audio que vous écoutez.

• 20 bandes espacées logarithmiquement, de 40 Hz à 16 kHz
• maintien des crêtes (peak hold), désactivable
• deux styles d'affichage : points ou barres pleines
• quatre sensibilités : pleine échelle −30, −48, −66 ou −78 dB
• pente réglable : plate, +3 ou +4,5 dB par octave, comme un RTA à pondération rose
• quatre tailles, de compacte à maximale
• couleurs des LED réglables, comme sur un vrai analyseur
• fréquence de rafraîchissement réglable (8 à 30 par seconde) : le seul vrai levier sur la consommation
• n'enregistre rien, ne stocke rien, n'envoie rien : lit un niveau et le dessine
• au silence, l'affichage s'éteint et ne consomme pas de CPU (mesuré : ~0,1 % au repos, ~5 % en activité)

L'autorisation de lire l'audio de sortie est nécessaire : sans elle, l'app n'a rien à dessiner. L'audio est analysé en mémoire et jeté aussitôt.
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
