-- ============================================================
-- Mux inferior del Datapath 3 (2 -> 1)
-- Selecciona qué dato entra al shifter.
-- sel_inf: 0 = salida de la ALU, 1 = bus_acc (acumulador).
-- Códigos simbólicos: confirmar con el diagrama oficial.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity mux_inferior is
    port (
        sel_inf : in  std_logic;
        alu_f   : in  std_logic_vector(7 downto 0);
        acc     : in  std_logic_vector(7 downto 0);
        y       : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of mux_inferior is
begin
    with sel_inf select y <=
        alu_f when '0',
        acc   when others;
end architecture;
