# Spettro — Chinese (Simplified)

Campi da incollare in App Store Connect. Fra parentesi il limite di Apple, in caratteri.

| campo | valore |
|---|---|
| Nome (30) | `Spettro` |
| Sottotitolo (30) | `菜单栏里的音频频谱分析仪` |
| Keyword (100) | `频谱,分析仪,音频,电平表,FFT,菜单栏,音乐,均衡器,可视化,分贝` |
| Categoria | Utility (secondaria: Musica) |
| Prezzo | Gratis |
| Età | 4+ |
| URL assistenza | (una pagina tua, o il repo se lo pubblichi) |
| URL privacy | obbligatorio anche se è gratis: una paginetta «non raccolgo dati» |

## Descrizione

```
Spettro 把 Mac 输出音频的频谱分析仪放进菜单栏：从 40 Hz 到 16 kHz 的 20 个频段，竖直分段条，底部绿色、顶部红色，峰值像老式音响上的分析仪那样悬停。

全部只占菜单栏的一小块：不用一直开着窗口，也不影响你正在听的声音。

• 20 个对数间隔频段，40 Hz 到 16 kHz
• 峰值保持，可关闭
• 两种显示样式：点或实心条
• 四档灵敏度：满量程 −30、−48、−66 或 −78 dB
• 可调斜率：平坦、+3 或 +4.5 dB/倍频程，类似粉红加权的 RTA
• 四种大小，从紧凑到最大
• LED 颜色可调，像真正的分析仪
• 刷新率可调（每秒 8-30 次）：这是唯一真正影响功耗的开关
• 不录音、不保存、不联网：只读取电平并画出来
• 安静时停止绘制，不消耗 CPU（实测：空闲约 0.1%，工作时约 5%）

需要读取输出音频的权限：没有它就没有可画的内容。音频在内存中分析并立即丢弃。
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
