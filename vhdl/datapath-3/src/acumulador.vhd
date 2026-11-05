-- ============================================================
-- Acumulador del Datapath 3
-- Registro de 8 bits con escritura (wr) y limpieza síncrona
-- (clear, con prioridad sobre wr) más reset global. Almacena
-- operandos y resultados parciales; su salida es el bus_acc.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity acumulador is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        wr    : in  std_logic;
        clear : in  std_logic;
        d_in  : in  std_logic_vector(7 downto 0);
        q     : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of acumulador is
    signal registro : std_logic_vector(7 downto 0) := (others => '0');
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                registro <= (others => '0');
            elsif clear = '1' then
                registro <= (others => '0');
            elsif wr = '1' then
                registro <= d_in;
            end if;
        end if;
    end process;

    q <= registro;
end architecture;
