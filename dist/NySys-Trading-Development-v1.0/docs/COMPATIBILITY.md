# Compatibilidad

| Agente | Proyecto | Usuario | Descubrimiento y conflictos |
| --- | --- | --- | --- |
| Codex | `.agents/skills/<nombre>/SKILL.md` | `~/.agents/skills/<nombre>/SKILL.md` | Una sesión selecciona por descripción o invocación explícita. Pueden aparecer entradas del mismo nombre desde distintas fuentes. |
| Claude Code | `.claude/skills/<nombre>/SKILL.md` | `~/.claude/skills/<nombre>/SKILL.md` | Invoca `/<nombre>` o activa por descripción. Para nombres iguales, ámbito enterprise precede al personal y este al proyecto. Los plugins se nombran con su prefijo. |

Los dos adaptadores comparten la fuente y los SHA-256. El frontmatter se restringe a nombre y descripción. El instalador rechaza colisiones en destino y, al instalar a proyecto, nombres detectados en rutas estándar del perfil y ancestros. Las instalaciones globales no inspeccionan todos los proyectos del usuario. La verificación estructural no cubre plugins, configuraciones administradas ni raíces no estándar del agente. Usa una sesión nueva para confirmar el nombre detectado.

- [OpenAI, rutas para instalación manual](https://developers.openai.com/api/reference/cli)
- [OpenAI, creación e invocación de skills](https://developers.openai.com/codex/skills)
- [Anthropic, ubicación, precedencia y frontmatter](https://code.claude.com/docs/en/skills)
