-- ============================================================
-- Banco de registros del Datapath 3
-- 8 registros de 8 bits. Lectura combinacional en "addr";
-- escritura síncrona de bus_acc en RF[addr] cuando wr = '1'
-- (un solo puerto: en cada ciclo se lee y escribe la misma
-- dirección, como en el diagrama de la asignatura).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity banco_registros is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        addr   : in  std_logic_vector(2 downto 0);
        wr     : in  std_logic;
        d_in   : in  std_logic_vector(7 downto 0);
        d_out  : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of banco_registros is
    type banco_t is array (0 to 7) of std_logic_vector(7 downto 0);
    signal regs : banco_t := (others => (others => '0'));
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                regs <= (others => (others => '0'));
            elsif wr = '1' then
                regs(to_integer(unsigned(addr))) <= d_in;
            end if;
        end if;
    end process;

    d_out <= regs(to_integer(unsigned(addr)));
end architecture;
