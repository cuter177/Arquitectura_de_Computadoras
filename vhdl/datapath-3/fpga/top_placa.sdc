# ============================================================
# Restricciones de tiempos de datapath-3 en la DE10-Standard
#
# Sin este fichero el TimeQuest no tiene periodo de reloj y analiza
# el diseño como si fuera a 1 GHz (slack negativo artificial).
# ============================================================

# CLOCK_50: 50 MHz -> 20 ns
create_clock -name clk -period 20.000 [get_ports {clk}]

# incertidumbre de reloj (jitter, etc.)
derive_clock_uncertainty

# Las entradas (KEY, SW) las acciona una persona y las salidas
# (LEDR, HEX) se miran a ojo: no necesitan set_input_delay ni
# set_output_delay, porque no hay ningún protocolo síncrono en los
# pines. Solo se restringe el reloj.
