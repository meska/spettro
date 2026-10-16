# Spettro — Japanese

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `メニューバーのスペクトラムアナライザー` |
| Keyword (100) | `スペクトラム,アナライザー,オーディオ,レベルメーター,FFT,メニューバー,音楽,イコライザー,ビジュアライザー,デシベル` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro は、Mac の出力オーディオのスペクトラムアナライザーをメニューバーに表示します。40 Hz から 16 kHz までの 20 バンド、縦のセグメントバー、下は緑で上は赤、そして昔のコンポのアナライザーのようにピークが残ります。

メニューバーのわずかなスペースだけで、開いたままにするウインドウもなく、再生中の音にも影響しません。

• 40 Hz 〜 16 kHz を対数間隔で分けた 20 バンド
• ピークホールド（オフにできます）
• 表示スタイルは 2 種類：ドットまたは連続バー
• 感度は 4 段階、フルスケール −30 / −48 / −66 / −78 dB
• 傾きの調整：フラット / +3 / +4.5 dB/オクターブ（ピンクウェイトの RTA のように）
• サイズは 4 段階、コンパクトから最大まで
• LED の色は自由に変更可能
• 更新頻度は 8〜30 回/秒で調整可能（消費電力に効く唯一のつまみ）
• 録音も保存も送信もしません。レベルを読んで描くだけです
• 無音時は描画を停止し CPU を消費しません（実測：停止時 ~0.1%、動作時 ~5%）

出力オーディオを読み取る許可が必要です。許可がないと描くものがありません。音声はメモリ上で解析され、その場で破棄されます。
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
