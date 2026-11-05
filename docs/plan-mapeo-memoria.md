# Plan de trabajo — Unidad `mapeo-memoria`

> Plan completo para la unidad **mapeo-memoria**: comparación mediante
> simulación VHDL de las tres funciones de mapeo de la memoria caché
> (directo, asociativo total y asociativo por conjuntos) y su reflejo en el
> reporte Springer `reportes/mapeo-memoria/`.
>
> Reglas aplicables: `AGENTS.md` (raíz), `vhdl/AGENTS.md`, `reportes/AGENTS.md`
> y `docs/guia-git.md`.

---

## 1. Objetivo

Comparar tres métodos de mapeo de memoria caché con el mismo banco de pruebas,
la misma memoria principal y la misma traza de accesos:

| Método | Descripción del equipo | Nombre técnico (Stallings) |
|---|---|---|
| Directo | búsqueda lineal de instrucciones a una línea fija | *direct mapping* (`i = j mod m`) |
| Asociativo | uso de etiquetas, cualquier bloque en cualquier línea | *associative mapping* (total) |
| Asociativo en conjuntos | caché dividida en conjuntos + etiquetas | *set-associative mapping* (`k`-way) |

En el reporte se usa la **terminología estándar** de Stallings; la descripción
del equipo se aclara como analogía en la introducción.

## 2. Estado de partida (verificado)

- `vhdl/mapeo-memoria/` **no existe todavía**; hay que crear `src/`, `tb/` y
  `salidas/`. No hay ningún `.vhd` en el repo todavía.
- `reportes/mapeo-memoria/main.tex` es la plantilla sin rellenar (copiada de
  `reportes/comun/plantilla_base.tex`).
- `reportes/mapeo-memoria/referencias.bib` tiene solo 2 entradas
  (`ghdl-docs`, `gtkwave-docs`); faltan ≥13 para las ≥15 obligatorias.
- Herramientas disponibles en el equipo: GHDL 6.0 (backend mcode, solo
  simulación), `latexmk` y `llncs.cls` (vía `texlive-publishers`).
- El CI (`.github/workflows/ci.yml`) ejecuta en cada PR `bash -n` de los
  scripts, `scripts/vhdl-analizar` por unidad y **todos** los `tb_*.vhd` que
  existan → cada testbench debe pasar desde su PR.

## 3. Decisiones de diseño (acordadas)

- **Solo lectura** (fetch de instrucciones): sin dirty bit ni política de
  escritura. Se documenta como simplificación en la sección 3 del reporte y
  como trabajo futuro en las conclusiones.
- **Parámetros comunes** (mini-Ejemplo 5.1 de Stallings, p. 168–180):

| Parámetro | Valor |
|---|---|
| Dirección | 10 bits, direccionamiento a nivel de byte |
| Palabra / bloque | 4 bytes (offset = 2 bits) |
| Memoria principal | 1 KB = 256 bloques de 4 B |
| Caché | 64 B = 16 líneas de 4 B |
| Mapeo directo | `tag(4) \| índice(4) \| offset(2)`, índice = bloque mod 16 |
| Mapeo asociativo | `tag(8) \| offset(2)`, comparación paralela de 16 tags, LRU |
| Mapeo por conjuntos | 8 conjuntos × 2 vías: `tag(5) \| conjunto(3) \| offset(2)`, LRU de 1 bit/conjunto |

- **Misma interfaz** en los 3 cachés para que la comparación sea justa.
- Reemplazo donde aplique: **LRU** (Stallings §5.2, p. 181).
- Latencia de memoria principal: **1 ciclo** (modelo de comportamiento).

### Interfaz común de los cachés (propuesta)

