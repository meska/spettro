# Spettro — Portuguese (Portugal)

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `Analisador de espetro na barra` |
| Keyword (100) | `espetro,analisador,áudio,vúmetro,fft,barra de menus,música,equalizador,visualizador,decibéis` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
O Spettro coloca o analisador de espetro do áudio de saída do teu Mac na barra de menus: 20 bandas de 40 Hz a 16 kHz, barras verticais segmentadas, verdes em baixo e vermelhas em cima, com picos que ficam pendurados como nos antigos analisadores das aparelhagens.

Tudo num pedacinho da barra de menus: nenhuma janela para deixar aberta e nenhum efeito no áudio que estás a ouvir.

• 20 bandas com espaçamento logarítmico, de 40 Hz a 16 kHz
• retenção do pico, pode ser desligada
• dois estilos de visualização: pontos ou barras cheias
• quatro sensibilidades, fundo de escala −30, −48, −66 ou −78 dB
• inclinação ajustável: plana, +3 ou +4,5 dB por oitava, como um RTA com ponderação rosa
• quatro tamanhos, de compacta a máxima
• cores dos LEDs ajustáveis, como num analisador a sério
• frequência de atualização ajustável (8-30 por segundo): a única alavanca real no consumo
• não grava nada, não guarda nada, não envia nada: lê um nível e desenha-o
• no silêncio desliga o desenho e não gasta CPU (medido: ~0,1 % parado, ~5 % em atividade)

Precisa de permissão para ler o áudio de saída: sem ela não há nada para desenhar. O áudio é analisado em memória e descartado no mesmo instante.
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
