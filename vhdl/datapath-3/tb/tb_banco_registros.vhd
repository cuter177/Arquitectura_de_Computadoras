-- ============================================================
-- Testbench del banco de registros: reset global, escritura en
-- varios registros, lectura combinacional y retención.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_banco_registros is
end entity;

architecture tb of tb_banco_registros is
    component banco_registros is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            addr  : in  std_logic_vector(2 downto 0);
            wr    : in  std_logic;
            d_in  : in  std_logic_vector(7 downto 0);
            d_out : out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal addr  : std_logic_vector(2 downto 0) := (others => '0');
    signal wr    : std_logic := '0';
    signal d_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal d_out : std_logic_vector(7 downto 0);
begin
    dut : banco_registros port map (
        clk => clk, rst => rst, addr => addr, wr => wr,
        d_in => d_in, d_out => d_out
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure escribir(constant a : in natural; constant v : in natural) is
        begin
            addr <= std_logic_vector(to_unsigned(a, 3));
            d_in <= std_logic_vector(to_unsigned(v, 8));
            wr   <= '1';
            tick;
            wr   <= '0';
        end procedure;

        procedure leer_y_comprobar(constant a : in natural; constant v : in natural) is
        begin
            addr <= std_logic_vector(to_unsigned(a, 3));
            wait for 10 ns;
            assert d_out = std_logic_vector(to_unsigned(v, 8))
                report "banco: R" & integer'image(a) &
                       " = " & integer'image(to_integer(unsigned(d_out))) &
                       ", esperaba " & integer'image(v)
                severity failure;
        end procedure;
    begin
        -- reset: todos los registros en 0
        rst <= '1';
        tick;
        tick;
        rst <= '0';
        for i in 0 to 7 loop
            leer_y_comprobar(i, 0);
        end loop;

        -- escrituras
        escribir(0, 16#11#);
        escribir(3, 16#33#);
        escribir(7, 16#77#);

        -- lecturas
        leer_y_comprobar(0, 16#11#);
        leer_y_comprobar(3, 16#33#);
        leer_y_comprobar(7, 16#77#);
        leer_y_comprobar(1, 0);   -- sin escribir sigue a 0
        leer_y_comprobar(5, 0);

        -- sin wr no escribe
        addr <= "001";
        d_in <= x"FF";
        wr   <= '0';
        tick;
        leer_y_comprobar(1, 0);

        report "tb_banco_registros: OK" severity note;
        wait;
    end process;
end architecture;