```vhdl
-- Todos los cachés de la unidad exponen esta interfaz (nombres exactos
-- pueden variar ligeramente; se mantienen iguales entre módulos).
entity cache_<metodo> is
  generic (
    -- tamaños derivados de la tabla de la §3; por defecto los del mini-ejemplo
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    addr     : in  unsigned(9 downto 0);  -- dirección solicitada (byte)
    req      : in  std_logic;             -- pulso de solicitud de lectura
    ready    : out std_logic;             -- dato válido
    data     : out unsigned(31 downto 0); -- palabra devuelta
    hit      : out std_logic;             -- 1 si acierto en caché
    -- hacia memoria principal (solo lectura)
    mem_addr : out unsigned(9 downto 0);
    mem_req  : out std_logic;
    mem_data : in  unsigned(31 downto 0);
    mem_ready: in  std_logic
  );
end entity;
```

Máquina de estados común: `IDLE → COMPARE → (FETCH_MEM → DONE) | DONE`.

## 4. VHDL — `vhdl/mapeo-memoria/`

| Fichero | Contenido |
|---|---|
| `src/memoria_principal.vhd` | RAM de comportamiento, 1 ciclo, inicializable (función de carga desde el tb) |
| `src/cache_directo.vhd` | tag \| índice \| offset, 1 comparador, sin reemplazo |
| `src/cache_asociativa.vhd` | comparación paralela de los 16 tags, registro LRU |
| `src/cache_conjuntos.vhd` | 8 conjuntos × 2 vías, LRU de 1 bit por conjunto |
| `tb/tb_memoria_principal.vhd` | lecturas a varias direcciones, autochequeado |
| `tb/tb_cache_directo.vhd` | traza con hits, misses y patrón *thrashing* |
| `tb/tb_cache_asociativa.vhd` | misma traza; verifica que el thrashing del directo acierta aquí |
| `tb/tb_cache_conjuntos.vhd` | misma traza; intermedio esperado |
| `tb/tb_comparacion_mapeos.vhd` | instancia los 3 cachés + memoria compartida; `report` final con aciertos/fallos/tasa de cada uno (fuente de la tabla del reporte) |

Convenciones obligatorias (`vhdl/AGENTS.md`): VHDL-2008 conservador,
un fichero = una entidad, `snake_case`, `numeric_std`, comentarios en español,
cabecera breve, testbenches con `assert ... severity failure` y
`report "... OK"`.

### Señales que debe exponer cada testbench en el `.vcd`

Las capturas del reporte salen de los `.vcd`, así que cada tb declara
señales `signal` (no solo variables internas) con estos nombres para que las
ondas sean comparables entre los 3 mapeos:

| Señal | Tipo | Para qué se ve en la captura |
|---|---|---|
| `clk`, `rst` | `std_logic` | base temporal y arranque |
| `ciclo` | `unsigned` | contador de ciclos (eje horizontal legible) |
| `addr` | `unsigned(9 downto 0)` | dirección solicitada por ciclo |
| `req`, `ready` | `std_logic` | ventana de solicitud y fin de acceso |
| `hit` | `std_logic` | **acierto (1) vs fallo (0)** — motivo principal de la captura |
| `data` | `unsigned(31 downto 0)` | palabra devuelta (verifica dato correcto) |
| `estado` | estado de la FSM (`enum` o `unsigned`) | se ve IDLE/COMPARE/FETCH_MEM/DONE |
| `caches_hits`, `caches_misses` | `unsigned` (solo en tbs de métricas) | evolución de contadores |
| `bloque_cargado` | `std_logic` (opcional) | pulso al completar una carga desde memoria |

`tb_comparacion_mapeos` añade, por cada módulo, `hit_directo`,
`hit_asociativa`, `hit_conjuntos` y sus contadores, para capturar en una sola
onda los tres métodos lado a lado.

### Workflow de capturas (VCD → PNG para el reporte)

1. **Generar el `.vcd`** (no se versiona; `.gitignore` ya lo cubre):
   ```bash
   scripts/vhdl-sim mapeo-memoria tb_cache_directo
   # → vhdl/mapeo-memoria/salidas/tb_cache_directo.vcd
   ```
