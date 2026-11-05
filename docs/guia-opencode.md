# Guía OpenCode — Cómo trabajar con la IA en este repo

OpenCode es el asistente de IA con el que el equipo trabaja. Esta guía expone
el uso diario **en este repositorio**.

---

## Instalación

- **WSL / Linux:**
  ```bash
  curl -fsSL https://opencode.ai/v2/install | bash
  ```
- **macOS (Homebrew):** `brew install anomalyco/tap/opencode-v2`
- Verificar: `opencode --version`

## Arranque: SIEMPRE desde la raíz del repo

```bash
cd ~/Arquitectura_de_Computadoras    # (dentro de WSL)
opencode
```

Abrir en la raíz es lo que hace que OpenCode cargue automáticamente los
`AGENTS.md` del proyecto (`AGENTS.md`, `reportes/AGENTS.md`, `vhdl/AGENTS.md`)
y `opencode.json`, que añade `docs/guia-git.md`, `docs/guia-opencode.md` y
`docs/guia-wsl.md` como instrucciones. Así la IA conoce las reglas del equipo
sin que tengas que explicarle nada.

> Si abres OpenCode desde otra carpeta, **no** cargará estos contextos y la IA
> no sabrá que debe derivar a `scripts/`.

## Qué le puedes preguntar (y cómo debe responder)

La IA está instruida para basarse en **esta documentación y los scripts del
repo**, no en comandos inventados:

| Pregunta | La IA te llevará a |
|---|---|
| ¿Cómo compilo el reporte? | `scripts/latexbuild main.tex` |
| ¿Cómo simulo este módulo? | `scripts/vhdl-sim <unidad> <tb>` |
| ¿Cómo veo las ondas? | `scripts/vhdl-wave <archivo.vcd>` |
| Me faltan herramientas / no compila | `bash scripts/instalar.sh` |
| ¿Cómo hago un PR o un commit? | `docs/guia-git.md` |
| Estoy en Windows/WSL | `docs/guia-wsl.md` |

Si algo falla porque falta una herramienta, la IA debe recomendarte
`scripts/instalar.sh` **en lugar de instalar por su cuenta**.

## Modo plan

Antes de que toque código grande (un módulo VHDL, una sección del reporte),
pide primero un plan:

```
Planifica cómo añadir el testbench del acumulador en datapath-2
```

OpenCode trabaja en **modo plan** hasta que tú le digas que ejecute. Sirve para
revisar el enfoque antes de que modifique ficheros. Cuando estés de acuerdo,
indica que continúe (cambia a modo de ejecución).

## Buenas prácticas del equipo

1. **Pide plan antes que código.** Sobre todo en VHDL y secciones del reporte.
2. **Exige las reglas del repo**: las referencias deben indicar **exactamente
   dónde aparece el texto sugerido**; la plantilla del reporte está en
   `reportes/AGENTS.md`; la convención VHDL en `vhdl/AGENTS.md`.
3. **Verifica con los scripts**: tras un cambio, ejecuta
   `scripts/vhdl-sim ...` o `scripts/latexbuild ...` y pide a la IA que arregle
   lo que falle. No des por bueno un módulo que no pasa su testbench.
4. **No le dejes subir artefactos**: revísale el `git status` antes del commit.
5. **Git delegado a la guía**: para ramas y PRs, la IA sigue `docs/guia-git.md`.
   Recuérdale que **abra una rama por cada feature** (`vhdl/<unidad>/<feat>`,
   `reporte/<unidad>/<feat>`, `docs/<feat>`…) aunque no se lo pidas; es una
   regla del repo, no una decisión de la IA.

## Comandos útiles del TUI

| Acción | Cómo |
|---|---|
| Nueva sesión | `Ctrl+T` (o el comando de nueva sesión) |
| Cambiar de modelo | menú de modelo en la parte inferior / `Ctrl+P` |
| Ejecutar sin abrir TUI | `opencode run "¿qué hace scripts/latexbuild?"` |
| Ayuda de atajos | `?` dentro del TUI |
| Salir | `Ctrl+C` o el comando de salida |

## Configuración del proyecto (`opencode.json`)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "docs/guia-git.md",
    "docs/guia-opencode.md",
    "docs/guia-wsl.md"
  ]
}
```

Si necesitas añadir otra guía como instrucción, edítala ahí (la IA también
puede hacerlo si se lo pides).

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| La IA no sabe nada del proyecto | Abriste OpenCode fuera de la raíz → `cd` al repo y relanza |
| La IA propone comandos sueltos de `ghdl`/`latexmk` | Recuérdale: "usa los scripts del repo (AGENTS.md)" |
| No arranca en WSL | Reinstala: `curl -fsSL https://opencode.ai/v2/install \| bash` |
| No encuentra el modelo / sin API key | `/connect` dentro del TUI para conectar tu proveedor |
| Sesionando en WSL no ve los ficheros | Comprueba que el clon está en `~` y no en `/mnt/c` (ver `docs/guia-wsl.md`) |
