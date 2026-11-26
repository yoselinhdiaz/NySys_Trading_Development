# Velocity ALMA (MQL5) — port del Pine v0.02

Indicador de gráfico para MetaTrader 5 que replica `Velocity ALMA` v0.02 de
TradingView: cinta ALMA (open y close, suavizada por EMA), bandas adaptativas
por desviación absoluta media escalada a sigma, señales BUY/SELL en vela
cerrada y niveles visuales TP1 / TP2 / SL con marcas de toque.

No repinta: la vela en formación solo mueve cinta, bandas y degradado. Las
señales y los niveles se calculan con `close` de vela cerrada, igual que el
Pine. **No es un EA**: no envía órdenes ni toca la cuenta.

Port, paridad y pruebas: Nysys, 26 de noviembre de 2026.

## Fuente

`docs/Velocity_ALMA_v0.02.pine` — Pine v5, 219 líneas, copia local del script
de referencia. Todas las referencias de línea del código MQL5 apuntan a ese
archivo.

| Pine | Qué |
| --- | --- |
| 24 | `indicator("Velocity ALMA", overlay = true, max_bars_back = 300, ...)` |
| 26-66 | Inputs agrupados (Basis, Volatility, Bands, Display, Levels) |
| 69-70 | `basisClose` / `basisOpen` = EMA(ALMA(x), BasisSmooth) |
| **73-74** | **Cadena de volatilidad: `madRaw` y `vol`** |
| 77-84 | `volRank` sobre las `volRankLookback` velas anteriores (na omitidas) |
| 87-90 | `adaptFactor`, `bandHalf`, `upperBand`, `lowerBand` |
| 93-103 | Cruces contra banda + máquina de tendencia (`buySignal`/`sellSignal`) |
| 108-109 | `plot(Buy Signal)` / `plot(Sell Signal)`, solo Data Window |
| 113-115 | Cinta = `fill` entre Basis Open y Basis Close |
| 118-123 | Degradado precio↔basis y `plot` de bandas |
| 124 | `barcolor` según tendencia |
| 145-158 | Hits del trade vigente (SL → TP1 → TP2) |
| 170-179 | Niveles del trade nuevo desde el cierre de la señal |
| 180-212 | Cajas, líneas y etiquetas de precio del trade activo |
| 214-216 | `plotshape` de marcas TP1 / TP2 / SL |
| 218-219 | `alertcondition` BUY / SELL |

### La cadena de volatilidad (Pine 73-74)

```pine
madRaw = ta.sma(math.abs(close - ta.sma(close, volLength)), volLength)
vol    = ta.ema(madRaw, volSmoothLength)
```

Son **dos** SMA encadenadas: `|close - SMA(close, VolLength)|` y después
`SMA(dev, VolLength)`. La SMA exterior es obligatoria. El port la omitía
(`vol = EMA(dev)`) y eso adelantaba `vol` unas 2 velas: en XAUUSD M15 la mitad
de banda se desviaba hasta 35.0 puntos y el factor implícito salía 0.44..4.22
en vez de 0.80..1.80. Corregido el 26/11/2026; con la cadena completa la
paridad es `max|Δ half| = 1.296e-08` y el desfase óptimo 0 velas.

## Contenido y destino de instalación

