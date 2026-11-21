# Flujo NinjaTrader 8

1. Registra build, contrato fechado MNQ/NQ/GC/MGC, zona horaria, trading hours, fuente de ticks, comisiones, roll y ajustes. Compila en NinjaScript Editor.
2. En Strategy Analyzer, deja constancia del modelo de fills, resolución y limitaciones con series múltiples. Usa una prueba causal sobre ticks para validar ambigüedad intrabar. Usa Playback/Market Replay para confirmar orden de callbacks y protección sobre ejecuciones simuladas.
3. En una cuenta Playback o simulada comprobada, cubre parciales, rechazos, desconexión y pérdida diaria con flatten de exposición propia. Captura el estado del controlador externo, aislamiento entre cuentas y cierre confirmado. Para condiciones no inducibles registra la prueba determinista y la comprobación pendiente.
4. Reporta métricas, fuentes, costes, logs y diferencias entre simuladores. Mantén desconectadas las cuentas reales.

[Strategy Analyzer](https://ninjatrader.com/support/helpGuides/nt8/strategy_analyzer.htm) · [Playback](https://ninjatrader.com/support/helpGuides/nt8/playback.htm)
