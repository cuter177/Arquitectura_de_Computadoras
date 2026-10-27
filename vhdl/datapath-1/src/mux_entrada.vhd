-- ============================================================
-- MUX de entrada del Datapath 1 (2 -> 1)
-- Elige el operando A de la ALU: constante 0 (sel = '0') o el
-- valor externo dato_ext (sel = '1').
-- sel: decisión de diseño provisional (polaridad modificable).
-- dato_ext: nombre provisional (el de la foto no se pudo leer).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity mux_entrada is
    generic (
        ANCHO : natural := 8
    );
    port (
        dato_ext : in  std_logic_vector(ANCHO - 1 downto 0);
        sel      : in  std_logic;
        y        : out std_logic_vector(ANCHO - 1 downto 0)
    );
end entity;

architecture comportamental of mux_entrada is
begin
    y <= dato_ext when sel = '1' else (others => '0');
end architecture;
