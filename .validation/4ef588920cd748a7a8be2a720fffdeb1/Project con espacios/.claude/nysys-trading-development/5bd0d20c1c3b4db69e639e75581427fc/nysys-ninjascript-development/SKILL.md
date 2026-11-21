---
name: nysys-ninjascript-development
description: 'Desarrolla y revisa Strategies y AddOns de NinjaTrader 8 en C# para MNQ, NQ y futuros de oro, con énfasis en ciclo de vida, ejecuciones y simulación.'
---

# nysys-ninjascript-development

Contenido original de NySys Trading Development.

## Procedimiento

- Usa `OnStateChange` para defaults, configuración, inicialización de dependencias y liberación de suscripciones. En series múltiples declara la serie que decide y la que ejecuta, comprueba `BarsInProgress` y `CurrentBars`, y explica la transición histórica a tiempo real.
- Usa `OnOrderUpdate` para estados, identificadores y rechazos y `OnExecutionUpdate` para contabilizar cada ejecución una sola vez y proteger los parciales por cantidad confirmada. Elimina referencias obsoletas al pasar a tiempo real. Evita mezclar órdenes managed y unmanaged.
- En AddOns, suscribe y libera eventos de cuenta sim por cuenta. Usa propiedad explícita por estrategia, cuenta, instrumento y revisión. Con varios instrumentos o cuentas, coordina reservas de riesgo en el controlador externo y bloquea entradas ante un estado externo obsoleto.
- Maneja fallos y desconexiones como estado bloqueado. Reconcilia órdenes, posiciones y ejecuciones antes de rearmar. Evalúa `RealtimeErrorHandling` y la política de pérdida de conexión. Coordina protección, cancelación y flatten por propiedad y confirma el resultado.
- Usa contratos explícitos y captura roll, tick size, tick value, horario de sesión y comisiones. Mantén las rutas de prueba limitadas a Strategy Analyzer, Playback o cuenta simulada verificada.

## Ejemplo

En Playback, una solicitud por dos MNQ produce dos ejecuciones individuales. Inyecta un rechazo de protección en un escenario controlado. La cantidad conciliada permanece exacta y el controlador bloquea nuevas entradas mientras resuelve la exposición.

## Criterios de aceptación

Compila en NinjaScript Editor. Entrega registro de orden/ejecución con dos parciales, reconexión, bloqueo de pérdida diaria y cierre simulado por propiedad. Distingue resultados de Analyzer y Playback.

## Referencias

- <https://ninjatrader.com/support/helpGuides/nt8/onexecutionupdate.htm>
- <https://ninjatrader.com/support/helpGuides/nt8/onorderupdate.htm>
