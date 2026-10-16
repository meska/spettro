# Spettro

Analizzatore di spettro nella barra dei menu: legge l'audio in uscita e disegna 20 bande verticali
a segmenti — verdi in basso, gialle e rosse in alto, con il picco che resta appeso come sui vecchi
analizzatori dei cassoni hi-fi. In dieci lingue.

Sostituisce "Menu Bar Audio Visualizer" (mbvisualizer), che sullo stesso Mac sta al 52-61% di CPU.

## Quanto costa davvero

Misurato con lo stesso metodo (delta di tempo CPU su una finestra di 15-20 secondi), in coppia per
non farsi ingannare dai cambi di carico della macchina:

| | CPU |
|---|---|
| a riposo, silenzio (il timer si spegne) | **~0,1%** |
| senza disegnare affatto (`--nofeed`) | **1,07%** |
| disegnando a 24 fps su macchina tranquilla | **2,8%** |
| stesso codice con la macchina carica (musica, Obsidian, browser, WindowServer al 48%) | **6-13%** |
| disegnando 24/s ma consegnando alla barra 6/s (`--commit 4`) | **3,0%** |

Due cose che questa tabella dice e che vanno dette:

1. **Il lavoro vero è ~1%**: tap, ring buffer, FFT da 2048 punti, 20 bande.
2. **Consegnare alla barra 4 volte meno non cambia niente** (2,83 contro 3,00, dentro il rumore).
   Quindi non è la consegna che costa: è *disegnare* l'immagine. Ecco perché la GPU non serve —
   al massimo toccherebbe 1,8 punti su un totale di 3, e non li toccherebbe nemmeno, perché i pixel
   già costano nulla; il costo è l'impalcatura per frame, che Metal non elimina.

I valori alti (6-13%) sono la macchina, non l'app: in quegli istanti WindowServer stava al 48% e i
due helper di Hermes al 37% e 22%.

## Menu (tutto si ricorda fra un avvio e l'altro)

