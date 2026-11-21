# NySys Trading Development v1.0

Paquete Windows de nueve skills para diseñar, implementar y revisar robots en MetaTrader 5 y NinjaTrader 8. Incluye siete skills NySys y dos adaptaciones MIT de Kryhr. Los flujos cubren XAUUSD, NDX100/NAS100, MNQ/NQ y oro, con énfasis en scalping de 30 a 120 segundos y validación nativa en simulación.

Desde la raíz del ZIP extraído, comprueba el plan de instalación antes de instalar en un proyecto existente.

```powershell
.\install-nysys-skills.ps1 -Agent Both -ProjectPath 'E:\NySys-Trading-Development' -DryRun
.\install-nysys-skills.ps1 -Agent Both -ProjectPath 'E:\NySys-Trading-Development'
.\verify-installation.ps1 -Agent Both -ProjectPath 'E:\NySys-Trading-Development'
```

Abre una sesión nueva en el proyecto. Selecciona una skill por nombre o describe la tarea. En Claude Code también puedes escribir `/nysys-mql5-development`. Consulta [instalación](docs/INSTALLATION.md), [compatibilidad](docs/COMPATIBILITY.md), [validación del paquete](docs/VALIDATION.md), [seguridad](SECURITY.md) y [procedencia](SOURCES.md).
