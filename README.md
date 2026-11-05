# Arquitectura de Computadoras

Repositorio del equipo (5 integrantes): **4 reportes en formato Springer
(LaTeX/llncs)** y su **código VHDL** simulado con GHDL + GTKWave.

| | |
|---|---|
| **Reportes** | `datapath-1`, `datapath-2`, `datapath-3`, `mapeo-memoria` |
| **Formato** | Springer LNCS (`llncs`), plantilla en `reportes/AGENTS.md` |
| **VHDL** | VHDL-2008, simulación con GHDL, ondas en GTKWave |
| **Rama base** | `dev` (Git Flow ligero, PRs hacia `dev`) |
| **IA** | OpenCode con los `AGENTS.md` del repo |

## Puesta en marcha

```bash
git clone git@github.com:cuter177/Arquitectura_de_Computadoras.git
cd Arquitectura_de_Computadoras
bash scripts/instalar.sh        # instala/verifica todo lo necesario
curl -fsSL https://opencode.ai/v2/install | bash   # OpenCode (si no lo tienes)
opencode                        # ábrelo SIEMPRE desde la raíz del repo
```

- **Windows / WSL (equipo):** sigue `docs/guia-wsl.md`.
- **Linux / macOS:** `scripts/instalar.sh` detecta tu distro.

## Comandos oficiales

```bash
# Reportes (desde la carpeta del reporte)
../../scripts/latexbuild main.tex          # → build/main.pdf

# VHDL (desde la raíz)
scripts/vhdl-analizar datapath-1           # compilar src/ + tb/
scripts/vhdl-sim datapath-1 tb_alu         # simular → .vcd
scripts/vhdl-wave vhdl/datapath-1/salidas/tb_alu.vcd   # ver ondas

# Entorno
bash scripts/instalar.sh                   # instalar
bash scripts/instalar.sh --check           # solo verificar
```

## Estructura

```
scripts/    scripts oficiales (fuente de verdad para compilar/simular)
  requerimientos.txt  dependencias + versiones mínimas
  instalar.sh         instalador multi-SO (detecta WSL)
  latexbuild          compila reportes LaTeX
  vhdl-analizar|vhdl-sim|vhdl-wave   flujo GHDL/GTKWave
reportes/   los 4 reportes LaTeX + plantilla (comun/plantilla_base.tex)
  <unidad>/   main.tex  referencias.bib  figuras/
vhdl/       una carpeta por unidad
  <unidad>/   src/ (diseño)  tb/ (testbenches)  salidas/ (.vcd, no se versionan)
docs/       guias: wsl, git, opencode + plantilla docx de referencia
.github/    plantilla de PR + issues + CI (GHDL y scripts en cada PR)
AGENTS.md   reglas del proyecto para la IA (OpenCode)
```

## Documentación

| Doc | Para qué |
|---|---|
| [`docs/guia-wsl.md`](docs/guia-wsl.md) | Montar el entorno en Windows + WSL |
| [`docs/guia-git.md`](docs/guia-git.md) | Ramas, commits, PRs, conflictos |
| [`docs/guia-opencode.md`](docs/guia-opencode.md) | Trabajar con OpenCode en este repo |
| [`AGENTS.md`](AGENTS.md) | Reglas del proyecto (las lee la IA) |
| [`reportes/AGENTS.md`](reportes/AGENTS.md) | Plantilla obligatoria de los reportes |
| [`vhdl/AGENTS.md`](vhdl/AGENTS.md) | Convención de código VHDL |

## Reglas clave

- **Referencias:** mínimo 15 por reporte, indicando **exactamente dónde aparece
  el texto sugerido** (capítulo/página/URL+fecha).
- **VHDL:** un testbench obligatorio por módulo; debe pasar `scripts/vhdl-sim`.
- **Compilación:** siempre vía `scripts/latexbuild` (nunca `latexmk` a mano).
- **Git:** nunca push directo a `main`; todo por PR hacia `dev`, y **una rama
  por cada feature** (`vhdl/<unidad>/<feat>`, `reporte/<unidad>/<feat>`…),
  aunque no te la pidan.
- **PRs:** la checklist de `.github/PULL_REQUEST_TEMPLATE.md` resume lo que
  debe cumplir todo cambio; el CI repite la parte automatizable (`bash -n` de
  los scripts + `vhdl-analizar`/`vhdl-sim` de cada unidad).
