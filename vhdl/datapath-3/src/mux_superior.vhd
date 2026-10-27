-- ============================================================
-- Mux superior del Datapath 3 (4 -> 1)
-- Elige el dato que se carga en el acumulador.
-- sel_sup: 00 = EXT1 (dato externo), 01 = EXT2 (reservado),
--          10 = salida del banco de registros,
--          11 = realimentación del shifter.
-- Códigos simbólicos: confirmar con el diagrama oficial.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity mux_superior is
    port (
        sel_sup : in  std_logic_vector(1 downto 0);
        ext1    : in  std_logic_vector(7 downto 0);
        ext2    : in  std_logic_vector(7 downto 0);
        rf      : in  std_logic_vector(7 downto 0);
        sh      : in  std_logic_vector(7 downto 0);
        y       : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of mux_superior is
begin
    with sel_sup select y <=
        ext1 when "00",
        ext2 when "01",
        rf   when "10",
        sh   when others;
end architecture;
