-- ============================================================
-- Testbench del mux inferior: selección entre la salida de la
-- ALU (0) y el bus del acumulador (1).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mux_inferior is
end entity;

architecture tb of tb_mux_inferior is
    component mux_inferior is
        port (
            sel_inf : in  std_logic;
            alu_f   : in  std_logic_vector(7 downto 0);
            acc     : in  std_logic_vector(7 downto 0);
            y       : out std_logic_vector(7 downto 0)
        );
    end component;

    signal sel_inf : std_logic := '0';
    signal alu_f   : std_logic_vector(7 downto 0) := x"AA";
    signal acc     : std_logic_vector(7 downto 0) := x"55";
    signal y       : std_logic_vector(7 downto 0);
begin
    dut : mux_inferior port map (
        sel_inf => sel_inf, alu_f => alu_f, acc => acc, y => y
    );

    stim : process
    begin
        sel_inf <= '0';
        wait for 10 ns;
        assert y = x"AA"
            report "mux_inferior: sel_inf=0 no elige la ALU" severity failure;

        sel_inf <= '1';
        wait for 10 ns;
        assert y = x"55"
            report "mux_inferior: sel_inf=1 no elige el acumulador" severity failure;

        report "tb_mux_inferior: OK" severity note;
        wait;
    end process;
end architecture;
