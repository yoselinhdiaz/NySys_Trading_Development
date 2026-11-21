# Flujo MT5

1. Registra build de MetaEditor/terminal, broker y símbolo exacto de XAUUSD o índice NAS100/NDX100. Captura modo netting/hedging, tick size, contract size, volumen, spread y restricciones de stops.
2. Compila el EA o indicador. Para un EA usa Strategy Tester, preferiblemente «Cada tick basado en ticks reales» si hay cobertura. Documenta spread, comisiones, desfase de timestamps y lapsos generados. Mantén las señales M1/M5/M15 separadas del temporizador de 30 a 120 segundos.
3. Reproduce una ventana pequeña. Exporta logs y lista de órdenes/deals para confirmar retcodes, fills, deduplicación, protección, límites y reconciliación. Usa un escenario determinista adicional para los fallos que el tester no puede inducir.
4. Etiqueta los resultados como tester nativo o modelo. Usa cualquier diagnóstico histórico de Python como apoyo focalizado. No actives trading real.

[MQL5 Strategy Testing](https://www.mql5.com/en/docs/runtime/testing)
