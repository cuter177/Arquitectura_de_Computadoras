#!/usr/bin/env bash
# Genera las capturas de ondas de la sección 4 del reporte de datapath-3.
# Requiere gtkwave y los VCD de vhdl/datapath-3/salidas/ (scripts/vhdl-sim).
set -euo pipefail
cd "$(dirname "$0")/../../.."   # raíz del repo
CAPT=reportes/datapath-3/capturas
FIGS=reportes/datapath-3/figuras
SAL=vhdl/datapath-3/salidas

gen() {  # gen <tb> <nombre-fichero>
  gtkwave -r "$CAPT/gtkwave.rc" -S "$CAPT/$2.tcl" "$SAL/$1.vcd" >/dev/null 2>&1
  python3 "$CAPT/recortar_png.py" "$FIGS/$2-captura.png" "$FIGS/$2.png"
  rm -f "$FIGS/$2-captura.png"
}

gen tb_exp1_suma          exp1-suma-ondas
gen tb_exp2_factorial     exp2-factorial-ondas
gen tb_exp3_mult          exp3-multiplicacion-ondas
gen tb_exp4_fibonacci     exp4-fibonacci-ondas
echo "Capturas listas en $FIGS/"
