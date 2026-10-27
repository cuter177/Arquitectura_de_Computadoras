-- ============================================================
-- Registro de datos del Datapath 1
-- Almacena n (operando B de la ALU) y lo realimenta a la ALU.
-- Carga habilitada con l: nombre provisional «L» de la foto
-- (no se distinguió con absoluta certeza; mi lectura inicial
-- fue «W»). rst es decisión de diseño adicional: no aparece en
-- la foto y se añade para inicializar B = 0 (necesario para
-- cargar dato_ext con op = 000). Reset síncrono con prioridad
-- sobre l, igual que el acumulador de datapath-3.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity registro is
    generic (
        ANCHO : natural := 8
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        l   : in  std_logic;
        d   : in  std_logic_vector(ANCHO - 1 downto 0);
        q   : out std_logic_vector(ANCHO - 1 downto 0)
    );
end entity;

architecture comportamental of registro is
    signal contenido : std_logic_vector(ANCHO - 1 downto 0) := (others => '0');
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                contenido <= (others => '0');
            elsif l = '1' then
                contenido <= d;
            end if;
        end if;
    end process;

    q <= contenido;
end architecture;
