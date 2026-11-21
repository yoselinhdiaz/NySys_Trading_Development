---
name: nysys-mql5-development
description: 'Desarrolla y revisa Expert Advisors e indicadores MQL5 nativos para MT5 cuando la tarea afecte señales, órdenes, posiciones o portabilidad entre brokers.'
---

# nysys-mql5-development

Contenido original de NySys Trading Development.

## Procedimiento

- En `OnInit`, resuelve el símbolo configurado y comprueba selección, modo de cuenta, permisos del entorno de prueba, tamaño de tick, volumen mínimo/máximo/paso, nivel de stops y freeze level. Usa el símbolo real del broker para XAUUSD y NDX100/NAS100. Ajusta precios a tick size y redondea volumen hacia abajo. Si queda debajo del mínimo, omite la entrada.
- Separa señal de M1/M5/M15, admisión de riesgo y ejecución. Usa datos disponibles al instante de decisión y relojes de ticks/eventos para la salida temporal. Evita E/S y esperas bloqueantes en `OnTick`.
- Configura `CTrade` con magic y política de llenado del símbolo. Comprueba `ResultRetcode()` según la operación y estado. Un booleano exitoso solo indica que se aceptó la estructura de la solicitud. Registra order/deal IDs y confirma volumen y protección con `OnTradeTransaction` y consultas al terminal.
- En hedging reconcilia tickets y magic. En netting la posición por símbolo puede agregar actividad ajena. Exige propiedad exclusiva comprobable o bloquea las mutaciones. Mantén una clave única por señal y reconstruye el estado antes de volver a admitir órdenes tras reiniciar o perder conexión.
- Diseña para Strategy Tester y simulación. Bloquea cuentas reales y estados desconocidos antes de cualquier operación. Conserva protección, reconciliación, límites y kill switch en el arnés. Mantén el runtime MQL5 nativo.

## Ejemplo

En una prueba de XAUUSD, simula un rechazo por stops y una segunda notificación del mismo deal. Comprueba que el rechazo no crea estado de posición y que el deal duplicado no incrementa volumen ni provoca un reenvío.

## Criterios de aceptación

MetaEditor compila sin errores. La prueba nativa registra build, símbolo, modelo de ticks, revisión y retcodes. Demuestra rechazo, protección sobre volumen confirmado, deduplicación y bloqueo tras reconexión hasta reconciliar.

## Referencias

- <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade>
- <https://www.mql5.com/en/docs/event_handlers/ontradetransaction>