El árbol de esta carpeta espeja `MQL5\` para que se pueda copiar tal cual.
`replica.py` **no** es necesario para operar: es el gate numérico de paridad.

| En este repo | Destino (carpeta de datos de MT5) |
| --- | --- |
| `Indicators/Nysys/Velocity_ALMA.mq5` | `MQL5\Indicators\Nysys\Velocity_ALMA.mq5` |
| `Include/Nysys/VelocityAlmaCsv.mqh` | `MQL5\Include\Nysys\VelocityAlmaCsv.mqh` |
| `Scripts/Nysys/Tests/Velocity_ALMA_ParityExport.mq5` | `MQL5\Scripts\Nysys\Tests\` |
| `Scripts/Nysys/Tests/replica.py` | `MQL5\Scripts\Nysys\Tests\` |
| `Scripts/Nysys/Tests/replica_README.md` | `MQL5\Scripts\Nysys\Tests\` |

No se versionan `.ex5` ni CSV: se generan en la instalación.

## Instalación en la carpeta de datos de Zeven

La carpeta de datos usada en las pruebas es

```
%APPDATA%\MetaQuotes\Terminal\60A65A94DAA8B356589F816D9F23B900
```

Zeven Global MT5 Terminal build 101435. El identificador `60A65A94…` es de esa
instalación; en otra máquina cambia (Archivo → Abrir carpeta de datos).

1. Copia los tres archivos MQL5 a las rutas de la tabla anterior y, si vas a
   correr el gate, los dos de `Tests\`.
2. Compila sin abrir la interfaz:

   ```powershell
   & 'E:\Program Files\Zeven Global MT5 Terminal 101435\MetaEditor64.exe' `
       /compile:"$env:APPDATA\MetaQuotes\Terminal\60A65A94DAA8B356589F816D9F23B900\MQL5\Indicators\Nysys\Velocity_ALMA.mq5" `
       /log:"$env:TEMP\velocity_alma.log"
   ```

   El resultado esperado es `0 errors, 0 warnings` en la última línea del log.
3. **Vuelve a adjuntar el indicador.** Compilar por línea de comandos no
   recarga un indicador ya adjunto: si no se quita y se vuelve a añadir (o se
   cambia de timeframe y se regresa), el gráfico sigue con el `.ex5` anterior y
   el CSV sale con los valores viejos.
4. Los inputs por defecto son los de la v0.02 (Basis 34 / 0.65 / 20 / 4, Vol 5
   y 5, rank 100, MAD 1.4826, multiplicadores 0.8 y 1.8). Los grupos
   `Display` y `TP1 / TP2 / Stop Loss` solo cambian el dibujo, nunca las
   señales. `InpGradOpacity` y `Diagnóstico` son extras de MT5.

## Cómo correr la paridad

Tres capas independientes; cada una se puede correr sola.

**1. CSV live (camino incremental).** En el indicador adjunto, `InpDumpCsv =
true` e `InpDumpBars = 500`. Al cerrar cada vela escribe
`MQL5\Files\velocity_alma_live_<simbolo>_<timeframe>.csv` (23 columnas). La
primera línea es una cabecera `#reset_time=<hora>;inc_bars=<n>` que separa las
filas del camino incremental de las de un recálculo. La tecla `D` sobre el
gráfico fuerza un volcado inmediato.

**2. Script de comparación.** Ejecuta `Velocity_ALMA_ParityExport` en el mismo
gráfico (`InpBars = 500`, `InpCompare = true`): crea una instancia nueva del
indicador por `iCustom` (recálculo completo), escribe
`velocity_alma_full_<simbolo>_<timeframe>.csv` y compara ambos archivos fila a
fila por `time_server`. Criterio: **0 filas distintas en el camino incremental
y al menos 3 velas comparadas**; con menos velas, o sin metadatos, informa
`INCONCLUSO`. Cualquier diferencia se imprime con hora, columna y valores.

**3. Réplica en Python (gate numérico).**

```powershell
cd "$env:APPDATA\MetaQuotes\Terminal\60A65A94DAA8B356589F816D9F23B900\MQL5\Scripts\Nysys\Tests"
python replica.py "..\..\..\Files\velocity_alma_live_XAUUSD.raw_PERIOD_M15.csv" --rows 300
```

Recalcula la cadena del Pine desde el OHLC del CSV (no lee buffers) y compara
`dev`, `mad_raw`, `vol`, `vol_rank` y `half`. `PASS` exige
`max|Δ half| < 1e-6`; además informa el factor implícito
`half / (1.4826 · vol)` (debe quedar en 0.80..1.80) y el barrido de desfase
(el óptimo tiene que ser `lag+0`). `--chain legacy` reproduce el defecto
anterior y sirve de control negativo. Detalle de uso en
`Scripts/Nysys/Tests/replica_README.md`.

### Resultado de referencia (26/11/2026)

XAUUSD.raw M15, 500 velas, últimas 300 evaluadas, Zeven build 101435:

