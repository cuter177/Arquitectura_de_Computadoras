-- ============================================================
-- Buffer de salida del Datapath 3
-- Triángulo inferior izquierdo del diagrama: saca bus_acc al
-- puerto dato_out cuando está habilitado (en = '1'); en caso
-- contrario la salida queda en alta impedancia (tri-estado).
-- Interpretación provisional: si el diagrama oficial es un
-- buffer simple (sin habilitación), basta en = '1' siempre.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity buffer_salida is
    port (
        d_in : in  std_logic_vector(7 downto 0);
        en   : in  std_logic;
        y    : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of buffer_salida is
begin
    y <= d_in when en = '1' else (others => 'Z');
end architecture;
