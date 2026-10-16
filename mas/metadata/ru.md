# Spettro — Russian

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Анализатор спектра звука` |
| Keyword (100) | `спектр,анализатор,аудио,уровень,БПФ,строка меню,музыка,эквалайзер,визуализация,децибел` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro помещает анализатор спектра выходного звука вашего Mac прямо в строку меню: 20 полос от 40 Гц до 16 кГц, вертикальные сегментные полосы, зелёные внизу и красные сверху, а пики остаются висеть, как на старых индикаторах музыкальных центров.

Всё это в маленьком кусочке строки меню: никаких окон, которые нужно держать открытыми, и никакого влияния на звук, который вы слушаете.

• 20 полос с логарифмическим шагом, от 40 Гц до 16 кГц
• удержание пика, можно отключить
• два стиля отображения: точки или сплошные полосы
• четыре режима чувствительности, полная шкала −30, −48, −66 или −78 дБ
• регулируемый наклон: ровно, +3 или +4,5 дБ на октаву, как у RTA с розовой коррекцией
• четыре размера, от компактного до максимального
• настраиваемые цвета светодиодов, как на настоящем анализаторе
• настраиваемая частота обновления (8-30 раз в секунду): единственный реальный рычаг расхода
• ничего не записывает, не сохраняет и не отправляет: читает уровень и рисует его
• в тишине перестаёт рисовать и не тратит CPU (измерено: ~0,1 % в покое, ~5 % в работе)

Нужно разрешение на чтение выходного звука: без него рисовать нечего. Звук анализируется в памяти и сразу отбрасывается.
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
