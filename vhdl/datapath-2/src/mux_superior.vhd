-- ============================================================
-- mux_superior.vhd — Mux de 4 entradas que alimenta el acumulador
--
-- Selecciona la fuente que se carga en el acumulador según sel_sup:
--   00 = ext1    (dato externo 1; carga de constantes y de n/A/B)
--   01 = ext2    (reservado; atado a 0 por el datapath)
--   10 = rf_out  (lectura del banco de registros)
--   11 = sh_out  (realimentación: salida del shifter/ALU calculada)
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux_superior is
  port (
    ext1    : in  unsigned(7 downto 0);
    ext2    : in  unsigned(7 downto 0);
    rf_out  : in  unsigned(7 downto 0);
    sh_out  : in  unsigned(7 downto 0);
    sel_sup : in  unsigned(1 downto 0);
    dout    : out unsigned(7 downto 0)
  );
end entity;

architecture combinacional of mux_superior is
begin
  with sel_sup select
    dout <= ext1   when "00",
            ext2   when "01",
            rf_out when "10",
            sh_out when others;  -- "11"
end architecture;
