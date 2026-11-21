# Instalación en Windows 10 y 11

Usa Windows PowerShell 5.1 o PowerShell 7. Extrae todo el ZIP a un directorio de confianza. Desde esa carpeta ejecuta los comandos. El directorio de proyecto debe existir. Los scripts resuelven archivos del paquete desde su propia ubicación.

```powershell
.\install-nysys-skills.ps1 -Agent Both -Scope Project -ProjectPath 'E:\NySys-Trading-Development' -DryRun
.\install-nysys-skills.ps1 -Agent Both -Scope Project -ProjectPath 'E:\NySys-Trading-Development'
.\verify-installation.ps1 -Agent Both -Scope Project -ProjectPath 'E:\NySys-Trading-Development'
.\uninstall-nysys-skills.ps1 -Agent Both -Scope Project -ProjectPath 'E:\NySys-Trading-Development' -DryRun
.\uninstall-nysys-skills.ps1 -Agent Both -Scope Project -ProjectPath 'E:\NySys-Trading-Development'
```

Usa `-Agent Codex` o `-Agent Claude` para un solo agente. En una sesión PowerShell selecciona componentes con `-Name nysys-mql5-development,nysys-trading-risk-guard`. Aplica la misma selección al verificar o retirar. Para instalación global usa `-Scope User` y omite `-ProjectPath`.

No se requieren privilegios de administrador si el usuario controla el destino. Respeta la política de ejecución vigente. DryRun lee y valida el paquete y destino sin escribir. Verify comprueba integridad y propiedad sin invocar los binarios. El registro de cambios se guarda en el directorio hermano `nysys-trading-development/<id>/operation.log`. Los errores previos a cambios se muestran en consola. Cada desinstalación conserva una copia íntegra en ese mismo directorio de operación. Para restaurar, usa la misma versión del instalador o mueve un respaldo intacto a su ruta anterior desocupada.

Reabre el proyecto en el agente y confirma la aparición de las skills. La detección por PATH es informativa. Usa la invocación descrita en [compatibilidad](COMPATIBILITY.md).
