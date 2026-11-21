---
name: nysys-pinescript-development
description: 'Desarrolla, revisa y valida indicadores y estrategias TradingView en Pine Script v6, especialmente ORB con DST, señales confirmadas, alertas y backtesting reproducible.'
---

# nysys-pinescript-development

Contenido original de NySys Trading Development. Skill para TradingView Pine Script v6; complementa `nysys-trading-code-review`, `nysys-strategy-validation` y `nysys-trading-risk-guard`.

## Procedimiento

- **Contrato y alcance.** Antes de editar, identifica archivo, revisión, símbolo, mercado, timeframe, tipo `indicator()` o `strategy()`, feed, zona horaria, configuración y comportamiento vigente. Establece qué señales, niveles, estilo, inputs, alertas y reglas deben permanecer idénticos. Trabaja sobre copia o diff; cambios de lógica requieren autorización explícita.
- **Pine v6.** Usa `//@version=6`, declaraciones y tipos compatibles, `var`/`varip` deliberadamente, condiciones booleanas explícitas y cálculo consistente de las series. Evita saltar cálculos históricos de `ta.*` por evaluación condicional cuando dependen de cada vela. Revisa límites de `max_bars_back`, tiempo de ejecución, solicitudes y objetos gráficos.
- **Relojes y sesiones ORB.** Declara por separado la **zona horaria de la apertura del mercado** y la **zona en la que se muestra/asigna la fecha**. Para Tokio usa `Asia/Tokyo`; Londres `Europe/London`; Nueva York `America/New_York`. En `time(timeframe.period, session, timezone)` utiliza IDs IANA, nunca UTC fijo ni desplazamientos manuales de DST. Calcula la fecha visible de NY con funciones de calendario o `str.format_time(timestamp, ..., "America/New_York")` usando el timestamp real de inicio. No confundas fecha civil de NY, fecha civil de Tokio y `time_tradingday` del instrumento (que representa otra convención). Valida explícitamente eventos que cruzan medianoche.
- **Definición de sesión.** No supongas equivalencia entre apertura de Tokio, apertura del mercado de futuros, reapertura de Globex o sesión de FX: documenta instrumento y convención elegida. Usa apertura local de Tokio a las 09:00, Londres a las 08:00 y NY a las 09:30 **solo si ese es el contrato aprobado**. Si el proyecto usa Asia 20:00 NY por diseño, registra el cambio de definición antes de sustituirla. Las sesiones deben especificar días elegibles si afecta días festivos o fines de semana; comprueba disponibilidad real de velas.
- **Construcción ORB.** La caja empieza en el primer bar elegible y acumula high/low exclusivamente durante los 15 minutos iniciales. En timeframes que no dividen 15 minutos o donde falten velas, define una política verificable (p. ej. restringir TF, usar intrabarras o marcar rango incompleto); no afirmes precisión de 15 minutos si el feed no la da. Las rupturas y flechas se confirman con la vela cerrada según reglas documentadas. Al cambiar de sesión, preserva o libera cajas anteriores según el contrato y controla `max_boxes_count`.
- **No repainting y causalidad.** Distingue valores intrabar, vela confirmada y datos futuros. Para decisiones al cierre usa `barstate.isconfirmed` en el contexto del gráfico; **no lo uses como garantía dentro de `request.security()`**. Para HTF, utiliza técnicas documentadas de datos confirmados y offset; prohíbe `lookahead_on` sin offset de datos confirmados. Comprueba que las señales históricas y las de tiempo real coincidan tras recargar, y que ninguna señal se anticipe a información no disponible.
- **Señales, objetos y rendimiento.** Separa cálculo de señales, estado de operación simulada, dibujo y alertas. Reutiliza `box`, `line` y `label` con actualizaciones `set_*` cuando corresponda; evita crear objetos indefinidamente y conserva la identidad visual aprobada. Verifica bucles, arrays y `request.security_lower_tf()` contra límites de TradingView; usa el mínimo necesario.
- **Alertas/webhooks.** Define explícitamente cuándo se dispara `alert()` o `alertcondition()`, cierre de vela, payload JSON, identificador idempotente, timestamp de evento en UTC y representación NY, símbolo/timeframe, versión y lado. Evita secretos en Pine o payload y no prometas que un webhook significa una ejecución completada. Los robots conectados aplicarán por separado admisión de riesgo y reconciliación.
- **Backtest y riesgo.** Si corresponde una `strategy()`, declara configuración de órdenes, comisiones, slippage, sesión, fill assumptions y diferencias entre OHLC e intrabar. Registra datos, ventana IS/OOS, parámetros, costes y resultados. No interpretes Strategy Tester como prueba de fills reales. Conserva kill switch y bloqueos en el sistema ejecutor externo; no habilites trading real desde un indicador.
- **Validación dirigida.** Prueba en M1/M5/M15 y símbolos relevantes con feed activo; reproduce al menos una apertura normal, cruces de fecha NY/Tokio, cambios DST de EE. UU. y Europa (incluidas semanas de desfase), ausencia de velas, primer bar de sesión, reapertura, recarga del gráfico, duplicación de etiqueta/alerta y agotamiento de objetos. Compara timestamp UTC, hora local de la sesión y fecha de NY en una tabla de casos esperados. Un cálculo independiente de zonas horarias es evidencia determinista, no compilación.
- **Entrega.** Informa archivo/revisión, diff mínimo, invariantes preservados, pruebas y evidencia por entorno: inspección estática, prueba de fechas independiente, compilación en Pine Editor, comparación gráfica histórica, alertas en simulación. Marca explícitamente lo no ejecutado o no observado. No afirmes compilación o paridad sin probarla en TradingView.

## Ejemplo

Para un ORB de Tokio definido como **09:00 Asia/Tokyo**, una apertura del 2 de noviembre de 2026 corresponde al **1 de noviembre, 19:00 America/New_York**, porque NY está en EST y Tokio no aplica DST. La etiqueta puede mostrar la fecha civil de NY `2026-11-01` y la fecha de sesión local de Tokio `2026-11-02`, sin confundirlas. El rango sigue siendo de 15 minutos. Si la intención fuera «Asia 20:00 NY» fija, eso sería **otra sesión** y no se debe modificar silenciosamente.

## Criterios de aceptación

- Pine Editor v6 compila sin errores; si no hay acceso a TradingView, queda **pendiente**, no aprobado.
- ORB forma exactamente el rango contratado, con zona IANA del mercado y fecha civil NY correcta; se adjunta una tabla de al menos seis casos que cubra EST/EDT, GMT/BST y cruce de medianoche.
- No hay cambios no autorizados en señales, niveles, entradas, colores o alertas. Una comparación de velas antes/después identifica cualquier diferencia intencionada.
- No hay `lookahead` de datos futuros ni señales basadas en velas no confirmadas donde el contrato exige cierre.
- Se reportan diferencias entre backtest, Replay y comportamiento en tiempo real, así como limitaciones del proveedor de datos.
- Se entregan diff, revisión y evidencia; las pruebas pendientes se enumeran sin afirmar validación total.

## Referencias

- <https://www.tradingview.com/pine-script-docs/concepts/time/>
- <https://www.tradingview.com/pine-script-docs/concepts/sessions/>
- <https://www.tradingview.com/pine-script-docs/concepts/bar-states/>
- <https://www.tradingview.com/pine-script-docs/concepts/repainting/>
- <https://www.tradingview.com/pine-script-docs/faq/other-data-and-timeframes/>
- <https://www.tradingview.com/pine-script-reference/v6/>
