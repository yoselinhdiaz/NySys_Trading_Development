---
name: nysys-quant-backtesting
description: 'Planifica backtests cuantitativos reproducibles, walk-forward, controles de sobreajuste y escenarios de costes para robots MT5 o NinjaTrader.'
---

# nysys-quant-backtesting

Contenido original de NySys Trading Development.

## Procedimiento

- Registra proveedor, símbolo/contrato, zona horaria, resolución, huecos, licencia, versión de datos y revisión. Define protocolo, hipótesis, métricas y presupuesto de variantes antes de ejecutar.
- Usa IS/OOS cronológico. Ajusta transformaciones dentro de cada IS, purga eventos que cruzan fronteras y aplica embargo si hay dependencia. En walk-forward congela parámetros antes de cada tramo y conserva un OOS final separado cuando el diseño lo permita.
- Modela spreads variables, slippage condicionado a volatilidad/liquidez, comisiones por lado y latencia. Prueba sensibilidad y plausibilidad de parciales. Calcula drawdown sobre equity, profit factor, expectancy neta, win rate, riesgo por operación, trades y resultados por régimen. Documenta denominador cero y muestra pequeña.
- Ajusta por múltiples hipótesis y controla inestabilidad próxima al óptimo. Si procede, usa bootstrap por bloques con semilla y comparación IID para contextualizar drawdown. El historial sintético sirve para probar el modelo.
- Python con Dukascopy o Databento sirve para diagnósticos focalizados. La evaluación primaria usa Strategy Tester de MT5 o Strategy Analyzer y Playback en NinjaTrader. Limita variantes y runs por defecto. Mantén el flujo sin cuentas reales.

## Ejemplo

En una ventana OOS, duplica el deslizamiento estimado y vuelve a calcular expectancy neta y drawdown con idénticos parámetros congelados. Reporta si la conclusión es sensible y cuál es la base de costes.

## Criterios de aceptación

Entrega definición de ventanas, semilla y hashes cuando procedan, tabla de costes, métricas por régimen y registro de intentos. Identifica fuente de evidencia y qué supuestos no se verificaron.

## Referencias

- <https://www.mql5.com/en/docs/runtime/testing>
- <https://ninjatrader.com/support/helpGuides/nt8/strategy_analyzer.htm>