| Prueba | Resultado |
| --- | --- |
| Incremental vs recálculo completo (por `time_server`) | 0 diferencias en 3 velas vivas, incluida la SELL de las 18:15 |
| Señales vs v0.02 en TradingView (OANDA:XAUUSD 15m, 24-26 nov) | 11/11 en la misma vela; TP1 a las 11:30 y 15:30 |
| `replica.py --chain pine` | `max&#124;Δ half&#124;` 1.296e-08; `dev` 9.1e-13, `mad_raw` 4.5e-13, `vol` 5.0e-09, `vol_rank` 0; lag 0 |
| `replica.py --chain legacy` (control negativo) | FAIL, `max&#124;Δ half&#124;` 35.02 |

Estas cifras son de ese símbolo, ese broker y ese build. No son una prueba de
ejecución en cuenta ni un forward test.

## Buffers `iCustom`

| Índice | Contenido |
| --- | --- |
| 36 / 37 | Buy Signal / Sell Signal (1 o 0) |
| 27 / 25 | Basis Close / Basis Open |
| 29 / 31 | Upper Band / Lower Band |
| 33 / 34 / 35 | Marca de toque TP1 / TP2 / SL |
| 52 / 53 / 54 / 55 | Entry / SL / TP1 / TP2 del trade vigente |
| 56 | `pos_dir`: 1 long, −1 short, 0 sin trade |
| 43 / 44 / 45 / 46 | `dev` / `mad_raw` / `vol` / `vol_rank` (diagnóstico del CSV) |

## Desviaciones visuales (D1-D6)

MT5 no puede reproducir píxel a píxel el motor de dibujo de TradingView. Las
seis diferencias son de presentación; ninguna toca señales ni niveles.

- **D1 · Sin alfa.** MT5 no dibuja rellenos translúcidos: cada color se
  pre-mezcla con el color de fondo del gráfico y se recalcula si el fondo
  cambia. El Pine usa `color.new(trendCol, 55..100)`.
- **D2 · Orden de las velas recoloreadas.** Con `InpColorCandles` activo hay
  que poner `CHART_FOREGROUND = false`; si no, MT5 dibuja las velas del
  gráfico por encima de los rellenos. El valor original se guarda en `OnInit`
  y se restaura en `OnDeinit`.
- **D3 · Etiquetas de una sola línea.** `OBJ_TEXT` no admite saltos de línea:
  donde el Pine escribe `TP2 (1.5R)\n<precio>`, MT5 muestra
  `TP2 (1.5R) 2318.40`.
- **D4 · Degradado en cuatro capas.** El alfa continuo del Pine (45 % en el
  precio, 0 % en la basis) se aproxima con 4 `DRAW_FILLING` cuyo color toma la
  opacidad del punto medio de su tramo, `Opacidad·(k+0.5)/4` (0.056 / 0.169 /
  0.281 / 0.394 con el 0.45 por defecto): el lado de la basis queda en 0.056,
  no en 0. Cada relleno declara dos índices de color porque `DRAW_FILLING` los
  exige (`0` si buf1>buf2, `1` si buf1<buf2) y se pintan iguales.
- **D5 · Líneas discontinuas de 1 px.** `STYLE_DASH` y `STYLE_DOT` solo se
  dibujan con `width = 1`. La línea de entrada del Pine (`style_dashed`,
  `width 2`) va discontinua de 1 px; con ancho 2 MT5 la pinta sólida.
- **D6 · El tipo de dibujo de un plot es fijo.** Cambiarlo en runtime mueve el
  reparto de buffers de todos los plots siguientes (con `ShowBands = false`
  el plot TP1 leía la banda inferior). Por eso el tipo nunca se cambia: se
  oculta con color `clrNONE` y `OnInit` aborta si el mapa plot→buffer no es
  el esperado (33/34/35 y 36/37, mensaje en el log de Expertos).

## Alcance y límites

- Indicador de solo lectura: no hay ejecución de órdenes, gestión de posición
  ni llamadas de trading.
- La paridad documentada es numérica (CSV) y de estructura visual (D1-D6), no
  una comparación de píxeles.
- La evidencia nativa corresponde a Zeven build 101435 con `XAUUSD.raw` M15.
  Otro broker, otro sufijo de símbolo u otro build exige repetir las tres
  capas antes de dar el port por bueno en ese entorno.
- `max_bars_back = 300` y `max_labels_count = 500` del Pine no tienen
  equivalente; el motor recalcula completo si el terminal recarga historia y
  el port mantiene solo 6 objetos por trade.

(c) Nysys Market Solutions. Solo con fines educativos; no es asesoramiento
financiero.

