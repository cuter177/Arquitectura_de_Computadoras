# AGENTS.md — Reportes (Springer / llncs)

Esta carpeta contiene los **4 reportes** del proyecto. Cada uno en su propia
carpeta con un `main.tex`:

```
reportes/
  comun/plantilla_base.tex   esqueleto llncs con todas las secciones (copiarlo)
  datapath-1/   main.tex  referencias.bib  figuras/
  datapath-2/
  datapath-3/
  mapeo-memoria/
```

## Plantilla obligatoria de los 4 reportes

Cada reporte DEBE seguir exactamente este orden y estas extensiones
(aproximadas; 1 cuartilla ≈ 1 página de la zona de impresión llncs de
122 mm × 193 mm):

| Sección | Contenido | Extensión |
|---|---|---|
| **Título** | Título del trabajo | — |
| **Autores** | Los integrantes del equipo (nombre + afiliación + correo) | — |
| **Resumen** | `Resumen.` + síntesis del trabajo | **< 100 palabras** |
| **Palabras Clave** | `Palabras Clave:` separadas por comas, inicial mayúscula | — |
| **1. Introducción** | Motivación, objetivos, estructura del paper | 1–2 cuartillas |
| **2. Diseño teórico** | Marco teórico, arquitectura, módulos VHDL | 3–5 cuartillas |
| **3. Propuesta experimental** | Metodología, bancos de prueba, herramientas (GHDL/GTKWave) | 1 hoja |
| **4. Simulaciones de VHDL** | Capturas de los **módulos más importantes** | **máx. 2 hojas** |
| **5. Resultados** | Análisis de las simulaciones, tablas, figuras | 3–5 cuartillas |
| **6. Conclusiones** | Cierre y trabajo futuro | 1 cuartilla |
| **Referencias** | Bibliografía | **≥ 15 referencias** (≥ 15 con ISBN/ISSN/DOI) |
| **Apéndice** | **Código VHDL** completo (el de `vhdl/<unidad>/`) | — |

Al trabajar en un reporte:

1. **Copia `comun/plantilla_base.tex`** como punto de partida (preámbulo llncs,
   bloque de autores, secciones ya nombradas).
2. Mantén los **nombres de sección** de la tabla (son los que pide el formato).
3. Si el usuario pide una sección concreta, respeta su extensión máxima.
4. **No** metas texto de relleno inventado en referencias.
5. **Abre la rama de la feature antes de escribir** (ver siguiente sección).

## Git: una rama por cada feature

Cada bloque de trabajo del reporte es una feature: una sección nueva, la
bibliografía, el apéndice, una tanda de capturas... **Abre su rama antes de
tocar el `.tex`**, aunque el usuario no lo pida explícitamente:

```bash
git switch dev && git pull
git switch -c reporte/<unidad>/<feat>   # ej.: reporte/datapath-1/seccion-simulaciones
```

Al terminar, PR de esa rama → `dev`. **Una feature = una rama**: no mezcles en
la misma rama secciones de unidades distintas. Flujo completo en
`docs/guia-git.md`.

## Reglas de formato llncs

- **No editar `llncs.cls` ni `splncs04.bst`**: los instala el sistema
  (`texlive-publishers`) y no se versionan (ver `.gitignore`).
- Clase: `\documentclass[llncs]{llncs}`. Compilación **siempre** con
  `scripts/latexbuild main.tex` (xelatex) — nunca `latexmk` a mano.
- Bibliografía: `\bibliography{referencias}` con `referencias.bib` y el estilo
  `splncs04` (numérico). Cita numérica `[n]`.
- Texto justificado, imágenes con buena resolución y buen contraste en gris.
- Figuras: `figuras/*.png`, referenciadas con `\includegraphics`.
- Las capturas de simulación que se ponen en la sección 4 salen de
  `vhdl/<unidad>/salidas/` (VCD) → exportadas a PNG en `figuras/`.

## Referencias (regla estricta)

- **Mínimo 15** por reporte.
- **Al menos 15 deben estar indexadas**: cada una con su identificador en
  el campo correspondiente del `.bib` — `isbn` (libros), `issn` (revistas)
  o `doi` (artículos, capítulos y estándares). El identificador debe
  **verificarse antes de citar** (IEEE Xplore, ACM DL, doi.org, catálogo
  editorial…); nada de relleno inventado. `splncs04` **no imprime**
  `isbn`/`issn`/`doi` por sí solo, así que refleja el identificador
  también en el campo `note` para que se vea en el PDF:

  ```bibtex
  @article{smith1982,
    author  = {Smith, Alan Jay},
    title   = {Cache Memories},
    journal = {ACM Computing Surveys},
    volume  = {14}, number = {3}, pages = {473--530},
    year    = {1982},
    doi     = {10.1145/356887.356892},
    note    = {sección 2 — funciones de mapeo y thrashing; DOI: 10.1145/356887.356892, ISSN: 0360-0300}
  }
  ```

  Las `@misc` de Wikipedia o de documentación de herramientas (GHDL,
  GTKWave…) no tienen ni admiten identificador; no las cuentes para las
  15.
- Cada referencia debe indicar **exactamente dónde aparece el texto sugerido**:
  dejar constancia de la ubicación concreta (capítulo/§, página, figura, tabla
  o URL + fecha de consulta) en el campo `note` de la entrada `.bib`. Ejemplo:

  ```bibtex
  @book{mannering2018,
    author    = {Autor Apellido},
    title     = {Título del libro},
    publisher = {Editorial},
    year      = {2018},
    note      = {cap. 4, p. 123 — frase sobre pipeline de etapas}
  }
  ```

  Ojo: el `.bib` **no admite comentarios** dentro de una entrada, y bibtex
  falla si el texto no tiene ninguna `\cite`.
- No cites nada que no puedas ubicar en la fuente.

## Apéndice con código VHDL

El apéndice reproduce el código VHDL de la unidad correspondiente
(`vhdl/<unidad>/src/`), con viñetas/listings legibles (monoespaciada, tamaño
reducido, negro). Si el código cambia en `vhdl/`, hay que actualizar el
apéndice del reporte correspondiente.
