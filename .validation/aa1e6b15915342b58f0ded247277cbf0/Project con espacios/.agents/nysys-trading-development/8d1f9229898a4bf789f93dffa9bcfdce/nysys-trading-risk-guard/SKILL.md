---
name: nysys-trading-risk-guard
description: 'Diseña y prueba sizing, límites diarios, propiedad, stops, reconciliación y kill switches para robots de trading en entornos de simulación.'
---

# nysys-trading-risk-guard

Contenido original de NySys Trading Development.

## Procedimiento

- Calcula cantidad desde el presupuesto monetario restante, pérdida estimada al stop en moneda de cuenta, costes y buffer de estrés. Redondea a unidad negociable hacia abajo, verifica margen y reserva capacidad para órdenes pendientes. Un stop no limita por sí solo el riesgo de gaps.
- Define zona horaria y rollover de sesión, PnL realizado/no realizado, comisiones, límite diario, exposición agregada y política de reinicio. Persiste el bloqueo y comprueba que reiniciar no libera el presupuesto diario.
- Aplica la autorización de cuenta simulada, propiedad, frescura, reconciliación, límites y estado del kill switch en el punto de admisión. Usa una clave estable por intención y un libro de fills deduplicado. Vincula cada fill a su tamaño protegido.
- Al disparar el bloqueo, suspende nuevas entradas, cancela pendientes propios y conserva o coordina protección mientras se cierra exposición propia cuando corresponda. Reconcilia la carrera cancelación/fill y registra exposición residual hasta confirmar. Nunca asumas que ordenar flatten terminó el cierre.
- Excluye posiciones ajenas y cuentas reales. Si la cuenta netting o el proveedor impiden aislar propiedad, bloquea mutaciones automáticas.

## Ejemplo

Con presupuesto de 100 y pérdida estresada de 61 por contrato, admite un contrato antes de considerar otros límites. Si ya hay 45 reservados en una orden pendiente, el resultado es cero.

## Criterios de aceptación

Las pruebas deterministas cubren cruce del límite, fill duplicado, fill tardío, rechazo, pérdida de conexión y restart. La reproducción nativa registra bloqueo y protección efectiva sobre el volumen simulado.

## Referencias

- <https://www.mql5.com/en/docs/trading/ordercalcprofit>
- <https://ninjatrader.com/support/helpGuides/nt8/account_class.htm>
