-- ============================================================
-- mux_superior.vhd — Mux de 4 entradas que elige el dato de
-- entrada del camino de datos (operando A de la ALU o fuente
-- directa hacia el banco)
--
-- Selecciona la fuente según sel_sup:
--   00 = ext1   (dato externo 1; carga de constantes y de n/A/B)
--   01 = ext2   (reservado; atado a 0 por el datapath)
--   10 = rf_a   (lectura A del banco: operando/destino)
--   11 = rf_b   (lectura B del banco: segundo operando o copia)
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux_superior is
  port (
    ext1    : in  unsigned(7 downto 0);
    ext2    : in  unsigned(7 downto 0);
    rf_a    : in  unsigned(7 downto 0);
    rf_b    : in  unsigned(7 downto 0);
    sel_sup : in  unsigned(1 downto 0);
    dout    : out unsigned(7 downto 0)
  );
end entity;

architecture combinacional of mux_superior is
begin
  with sel_sup select
    dout <= ext1 when "00",
            ext2 when "01",
            rf_a when "10",
            rf_b when others;  -- "11"
end architecture;
