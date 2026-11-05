## ¿Qué feature es esta rama?

<!-- Una frase. Si no cabe en una frase, es más de una feature → parte la rama
     (docs/guia-git.md, regla 6: una rama por cada feature). -->

## Cambios

<!-- Lista breve de lo que toca. Unidad afectada: datapath-1 | datapath-2 |
     datapath-3 | mapeo-memoria | docs | scripts | repo -->

## Checklist

- [ ] Esta rama contiene **una sola feature** (una rama = un cambio)
- [ ] Nombre de rama correcto: `vhdl/<unidad>/<feat>`, `reporte/<unidad>/<feat>`, `docs/<feat>`, `scripts/<feat>`, `repo/<feat>`
- [ ] Commits en español con Conventional Commits (`tipo(alcance): descripción`)
- [ ] Sin artefactos en el diff (`.cf`, `.o`, `.vcd`, `build/`, `.ghdl/`, `salidas/`)
- [ ] **VHDL:** pasa `scripts/vhdl-analizar <unidad>` y `scripts/vhdl-sim <unidad> tb_<modulo>`
- [ ] **VHDL:** todo módulo nuevo tiene su testbench autochequeado en `tb/`
- [ ] **Reporte:** compila con `../../scripts/latexbuild main.tex` (desde la carpeta del reporte)
- [ ] **Reporte:** respeta la plantilla de `reportes/AGENTS.md` (secciones, orden y extensiones)
- [ ] **Reporte:** ≥ 15 referencias y cada una indica en `note` dónde aparece el texto
- [ ] **Reporte:** si cambió el VHDL, el apéndice está actualizado

## Capturas / evidencias

<!-- Si es VHDL: ruta del .vcd y cómo se simuló. Si es reporte: build/main.pdf
     compilando. Adjunta la captura si aporta. -->
