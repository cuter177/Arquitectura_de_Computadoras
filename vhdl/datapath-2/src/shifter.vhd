-- ============================================================
-- shifter.vhd — Desplazador de 8 bits del datapath-2
--
-- Códigos de sh (2 bits):
--   00 = pasar         (identidad: imprescindible, camino de realimentación)
--   01 = desplazar izq. 1 bit  (entra 0 por la derecha)
--   10 = desplazar der. lógico 1 bit  (entra 0 por la izquierda)
--   11 = desplazar der. aritmético 1 bit (entra el bit de signo)
--
-- En los tres experimentos del datapath-2 sólo se usa el modo pasar;
-- los demás códigos son provisionales (ver docs/plan-datapath-3.md, §4.4).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter is
  port (
    d     : in  unsigned(7 downto 0);
    sh    : in  unsigned(1 downto 0);
    dout  : out unsigned(7 downto 0)
  );
end entity;

architecture combinacional of shifter is
begin
  with sh select
    dout <= d                              when "00",  -- pasar
            shift_left(d, 1)               when "01",  -- izquierda lógica
            shift_right(d, 1)              when "10",  -- derecha lógica
            unsigned(shift_right(signed(d), 1)) when others; -- der. aritmética
end architecture;
