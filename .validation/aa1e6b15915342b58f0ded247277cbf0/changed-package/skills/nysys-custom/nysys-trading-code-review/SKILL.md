---
name: nysys-trading-code-review
description: 'Revisa y depura cambios de trading en MQL5 o NinjaScript cuando afecten órdenes, señales, seguridad operativa, estado o reproducibilidad.'
---

# nysys-trading-code-review

Contenido original de NySys Trading Development.

## Procedimiento

- Sigue el camino desde señal hasta llamada nativa y de callback hasta reconciliación. Revisa relojes, código de retorno, normalización, protección de parciales, propiedad de cuentas y estados ante reinicio o desconexión.
- Ordena hallazgos por impacto y probabilidad. Adjunta archivo/línea, condición de disparo, efecto observable y cambio comprobable. Distingue inspección de reproducción. Usa una regresión focalizada cuando exista un defecto verificable.
- Prueba invariantes con modelos deterministas y reproduce comportamiento específico en el tester/replay nativo cuando sea viable. Haz revisión del camino típico y al menos un fallo relevante. Comprueba auditoría, secretos, mecanismos de envío y fallos cerrados.
- Trabaja sobre copia o diff autorizado. No alteres estrategias existentes sin respaldo y aprobación ni conectes cuentas reales. Evalúa entornos simulados y evita afirmar que compilación equivale a validación de ejecución.

## Ejemplo

Si `CTrade.Buy` devuelve true y el EA cambia a estado filled, señala el punto exacto y prepara una prueba con retcode de rechazo. Espera que el estado permanezca sin posición y que se registre la causa.

## Criterios de aceptación

Cada hallazgo indica evidencia, impacto y reparación. La conclusión lista qué compiló, qué se reprodujo nativamente y qué queda pendiente.

## Referencias

- <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade>
- <https://ninjatrader.com/support/helpGuides/nt8/onexecutionupdate.htm>
