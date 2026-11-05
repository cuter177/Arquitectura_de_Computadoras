# AGENTS.md — Instrucciones del proyecto

Repositorio de **Arquitectura de Computadoras**: 4 reportes en formato Springer
(LaTeX/llncs) + código VHDL simulado con GHDL. Equipo de 5 integrantes.

## Regla de oro: deriva SIEMPRE a los scripts y documentos del repo

Cuando alguien pregunte **cómo compilar, simular, ver ondas, instalar o
trabajar** con este proyecto, responde **basándote en esta documentación y en
los scripts existentes**. No recomiendes comandos `latexmk`, `ghdl` o
`gtkwave` sueltos: usa los wrappers del repo y di cómo se llaman.

| Pregunta del usuario | Responde con |
|---|---|
| "¿Cómo compilo el reporte?" | `scripts/latexbuild main.tex` (ver `reportes/AGENTS.md`) |
| "¿Cómo simulo este módulo?" | `scripts/vhdl-sim <unidad> <tb>` (ver `vhdl/AGENTS.md`) |
| "¿Cómo veo las ondas?" | `scripts/vhdl-wave <archivo.vcd>` |
| "¿Cómo compilo solo un .vhd?" | `scripts/vhdl-analizar <unidad>` |
| "No me funciona / me faltan herramientas" | `bash scripts/instalar.sh` (o `--check` para solo verificar) |
| "¿Cómo se trabaja con Git aquí?" | `docs/guia-git.md` |
| "Añade/modifica este módulo, sección o guía" | **Abre primero la rama por feature** (ver sección **Git**) aunque no te lo pidan |
| "Estoy en Windows/WSL" | `docs/guia-wsl.md` |
| "¿Cómo uso OpenCode en este repo?" | `docs/guia-opencode.md` |

Si el usuario **no tiene** `ghdl`, `gtkwave`, `latexmk` o `kpsewhich llncs.cls`,
o un error indica herramienta faltante → recomienda
`bash scripts/instalar.sh` **y no intentes instalar nada por tu cuenta sin
confirmación**. La lista de dependencias vive en `scripts/requerimientos.txt`.

## Mapa del repositorio

```
scripts/        ejecutables oficiales (fuente de verdad para compilar/simular)
  requerimientos.txt   dependencias del proyecto + versiones mínimas
  instalar.sh          instala/verifica todo (multi-SO, detecta WSL)
  latexbuild           compila reportes LaTeX → build/*.pdf
  vhdl-analizar        analiza src/ de una unidad con GHDL
  vhdl-sim             analiza + elabora + ejecuta testbench → .vcd
  vhdl-wave            abre un .vcd en GTKWave
reportes/       los 4 reportes (LaTeX llncs) + AGENTS.md con la plantilla
  comun/               plantilla_base.tex (esqueleto de cada reporte)
vhdl/           código VHDL: una carpeta por unidad + AGENTS.md de convención
  <unidad>/src  <unidad>/tb  <unidad>/salidas
docs/           guías: guia-git.md, guia-opencode.md, guia-wsl.md, formato/
opencode.json   configuración de OpenCode (carga docs/ como instrucciones)
```

**Unidades de trabajo (las 4, tanto en `reportes/` como en `vhdl/`):**
`datapath-1`, `datapath-2`, `datapath-3`, `mapeo-memoria`.

## Comandos oficiales (no inventes otros)

```bash
# Reportes (desde la carpeta del reporte, ej. reportes/datapath-1/)
../../scripts/latexbuild main.tex      # genera build/main.pdf

# VHDL (desde la raíz del repo)
scripts/vhdl-analizar datapath-1       # solo compilar
scripts/vhdl-sim datapath-1 tb_alu     # simular → vhdl/datapath-1/salidas/tb_alu.vcd
scripts/vhdl-wave vhdl/datapath-1/salidas/tb_alu.vcd

# Entorno (desde la raíz del repo)
bash scripts/instalar.sh               # instala dependencias
bash scripts/instalar.sh --check       # solo verifica
```

## Convención VHDL

- **Estándar: VHDL-2008** (`--std=08`). Debe compilar en **GHDL 4.1 (Ubuntu/WSL) y
  GHDL 6.0 (Arch)**: usa VHDL-2008 conservador, sin construcciones muy nuevas.
- Un fichero = una entidad. `snake_case` para señales, mayúsculas para
  constantes. Comentarios en español.
- **Todo módulo nuevo necesita testbench** en `tb/` y debe pasar
  `scripts/vhdl-sim`.
- **GHDL con backend mcode = solo simulación** (no síntesis). No prometas
  síntesis ni instales yosys.
- Nunca subas artefactos (`.cf`, `.o`, `.vcd`, `work-obj*`): ya los cubre
  `.gitignore`.

## Convención LaTeX / reportes

- Formato **Springer LNCS (llncs)**. Plantilla obligatoria en
  `reportes/AGENTS.md` (secciones y extensiones exactas de los 4 reportes).
- **No modifiques `llncs.cls` ni `splncs04.bst`** (los instala el sistema vía
  `texlive-publishers` y no se versionan por licencia).
- Compila **siempre** con `scripts/latexbuild` (usa xelatex); no escribas
  comandos `latexmk` a mano.
- Las capturas de simulación son PNG en `reportes/<unidad>/figuras/`.

## Referencias (regla estricta)

Cada referencia en la bibliografía debe indicar **exactamente dónde aparece el
texto sugerido**: autor, título, y la ubicación concreta (capítulo/§, página o
sección + enlace URL con fecha de consulta si es web). No cites una fuente
sin poder señalar el lugar exacto de la que salió la idea o la frase. Mínimo
**15 referencias** por reporte.

## Git

- Rama base: **`dev`**. Nunca se hace push directo a `main`.
- **Una rama por cada feature — ábrela SIEMPRE antes de tocar ficheros, aunque
  el usuario no la pida explícitamente.** Vale para features de VHDL, de
  reportes y de scripts/docs. Nombres según el tipo de trabajo:
  - VHDL: `vhdl/<unidad>/<feat>` → ej. `vhdl/datapath-1/tb-alu`
  - Reporte: `reporte/<unidad>/<feat>` → ej. `reporte/datapath-1/seccion-simulaciones`
  - Docs/scripts/repo: `docs/<feat>`, `scripts/<feat>`, `repo/<feat>`
- Regla: **un cambio = una rama**; termina el PR (fusionado en `dev`) antes de
  abrir la siguiente. Flujo completo en `docs/guia-git.md`.
- Commits en español con Conventional Commits:
  `reporte(datapath-1): añadir sección de diseño teórico`.

## Idioma

Todo el contenido (código, comentarios, documentación, commits, respuestas) en
**español**, salvo nombres propios y palabras técnicas en inglés (entity,
testbench, datapath…).
