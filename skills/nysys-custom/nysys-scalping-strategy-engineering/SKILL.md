---
name: nysys-scalping-strategy-engineering
description: 'Diseña hipótesis de scalping de 30 a 120 segundos para XAUUSD, NAS100, MNQ, NQ y oro cuando se necesite microestructura, order flow o modelado causal de ejecución.'
---

# nysys-scalping-strategy-engineering

Contenido original de NySys Trading Development.

## Procedimiento

- Declara hipótesis, mecanismo esperado, ventanas por sesión, señales, filtros de spread y condición de invalidación. Separa contexto M1/M5/M15 del reloj de 30–120 s contado desde el primer fill. Define la expiración de una entrada sin fill.
- Etiqueta timestamp de evento y de disponibilidad. Construye imbalance y agresión solo con datos de calidad suficiente. En CFD, documenta que el book y volumen del broker pueden ser parciales. Para futuros, distingue MBP de MBO, colas estimadas, cancelaciones y prioridad.
- Simula agresión al bid/ask apropiado después de latencia. Una orden pasiva al touch necesita modelo explícito de prioridad y qty consumida. Mide coste efectivo, fill ratio, adverse selection, MAE/MFE y duración real. Evita cobrar spread dos veces.
- Congela reglas antes de OOS. Repite un segmento dirigido nativamente con quote bursts, gaps y spread extremo. Mantén límites por sesión, cooldown y kill switch. Excluye cuentas reales del flujo.

## Ejemplo

Si la señal usa el cierre M1 a las 09:31 y un modelo añade 150 ms, busca la primera cotización elegible a partir de 09:31:00.150. Con OHLC sin cotizaciones, marca el fill como ambiguo y confirma en datos de ticks.

## Criterios de aceptación

Entrega un contrato de datos, una traza con tiempo de señal/solicitud/fill/salida, una comparación conservadora de costes y un caso reproducido en Tester o Playback, o su estado pendiente.

## Referencias

- <https://www.mql5.com/en/docs/runtime/testing>
- <https://ninjatrader.com/support/helpGuides/nt8/playback.htm>
