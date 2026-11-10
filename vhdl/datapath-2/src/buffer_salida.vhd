-- ============================================================
-- buffer_salida.vhd — Buffer de salida con habilitación
--
-- Saca al puerto externo la lectura A del banco (rf_a) cuando
-- en = '1'. Se modela como buffer simple: el datapath-2 usa una
-- señal 'dato_out' compartida y el control la habilita (out_en)
-- únicamente en el microciclo final de cada algoritmo, con 'addr'
-- apuntando al registro que contiene el resultado.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity buffer_salida is
  port (
    d       : in  unsigned(7 downto 0);   -- lectura A del banco (rf_a)
    en      : in  std_logic;              -- habilitación
    dato_out : out unsigned(7 downto 0)
  );
end entity;

architecture combinacional of buffer_salida is
begin
  dato_out <= d when en = '1' else (others => '0');
end architecture;
