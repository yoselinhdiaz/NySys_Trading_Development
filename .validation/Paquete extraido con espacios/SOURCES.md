# Procedencia y selección

Revisión del 18 de noviembre de 2026. Los cinco orígenes se descargaron como clones superficiales sin checkout a `sources/repositories` en el proyecto de desarrollo. Cada clon preserva el remoto y los objetos Git del commit indicado. Se inspeccionaron los README, el inventario de SKILL.md, los textos de licencia disponibles y las dependencias de candidatos. La selección se basó en utilidad para MT5/NT8, redundancia, portabilidad, licencia y efectos externos. Los clones quedan fuera del ZIP.

| Fuente | Commit | Licencia observada | Decisión |
| --- | --- | --- | --- |
| [AGIPro](https://github.com/agiprolabs/claude-trading-skills) | `981e1d736cdc02bdc1c55c74ec9224e956414706` | MIT, `LICENSE.md` | Excluida. Microestructura tradicional aplicada a cripto y walk-forward incluyen scripts y dependencias científicas. Los flujos NySys cubren los métodos pertinentes en el mercado y la plataforma objetivo. |
| [Kryhr](https://github.com/Kryhr/26-quant-trading-skills) | `80c2f860f322207526ce7f31901234313253f263` | MIT, `LICENSE` | Incluidas las skills de fills imposibles y Monte Carlo. Sin scripts ni dependencias locales. Robustez y costes se cubren en NySys y en referencias upstream fijadas. |
| [HyperFrequency](https://github.com/HyperFrequency/skills) | `7532af704e2ab1cb69953bc20419bbca19878ea3` | Sin licencia de redistribución identificada en el árbol | Excluida. Order flow apunta a rutas locales y herramientas externas. Nautilus documenta dependencias Python y ejecución mainnet, fuera del alcance. |
| [Alpaca](https://github.com/alpacahq/alpaca-skills) | `0e7c35163ae462730de1f4a0bfafceac82b7d59b` | Apache-2.0, `LICENSE` | Excluida. El backtest requiere Alpaca CLI y acceso autenticado. Paper y Broker API duplican simulación o exponen operaciones fuera de los mercados objetivo. El [anuncio oficial](https://alpaca.markets/blog/alpaca-launches-skills-library-for-ai-agents/) enlaza el repositorio. |
| [CPZAI](https://github.com/CPZ-Lab/cpzai-plugin) | `371512edd2b98a980905f6288098578dd8846c32` | Apache-2.0 en `cpzai/LICENSE` | Excluida. La skill de backtesting contempla un flujo MCP que ejecuta y modifica estrategias. El plugin incluye configuración MCP y hooks. NySys cubre metodología y validación local. |

## Contenido distribuido

Los dos derivados conservan el cuerpo metodológico de Kryhr. NySys ajustó las descripciones, sustituyó referencias relativas por enlaces al commit y agregó alcance y salvedades sobre tester nativo, volumen CFD y prioridad. Cada directorio distribuido conserva el aviso MIT. El manifiesto identifica el archivo y hash de cada skill. Los siete directorios `nysys-*` contienen instrucciones originales.

| Capacidad | Skill principal |
| --- | --- |
| Hipótesis, scalping, microestructura, order flow y modelado causal | NySys Scalping |
| Walk-forward, costes, overfitting, estadística y regímenes | NySys Quant Backtesting |
| Remuestreo y colas de drawdown | Kryhr Monte Carlo |
| Auditoría de fills y modelado de ejecución | Kryhr Fill Feasibility |
| Position sizing, límites y reconciliación | NySys Risk Guard |
| MQL5, NinjaScript, testing, code review y debugging | NySys MQL5, NinjaScript, Strategy Validation y Trading Code Review |