2. **Abrirlo en GTKWave** con el wrapper oficial (no `gtkwave` a mano):
   ```bash
   scripts/vhdl-wave vhdl/mapeo-memoria/salidas/tb_cache_directo.vcd
   ```
3. **Cargar las señales** en el panel izquierdo (`SST`/jerarquía del tb) e
   **insertarlas** en el panel de ondas: al menos `clk`, `ciclo`, `addr`,
   `req`, `ready`, `hit`, `data`, `estado`.
4. **Enfocar la zona útil**: buscar con `Search → Track` o zoom (`z`/`Z`) el
   patrón que interesa mostrar — p. ej. un miss (`hit = '0'`) seguido del
   pulso de carga y el siguiente hit. Ajustar a ~20–40 ciclos por captura para
   que siga siendo legible en el ancho de columna llncs.
5. **Exportar PNG**: `File → Print...` con destino *Print to File* (o
   captura de la zona de ondas con la herramienta del sistema). Convertir el
   PDF a PNG si hace falta (`pdftoppm -png -r 200`), fondo blanco y trazos
   con buen contraste (las figuras se imprimen en gris).
6. **Guardar en el reporte** con nombre descriptivo:
   `reportes/mapeo-memoria/figuras/<tb>_<qué-se-ve>.png`
   ej.: `figuras/tb_cache_directo_miss.png`,
   `figuras/tb_comparacion_hits.png`.
7. **Referenciar en el LaTeX** (sección 4) con `\includegraphics` + caption
   que explique qué se observa (hit/miss, carga de bloque, contadores).

Nota: los PNG de `figuras/` **sí se versionan** (evidencia del reporte); los
`.vcd` de `salidas/` no.

## 5. Reporte — `reportes/mapeo-memoria/`

Rellenar `main.tex` siguiendo la plantilla de `reportes/AGENTS.md`:

| Sección | Contenido | Extensión |
|---|---|---|
| Título / Autores | por rellenar (5 integrantes) | — |
| Resumen | objetivo + GHDL/GTKWave + resultado | < 100 palabras |
| 1. Introducción | motivación, objetivos, estructura; aclara nombres técnicos | 1–2 cuart. |
| 2. Diseño Teórico | los 3 mapeos, fórmulas, figuras, módulos VHDL, decisiones | 3–5 cuart. |
| 3. Propuesta Experimental | metodología GHDL/GTKWave, VHDL-2008, bancos de prueba, parámetros | 1 hoja |
| 4. Simulaciones de VHDL | capturas PNG de los módulos más importantes | máx. 2 hojas |
| 5. Resultados | tabla comparativa (tasas del tb de comparación), gráfico, análisis | 3–5 cuart. |
| 6. Conclusiones | cuándo conviene cada mapeo; trabajo futuro (escrituras, L1/L2) | 1 cuart. |
| Referencias | ≥ 15 con ubicación exacta en `note` | ≥ 15 |
| Apéndice | código VHDL completo de `src/` | — |

Capturas: `.vcd` de `vhdl/mapeo-memoria/salidas/` → PNG en
`reportes/mapeo-memoria/figuras/` (buen contraste, legible en gris).

### Referencias mínimas previstas (con ubicación verificada)

- Stallings, *Computer Organization and Architecture*, 11ª ed. (Global), 2021 —
  cap. 5 "Cache Memory", pp. 160–198: directo pp. 168–171; asociativo/CAM
  pp. 171–175; por conjuntos pp. 176–180; reemplazo pp. 181–182; política de
  escritura pp. 182–183; rendimiento pp. 191–194.
- Hennessy & Patterson, *Computer Architecture: A Quantitative Approach*,
  6ª ed., 2019 — cap. 2 "Memory Hierarchy Design".
