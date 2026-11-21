---
name: nysys-strategy-validation
description: 'Valida estrategias y ejecución con pruebas nativas focalizadas de MT5 o NinjaTrader y clasifica evidencia técnica frente a resultados de rentabilidad.'
---

# nysys-strategy-validation

Contenido original de NySys Trading Development.

## Procedimiento

- Congela revisión, plataforma/build, instrumento, periodo, fuente/modelo de ticks, costes, reglas y criterios antes de ejecutar. Selecciona el menor segmento que reproduzca el comportamiento y conserva logs, cuenta de simulación y configuración redactada.
- MT5: compila MetaEditor y usa Strategy Tester con ticks reales donde estén disponibles. Declara cobertura, intervalos generados o sin cotizaciones y diferencia de broker. NinjaTrader: compila en editor, usa Strategy Analyzer para históricos y Playback para secuencia de callbacks y comportamiento simulado.
- Comprueba causalidad, retcodes/rechazos, idempotencia, parciales, stops, límites, reconexión, cancelaciones tardías y kill switch. Conserva unit tests y chequeos de configuración. Etiqueta hallazgos de inspección o modelo como pendientes de reproducción nativa.
- Distingue inspección, modelo determinista, Python histórico, tester/replay nativo y forward simulado autorizado. Python orienta un diagnóstico y no veta la prueba nativa. Una aprobación en tester se refiere al entorno ensayado. Mantén la validación sin operaciones ni cuentas reales.

## Ejemplo

Para reproducir una entrada duplicada, conserva un minuto alrededor de la señal y la reconexión, y verifica en Playback si la segunda solicitud aparece con la misma clave antes de declarar el incidente observado.

## Criterios de aceptación

Cada criterio incluye estado, fuente de evidencia, revisión, prueba y limitación. Una validación incompleta identifica exactamente la reproducción nativa pendiente.

## Referencias

- <https://www.mql5.com/en/docs/runtime/testing>
- <https://ninjatrader.com/support/helpGuides/nt8/playback.htm>
