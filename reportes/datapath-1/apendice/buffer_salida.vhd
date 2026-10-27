-- =======================================================
-- Buffer tri-estado de salida del Datapath 1
-- Etiqueta del esquema del curso: «O.E.» (Output Enable).
-- oe = '1' saca el dato; oe = '0' deja la salida en alta
-- impedancia. Nombre del puerto: decisión de diseño (el
-- esquema solo muestra la etiqueta O.E.).
-- =======================================================
library ieee;
use ieee.std_logic_1164.all;

entity buffer_salida is
    generic (
        ANCHO : natural := 8
    );
    port (
        d_in : in  std_logic_vector(ANCHO - 1 downto 0);
        oe   : in  std_logic;
        y    : out std_logic_vector(ANCHO - 1 downto 0)
    );
end entity;

architecture comportamental of buffer_salida is
begin
    y <= d_in when oe = '1' else (others => 'Z');
end architecture;