- Patterson & Hennessy, *Computer Organization and Design* (RISC-V ed.), 2021 —
  cap. 5 "Memory: Hierarchy and Protection".
- Bryant & O'Hallaron, *CS:APP*, 3ª ed., 2015 — cap. 6 §6.2–6.4.
- Wikipedia «Caché (informática)» + fecha de consulta.
- GHDL y GTKWave (ya en el `.bib`).

Cada entrada en `referencias.bib` lleva `note` con cap/§/página o URL+fecha.

## 6. Flujo Git (una feature = una rama)

Cada paso es una rama independiente con su PR → `dev` (regla 6 de
`docs/guia-git.md`). Nombres de rama y orden:

| # | Rama | Contenido |
|---|---|---|
| 1 | `vhdl/mapeo-memoria/cache-directo` | estructura de la unidad + `memoria_principal` + `cache_directo` + sus tbs |
| 2 | `vhdl/mapeo-memoria/cache-asociativa` | `cache_asociativa` + tb |
| 3 | `vhdl/mapeo-memoria/cache-conjuntos` | `cache_conjuntos` + tb |
| 4 | `vhdl/mapeo-memoria/comparacion-mapeos` | `tb_comparacion_mapeos` con métricas |
| 5 | `reporte/mapeo-memoria/marco-teorico` | título/autores, resumen, secciones 1–2 |
| 6 | `reporte/mapeo-memoria/referencias` | `referencias.bib` ≥ 15 con `note` |
| 7 | `reporte/mapeo-memoria/propuesta-experimental` | sección 3 |
| 8 | `reporte/mapeo-memoria/simulaciones` | sección 4 + capturas PNG en `figuras/` (workflow de la §4 de este plan) |
| 9 | `reporte/mapeo-memoria/resultados-conclusiones` | secciones 5–6 |
| 10 | `reporte/mapeo-memoria/apendice-vhdl` | apéndice con el código final |

Commits en español con Conventional Commits, ej.:
`vhdl(mapeo-memoria): añadir caché de mapeo directo con su testbench`,
`reporte(mapeo-memoria): añadir marco teórico de los tres mapeos`.

## 7. Verificación (en cada paso)

```bash
# VHDL — desde la raíz del repo
scripts/vhdl-analizar mapeo-memoria
scripts/vhdl-sim mapeo-memoria tb_cache_directo        # y cada tb nuevo
scripts/vhdl-wave vhdl/mapeo-memoria/salidas/tb_cache_directo.vcd

# Reporte — desde reportes/mapeo-memoria/
../../scripts/latexbuild main.tex                      # → build/main.pdf
```

Checklist de cierre (espejo del PR template):

- [ ] Rama con una sola feature y nombre correcto.
- [ ] Commits en español, Conventional Commits.
- [ ] Sin artefactos en el diff (`.vcd`, `.cf`, `.ghdl/`, `salidas/`, `build/`).
- [ ] Todo módulo nuevo tiene tb autochequeado que pasa `vhdl-sim`.
- [ ] Reporte compila con `latexbuild` y respeta secciones/extensiones.
- [ ] ≥ 15 referencias con ubicación exacta en `note`.
- [ ] Apéndice actualizado si cambió el VHDL de `src/`.

## 8. Riesgos y notas

- **GHDL mcode**: solo simulación; no prometer síntesis (no hay yosys).
- **Portabilidad GHDL 4.1/6.0**: VHDL-2008 conservador; evitar construcciones
  nuevas. Probar en el GHDL del equipo (6.0) y confiar en el CI (Ubuntu) para
  la 4.x.
- El CI fallará si un tb no termina (bucle infinito): los tbs deben tener un
  número finito de ciclos y un `report "... OK"` final.
- Si un `.bib` no tiene ninguna `\cite`, bibtex falla → las citas se colocan
  al escribir cada sección.
- `git pull`/`push` requieren clave SSH configurada en la máquina que lo
  ejecute.
