# ============================================================
# Captura de ondas de tb_datapath (105–170 ns):-buffer de
# salida tri-estado. Tras el segundo rst se carga n=60 (0x3C)
# con la salida en alta impedancia ('Z' con O.E=0) y el cw
# 100000 la habilita; después el cw 110010 incrementa (q=3D).
# Ejecutar DESDE LA RAÍZ:
#   gtkwave -r reportes/datapath-1/capturas/gtkwave.rc \
#           -S reportes/datapath-1/capturas/tb-datapath-salida.tcl \
#           vhdl/datapath-1/salidas/tb_datapath.vcd
# Genera reportes/datapath-1/figuras/tb-datapath-salida.png
# Tras el volcado, recortar con:
#   python3 reportes/datapath-1/capturas/recortar.py 115 \
#           reportes/datapath-1/figuras/tb-datapath-salida.png
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
gtkwave::setZoomRangeTimes 105000000 170000000
gtkwave::/File/Grab_To_File "reportes/datapath-1/figuras/tb-datapath-salida.png"
gtkwave::/File/Quit
