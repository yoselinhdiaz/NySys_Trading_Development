# Validación de la edición 1.0

18 de noviembre de 2026 · Windows NT 10.0.26300.0.

Se ejecutó `tests/Test-Package.ps1` en Windows PowerShell 5.1.26100.9818 y PowerShell 7.6.9. Los 11 escenarios aprobaron en cada runtime.

| Caso | Resultado en ambos runtimes |
| --- | --- |
| 1. Sintaxis PowerShell e inventario | Aprobado |
| 2. DryRun completo de instalación sin escrituras | Aprobado |
| 3. Selección de agente y de dos componentes | Aprobado |
| 4. Instalación en ambas rutas, igualdad de hashes e idempotencia | Aprobado |
| 5. DryRun de retirada sin escrituras | Aprobado |
| 6. Edición local detectada y preservada | Aprobado |
| 7. Retirada, 18 respaldos intactos y segunda retirada sin cambios | Aprobado |
| 8. Colisión con directorio ajeno y nombre desconocido | Aprobado |
| 9. Colisión de nombre en un ancestro | Aprobado |
| 10. Corrupción de un archivo del paquete | Aprobado |
| 11. Nombre duplicado en el manifiesto | Aprobado |

También se ejecutó un DryRun global para un componente y ambos adaptadores en el perfil aislado del sandbox. El formato portátil de las nueve skills se validó con los scripts del paquete. Consulta SOURCES.md para procedencia y licencias.

Para repetir la prueba, elige un directorio existente bajo el proyecto donde puedas escribir fixtures. El script conserva los fixtures en un directorio único.

```powershell
.\tests\Test-Package.ps1 -FixtureParent 'E:\NySys-Trading-Development\.validation'
```

La evidencia de compatibilidad es estructural. Codex se detectó en PATH y Claude Code no. El descubrimiento e invocación interactivos en ambos agentes y la instalación global efectiva quedaron pendientes. El paquete no contiene un robot ni cuenta de prueba. No se ejecutaron MetaEditor, Strategy Tester, Strategy Analyzer, Playback ni pruebas de rentabilidad. La prueba no requiere credenciales ni red.
