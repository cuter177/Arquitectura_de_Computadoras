-- ============================================================
-- Testbench del acumulador: reset, carga con wr, retención con
-- wr = 0 y prioridad de clear sobre wr.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_acumulador is
end entity;

architecture tb of tb_acumulador is
    component acumulador is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            wr    : in  std_logic;
            clear : in  std_logic;
            d_in  : in  std_logic_vector(7 downto 0);
            q     : out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal wr    : std_logic := '0';
    signal clear : std_logic := '0';
    signal d_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal q     : std_logic_vector(7 downto 0);
begin
    dut : acumulador port map (
        clk => clk, rst => rst, wr => wr, clear => clear,
        d_in => d_in, q => q
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;
    begin
        -- reset
        rst <= '1';
        tick;
        tick;
        assert q = x"00"
            report "acumulador: rst no limpia el registro" severity failure;
        rst <= '0';

        -- carga con wr
        d_in <= x"3C";
        wr   <= '1';
        tick;
        assert q = x"3C"
            report "acumulador: wr no carga el dato" severity failure;

        -- retención con wr = '0'
        wr   <= '0';
        d_in <= x"FF";
        tick;
        assert q = x"3C"
            report "acumulador: no retiene el dato con wr = 0" severity failure;

        -- clear con prioridad sobre wr
        wr    <= '1';
        clear <= '1';
        d_in  <= x"AA";
        tick;
        assert q = x"00"
            report "acumulador: clear no tiene prioridad sobre wr" severity failure;

        -- clear solo
        wr    <= '0';
        clear <= '1';
        tick;
        assert q = x"00"
            report "acumulador: clear solo no limpia" severity failure;

        report "tb_acumulador: OK" severity note;
        wait;
    end process;
end architecture;
