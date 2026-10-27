-- ============================================================
-- Testbench del registro: reset síncrono, carga con l = '1',
-- retención con l = '0' y prioridad de rst sobre l.
-- El clk se genera dentro del proceso estimulador (patrón de
-- datapath-3) para que la simulación termine sola.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_registro is
end entity;

architecture tb of tb_registro is
    component registro is
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
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal l   : std_logic := '0';
    signal d   : std_logic_vector(7 downto 0) := (others => '0');
    signal q   : std_logic_vector(7 downto 0);
begin
    dut : registro port map (
        clk => clk, rst => rst, l => l, d => d, q => q
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
        -- reset síncrono
        rst <= '1';
        l   <= '0';
        tick;
        assert q = x"00"
            report "registro: rst no limpia el registro" severity failure;
        rst <= '0';

        -- carga con l = '1'
        d <= x"5A";
        l <= '1';
        tick;
        assert q = x"5A"
            report "registro: l no carga el dato" severity failure;

        -- retención con l = '0'
        l <= '0';
        d <= x"FF";
        tick;
        assert q = x"5A"
            report "registro: no retiene el dato con l = 0" severity failure;

        -- nueva carga
        d <= x"C3";
        l <= '1';
        tick;
        assert q = x"C3"
            report "registro: segunda carga no funciona" severity failure;

        -- rst con prioridad sobre l
        rst <= '1';
        l   <= '1';
        d   <= x"77";
        tick;
        assert q = x"00"
            report "registro: rst no tiene prioridad sobre l" severity failure;

        report "tb_registro: OK" severity note;
        wait;
    end process;
end architecture;
