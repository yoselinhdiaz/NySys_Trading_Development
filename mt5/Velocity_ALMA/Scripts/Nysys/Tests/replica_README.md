# replica.py — paridad numérica de Velocity_ALMA.mq5

`replica.py` es la réplica literal de la cadena del Pine v0.02 (el indicador de
referencia, `docs/Velocity_ALMA_v0.02.pine`). Recalcula desde OHLC y compara
serie a serie contra el CSV de paridad; no lee buffers del terminal. Vive aquí,
junto al exporter (`Velocity_ALMA_ParityExport.mq5`), y es la única copia.
Solo usa la biblioteca estándar (`argparse`, `math`, `sys`): Python 3.8+.

```
cd MQL5\Scripts\Nysys\Tests
python replica.py <csv> [--rows 300] [--chain pine|legacy]
                        [--at "2026.11.26 07:00"] [--print-series]
```

CSV de entrada: `MQL5\Files\velocity_alma_live_<sym>_<tf>.csv` (lo escribe el
indicador al cerrar cada vela con `InpDumpCsv=true`) o el `full` del script
`Velocity_ALMA_ParityExport`.

## Cadena (Pine v0.02, líneas 68-90; volatilidad en 73-74)

```
basisClose = ta.ema(ta.alma(close, 34, 0.65, 20), 4)     // 69-70
dev        = |close - ta.sma(close, 5)|                  // 73 (SMA interior)
madRaw     = ta.sma(dev, 5)                              // 73 (SMA EXTERIOR)
vol        = ta.ema(madRaw, 5)                           // 74
volRank    = #{k=1..100 : vol[i-k] <= vol[i]} / 100      // 77-84
adaptFactor= 0.8 + (1.8 - 0.8) * volRank                 // 87
bandHalf   = 1.4826 * vol * adaptFactor                  // 88
upperBand  = basisClose + bandHalf                       // 89
lowerBand  = basisClose - bandHalf                       // 90
```

Las dos SMA van encadenadas: `dev` (SMA interior) y `madRaw` (SMA exterior).
Quitar la exterior es el defecto que corrigió el port el 26/11/2026.

## Estado de la paridad (26/11/2026, XAUUSD.raw M15, últimas 300 velas)

| medición | max&#124;Δ half&#124; | factor implícito | lag óptimo |
| --- | --- | --- | --- |
| CSV del port **con** el defecto vs `--chain pine` | 35.019 | 0.443 .. 4.217 | +2 velas |
| CSV del port **corregido** vs `--chain pine` | **1.296e-08** | 0.800 .. 1.800 | 0 |
| control negativo: CSV corregido vs `--chain legacy` | 35.02 | 0.413 .. 3.252 | — |

Por serie en el CSV corregido: `dev` 9.1e-13, `mad_raw` 4.5e-13, `vol` 5.0e-09,
`vol_rank` 0, `half` 1.296e-08. Gate: `max|Δ half| < 1e-6`.

`--chain legacy` reproduce a propósito el comportamiento anterior (`vol =
EMA(dev)`, `mad = vol * 1.4826`): sirve de control negativo, demuestra que el
resto de la cadena (ALMA, semilla EMA, rank, índices) ya era correcto y que la
única causa era la SMA que faltaba.

Señales: 11/11 en la misma vela que la v0.02 en TradingView (OANDA:XAUUSD 15m,
24-26 nov), con TP1 a las 11:30 y 15:30. Camino incremental del indicador:
0 diferencias frente al recálculo completo en 3 velas vivas, incluida la SELL
de las 18:15 (hora del servidor).

## Columnas de diagnóstico

Las 4 últimas columnas del CSV (`dev`, `mad_raw`, `vol`, `vol_rank`) van AL
FINAL para no mover ni cambiar ninguna de las 19 históricas. Los precios se
escriben con 6 decimales (`VALMA_CSV_DECIMALS`) y las 4 series de diagnóstico
con 8 (`VALMA_CSV_DIAG_DECIMALS`); `half` se compara con `max|Δ| < 1e-6` a
partir de `vol` y `vol_rank`. A 6 decimales el redondeo de `vol` (5e-7) se
propaga a `half` × 1.4826 × 1.8 = 1.3e-6 y el gate daría un falso FAIL.
