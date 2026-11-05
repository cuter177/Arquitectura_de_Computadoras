# ============================================================
# Captura de ondas de tb_datapath (5–95 ns):
# rst, carga de n=5 con 000 y M=1, doblar n+x con 001 y la
# contraprueba 100010 (C=010, L=0): la ALU cambia, el
# registro conserva su valor. Ejecutar DESDE LA RAÍZ:
#   gtkwave -r reportes/datapath-1/capturas/gtkwave.rc \
#           -S reportes/datapath-1/capturas/tb-datapath-ondas.tcl \
#           vhdl/datapath-1/salidas/tb_datapath.vcd
# Genera reportes/datapath-1/figuras/tb-datapath-ondas.png
# Tras el volcado, recortar con:
#   python3 reportes/datapath-1/capturas/recortar.py 115 \
#           reportes/datapath-1/figuras/tb-datapath-ondas.png
# ============================================================
gtkwave::addSignalsFromList {
tb_datapath.clk
tb_datapath.rst
tb_datapath.dato_ext[7:0]
tb_datapath.cw[5:0]
tb_datapath.f_alu[7:0]
tb_datapath.q_reg[7:0]
tb_datapath.salida[7:0]
}
gtkwave::/View/Left_Justified_Signals
gtkwave::/View/Use_Black_and_White
gtkwave::/Edit/Highlight_All
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/UnHighlight_All
gtkwave::highlightSignalsFromList {tb_datapath.cw[5:0]}
gtkwave::/Edit/Data_Format/Binary
gtkwave::/Edit/UnHighlight_All
gtkwave::/Time/Zoom/Zoom_Best_Fit
after 1500
gtkwave::setZoomRangeTimes 5000000 95000000
gtkwave::/File/Grab_To_File "reportes/datapath-1/figuras/tb-datapath-ondas.png"
gtkwave::/File/Quit
