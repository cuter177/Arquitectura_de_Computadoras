# ============================================================
# Captura de ondas de tb_alu para ANCHO=4 (215–250 ns): las
# tres operaciones en 4 bits, donde 9<<1=2 (9*2=18 mod 16)
# y 15+1=0 (256->16) ilustran la aritmética modular.
# Ejecutar DESDE LA RAÍZ:
#   gtkwave -r reportes/datapath-1/capturas/gtkwave.rc \
#           -S reportes/datapath-1/capturas/tb-alu-ancho4.tcl \
#           vhdl/datapath-1/salidas/tb_alu.vcd
# Genera reportes/datapath-1/figuras/tb-alu-ancho4.png
# Tras el volcado, recortar con:
#   python3 reportes/datapath-1/capturas/recortar.py 115 \
#           reportes/datapath-1/figuras/tb-alu-ancho4.png
# ============================================================
gtkwave::addSignalsFromList {
tb_alu.c[2:0]
tb_alu.a8[7:0]
tb_alu.b8[7:0]
tb_alu.f8[7:0]
tb_alu.a4[3:0]
tb_alu.b4[3:0]
tb_alu.f4[3:0]
}
gtkwave::/View/Left_Justified_Signals
gtkwave::/View/Use_Black_and_White
gtkwave::/Edit/Highlight_All
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/UnHighlight_All
gtkwave::highlightSignalsFromList {tb_alu.c[2:0]}
gtkwave::/Edit/Data_Format/Binary
gtkwave::/Edit/UnHighlight_All
gtkwave::/Time/Zoom/Zoom_Best_Fit
after 1500
gtkwave::setZoomRangeTimes 215000000 250000000
gtkwave::/File/Grab_To_File "reportes/datapath-1/figuras/tb-alu-ancho4.png"
gtkwave::/File/Quit
