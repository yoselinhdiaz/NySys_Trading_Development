# Seguridad

El ZIP contiene instrucciones Markdown y administración local de archivos. No incluye robots, binarios, credenciales, brokers, servidores MCP ni hooks. La instalación no invoca agentes, código de terceros ni red. El proyecto y el usuario eligen los destinos mediante parámetros explícitos.

El manifiesto fija los SHA-256 de las skills. Las validaciones rechazan archivos extra, metadatos inesperados, rutas que atraviesan enlaces o junctions existentes y contenido distinto al registrado. El manifiesto acompaña el ZIP y sirve para detectar cambios accidentales. Para verificar procedencia del archivo completo, contrasta su SHA-256 por un canal independiente. El paquete carece de firma digital.

Una colisión con un destino existente se rechaza salvo que la instalación coincida exactamente. Una retirada mueve el directorio intacto a un respaldo fuera de la ruta de descubrimiento. La instalación de un directorio se publica mediante un movimiento local que falla si el nombre ya existe. Una ejecución con varias skills puede completarse parcialmente por un fallo de E/S. Repite el comando tras reparar la causa y usa el registro para identificar los movimientos completados. Ejecuta la gestión en directorios de confianza y evita operaciones paralelas sobre los mismos destinos.

Las skills limitan la ejecución de estrategias a ambientes simulados. Los controles de cuenta y riesgo descritos deben implementarse en el robot y verificarse en plataforma. El Markdown guía al agente. Las restricciones de ejecución dependen de los permisos y del sandbox que aplique el agente.
