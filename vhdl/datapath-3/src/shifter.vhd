-- ============================================================
-- Shifter del Datapath 3
-- Desplazamiento de 1 bit sobre el dato de entrada. Su salida
-- realimenta al mux superior (camino obligatorio del resultado
-- hacia el acumulador), por lo que el modo "pasar" (sh = 00)
-- es imprescindible.
-- sh = 00: pasar (idéntico)        -- IMPRESCINDIBLE (confirmado en uso)
-- sh = 01: desplazamiento izquierda, rellena con 0   -- PROVISIONAL
-- sh = 10: desplazamiento derecha lógico, rellena 0  -- PROVISIONAL
-- sh = 11: desplazamiento derecha aritmético         -- PROVISIONAL
-- Los códigos 01/10/11 son provisionales: el diagrama de la
-- asignatura no documenta dirección ni códigos del shifter;
-- los 4 experimentos solo usan sh = 00.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity shifter is
    port (
        d_in  : in  std_logic_vector(7 downto 0);
        sh    : in  std_logic_vector(1 downto 0);
        d_out : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of shifter is
begin
    with sh select d_out <=
        d_in                            when "00",  -- pasar
        d_in(6 downto 0) & '0'          when "01",  -- << 1 (provisional)
        '0' & d_in(7 downto 1)          when "10",  -- >> 1 lógico (provisional)
        d_in(7) & d_in(7 downto 1)      when others; -- >> 1 aritmético (provisional)
end architecture;
