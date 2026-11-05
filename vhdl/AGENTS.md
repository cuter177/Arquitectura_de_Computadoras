# AGENTS.md — Código VHDL

Convención para el código VHDL de las 4 unidades:
`datapath-1`, `datapath-2`, `datapath-3`, `mapeo-memoria`.

## Estructura de cada unidad

```
vhdl/<unidad>/
  src/        una entidad por fichero (el diseño)
  tb/         un testbench por módulo
  salidas/    .vcd generados (NO se versionan, ya ignorados)
  .ghdl/      workdir temporal de GHDL (NO se versiona)
```

## Simular: usa siempre los scripts del repo

No recomiendes ni ejecutes `ghdl` a mano; deriva a los wrappers:

```bash
scripts/vhdl-analizar datapath-1            # solo analizar/compilar src/ + tb/
scripts/vhdl-sim datapath-1 tb_alu          # analizar + elaborar + ejecutar
scripts/vhdl-wave vhdl/datapath-1/salidas/tb_alu.vcd   # ver ondas en GTKWave
```

`vhdl-sim` genera `vhdl/<unidad>/salidas/<tb>.vcd`. Si algo falla por
herramienta faltante → `bash scripts/instalar.sh`.

## Reglas de código

- **Estándar VHDL-2008** (`--std=08`, ya fijado en los scripts).
- **Portabilidad GHDL 4.1 (Ubuntu/WSL) y GHDL 6.0 (Arch)**: VHDL-2008
  conservador. Evita construcciones muy recientes o poco soportadas.
- **Un fichero = una entidad** (`sumador.vhd` contiene `entity sumador`).
- Nombres: `snake_case` para señales y puertos, `CONSTANTES` en mayúsculas,
  tipos en `CamelCase`. Comentarios y cadenas en español.
- Siempre `library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;`
  (usa `numeric_std`, **no** `std_logic_arith`/`std_logic_unsigned`).
- Cabecera breve en cada fichero: qué hace el módulo.

## Testbenches (obligatorios)

- Todo módulo nuevo en `src/` necesita su testbench en `tb/`, con
  autochequeo: `assert ... severity failure` si algo falla y un
  `report "... OK"` al pasar.
- Nombre: `tb_<modulo>.vhd` → entidad `tb_<modulo>`.
- El testbench debe **fallar** ante un resultado incorrecto (no solo imprimir).
- Antes de dar por terminado un módulo, debe pasar:
  `scripts/vhdl-sim <unidad> tb_<modulo>`.

## Nota sobre síntesis

El GHDL del equipo es backend **mcode**: **solo simulación**. No se trabaja
síntesis en este proyecto (no hay yosys ni flujo de síntesis). Si un usuario
pregunta por sintetizar, aclara que el flujo del curso es simulación con
GHDL + visualización con GTKWave.

## Git: una rama por cada feature

Cada módulo, testbench o refactor nuevo es una feature: **abre su rama antes
de escribir el primer fichero**, aunque el usuario no lo pida explícitamente:

```bash
git switch dev && git pull
git switch -c vhdl/<unidad>/<feat>     # ej.: vhdl/datapath-1/tb-alu
```

Al terminar (testbench pasando), PR de esa rama → `dev`. **Una feature = una
rama**: no acumules dos features distintas en la misma rama. Detalle completo
del flujo en `docs/guia-git.md`.

## Artefactos

Nunca hagas `commit` de: `*.cf`, `*.o`, `*.ali`, `work-obj*`, `*.vcd`,
`*.ghw`, `.ghdl/`, `salidas/`. Todo eso ya está en `.gitignore`.
Las **capturas** que van en los reportes son PNG exportados de GTKWave, y se
guardan en `reportes/<unidad>/figuras/`.