- **Sensibilità**: Molto sensibile (−78) · Sensibile (−66) · Normale (−48) · Da concerto (−30)
- **Display**: Punti (a trattini, come il VFD del Technics) · Barre (colonne piene)
- **Dimensione**: Compatta · Normale · Larga · Massima (l'altezza si ferma al tetto della barra)
- **Pendenza**: Piatta (misurata) · +3 dB per ottava · **+4,5 dB per ottava (predefinita)** — vedi
  "Perché il fianco sinistro sta sempre su": a piatta il display è la verità misurata, ma con la
  musica il fianco sinistro resta un muro, quindi la scelta di partenza è +4,5.
- **Peak hold** on/off · **Aggiornamento**: 30 / 24 / 16 / 8 al secondo
- **Colori…**: finestra con i quattro campioni (verde, ambra, rosso, tacca del picco), un cursore
  per quanto si vedono i segmenti spenti, e "Ripristina". Le modifiche si applicano subito e si
  salvano da sole (`UserDefaults`, dominio `net.meskatech.spettro`).
- **Riavvia la cattura audio** · **Esci**

## Perché il fianco sinistro sta sempre su

Confrontato con mbvisualizer (18 bande, ocra) sullo stesso rumore basso-pesante, stesso volume:

| | colonne | passo | altezze dal basso (px) |
|---|---|---|---|
| mbvisualizer | 18 | 11,4 px | 20 32 34 34 33 27 28 24 25 24 22 19 17 15 13 11 10 8 |
| Spettro | 20 | 15,6 px | 27 27 25 22 25 25 22 21 17 18 17 14 14 10 10 10 6 |

Entrambe hanno la sinistra più alta: la musica ha davvero 20-30 dB più energia in basso. Ma mbvisualizer
ha il picco sulle colonne 2-4, mentre le nostre prime sei stanno tutte fra 22 e 27 su un massimo di 27 —
un muro piatto. Due cause, misurate:

1. **Non è una sovrastima.** Toni a livello noto: 40 Hz a −10,5 dBFS legge −10,4; 80 Hz −11,7;
   160 Hz −10,1; 600 Hz −10,8. La misura è corretta.
2. **La finestra di Hann allarga.** A 2048 punti la risoluzione è 23 Hz, ma le bande basse distano
   14-40 Hz: la griglia è più fine della risoluzione, quindi un tono basso accende **tre** barre
   identiche (40, 54, 75 Hz) invece di una.

Rimedi, entrambi nel menu o nel binario:

- **Pendenza** (menu): offset per banda `dB/ottava · log2(centro/1000)`, centrato su 1 kHz. Su rumore
  basso-pesante l'escursione fra la banda più forte e la più debole scende da **29,2 a 13,0 dB**;
  lo scostamento per banda coincide con la formula entro 0,1 dB. A "Piatta" il display è la verità
  misurata, quindi la scelta resta dell'utente.
- **FFT 4096** (`--fft 4096`, non ancora nel menu): un tono a 40 Hz passa da 3 bande a fondo scala a
  2, e la banda successiva da −6 dB a −15 dB. Costo in CPU non misurabile (7,4-8,7% contro
  7,8-8,2%). In cambio la finestra raddoppia (43 → 85 ms) e la costante di taratura andrebbe
  rimisurata per la nuova dimensione (fino a ~2 dB di differenza su un tono, perdita di scalloping).

## Come funziona

- `Sources/AudioMeter.swift` — tap CoreAudio su tutto l'audio in uscita
  (`AudioHardwareCreateProcessTap` + device aggregato privato con il dispositivo di uscita come
  clock). Un IOProc scrive gli ultimi campioni in un ring buffer e segnala al main thread solo
  quando arriva segnale. L'audio non viene toccato né registrato: `muteBehavior = .unmuted`.
- `Sources/SpectrumAnalyzer.swift` — FFT di 2048 punti (vDSP) con finestra di Hann, 20 bande
  logaritmiche da 40 Hz a 16 kHz, livello = **massimo** delle righe in banda (non la media: una
  banda larga altrimenti legge fino a 15 dB sotto un tono che la attraversa).
  `measuredWindowGain` è un numero **misurato**, non dedotto: vedi "Taratura".
- `Sources/MeterImageRenderer.swift` — **il percorso di disegno predefinito**: il meter viene
  disegnato in un bitmap fuori schermo e consegnato alla status item come `NSImage`. Costa un po'
  meno che tenere una view viva là dentro (5,65% contro 6,00% misurati) ed è il modo che Apple
  raccomanda per una status item che si aggiorna spesso.
- `Sources/SpectrumView.swift` — la stessa cosa ma con una view viva dentro la status item
  (si sceglie con `--view`, per confronto).
- `Sources/main.swift` — status item, ballistica per banda (attacco immediato, rilascio lento),
  timer spento dopo 1,2 s di silenzio, menu con sensibilità, stile display, peak hold, frequenza di
  aggiornamento. Con `--log` stampa anche i contatori (callback audio/s, render/s, ridisegni/s) e
  con `--nofeed` stacca il disegno: è così che ho scoperto dove andava la CPU.

## Compilare e installare

```bash
./build.sh                              # universale (arm64 + x86_64): compila, firma, installa
open -a ~/Applications/Spettro.app
```

Per default firma ad hoc; con `SPETTRO_IDENTITY="Developer ID Application: …" ./build.sh` usa la tua identità.
Richiede macOS 14.2 o successivo (il tap sull'audio di sistema non esiste prima).
Per il debug: lanciare il binario con `--log` e leggere stderr — stampa le 20 bande in dBFS e la
CPU propria. Con `--dump-menu` stampa il menu localizzato ed esce, senza avviare il tap audio.

## Taratura (perché quei numeri sono quelli)

Con un tono campione a **−10,5 dBFS** (ampiezza 0,30) le bande leggevano −6,8 dB, cioè 1,53 volte
troppo: è il guadagno complessivo della finestra di Hann normalizzata di vDSP con la convenzione
`zrip`, che non è deducibile a tavolino senza sbagliare. Il fattore è in `measuredWindowGain` e i
toni di prova ora leggono:

| tono | banda | lettura |
|---|---|---|
| 1000 Hz | 911 Hz | −10,5 dB ✓ |
| 8000 Hz | 7323 Hz | −10,5 dB ✓ |
| 60 Hz | 40-87 Hz | −11 dB su quattro bande (la finestra corta non separa il fondoscala) |

Le bande senza segnale stanno sotto −69 dB: oltre 58 dB di separazione fra la banda attiva e le altre.

## Permesso audio (importante)

L'app chiede **«registrazione dell'audio di sistema»**: senza, `AudioMeter.start()` si blocca in
attesa e non c'è niente da disegnare. Note verificate sul campo, sbagliando prima:

- Il dialogo compare **la prima volta che un'app con quella identità crea un tap**, comunque sia
  lanciata: Finder, `open -a`, login item o binario lanciato a mano dal terminale. Mentre aspetta,
  il thread principale è bloccato dentro `start()` e **non scrive una riga di log**: se l'app è viva
  e muta, guarda lo schermo prima di cercare un bug nel codice.
- La decisione è legata a **bundle id + firma**. Cambiare `CFBundleIdentifier` la azzera e il dialogo
  ricompare: decidi l'identità *prima* di mettere l'app in mano a qualcuno, o gli farai cliccare due
  volte. È successo qui, passando da `net.meskatech.vumeter` a `net.meskatech.spettro`.
- Se si risponde "Non consentire" per sbaglio: Impostazioni di Sistema → Privacy e sicurezza →
  **Registrazione schermo e audio di sistema** → spuntare l'app.
- Il testo del dialogo è `NSAudioCaptureUsageDescription` da `Info.plist`: è quello che l'utente
  legge, quindi va scritto come un essere umano e non come una nota legale.

## Lingue (dieci)

Menu, finestra dei colori, avvisi e il testo del dialogo di permesso audio sono tradotti in
italiano, inglese, tedesco, francese, spagnolo, portoghese, olandese, giapponese, cinese
semplificato e russo. Il testo del permesso lo serve macOS da `InfoPlist.strings`, quindi non passa
dal codice: è per questo che vive nello stesso posto delle altre stringhe.

Il sorgente unico è `mas/l10n.json`. I `.strings` **non si modificano a mano**:

```bash
python3 mas/l10n.py gen       # riscrive Resources/<lingua>.lproj/
python3 mas/l10n.py check     # chiavi allineate, segnaposto coerenti, plist validi
python3 mas/l10n.py verify    # lancia l'app vera in ognuna delle lingue e confronta il menu
```

`build.sh` copia le cartelle `.lproj` in `Contents/Resources/`: è quella presenza a rendere l'app
multilingua, non c'è niente da dichiarare nell'`Info.plist`.

Per **vedere** una lingua senza cambiare quella del sistema — il menu viene stampato ed esce, senza
avviare il tap audio:

```bash
./build/Spettro.app/Contents/MacOS/Spettro --dump-menu -AppleLanguages '(ja)'
```

Due cose imparate facendolo, che valgono per la prossima volta:

- Le etichette della finestra dei colori avevano larghezza **fissa a 150 punti**: in russo
  «Жёлтый (высокие уровни)» usciva tagliato a metà parola. Ora la larghezza si misura sul testo più
  lungo della lingua attiva e la finestra si adatta al contenuto. Una lingua più lunga
  dell'italiano è il modo più rapido per scoprire un layout a misura fissa.
- Il numero delle bande era **20** nel codice e **24** in tre punti di questo README e nella bozza
  di descrizione: corretto a 20. Se un numero compare in un testo, verificarlo nel codice prima di
  tradurlo in dieci lingue.

## Mac App Store

In `mas/` c'è tutto per lo store: entitlements della sandbox, generatore d'icona, script di
pacchettizzazione, le schede per App Store Connect (`mas/metadata/<lingua>.md`, generate e
verificate da `mas/metadata.py`) e `mas/APPSTORE.md` con stato e passi.

**Verificato**: con `com.apple.security.app-sandbox` + `com.apple.security.device.audio-input` il tap
globale funziona ancora (l'app ha girato col suo container in `~/Library/Containers/` leggendo
livelli veri). Era il rischio grosso della sandbox obbligatoria, ed è caduto.

## Note

- Sviluppato in `~/Dev/vumeter` (progetto Hermes `vumeter`). Il nome della cartella è rimasto
  quello vecchio quando l'app si chiamava VUmeter.
- L'app è `LSUIElement`: nessuna icona nel Dock. Il login item si imposta da Impostazioni di
  Sistema → Generali → Elementi login.

## Licenza

MIT, vedi `LICENSE`.
