-- ============================================================
-- Testbench del detector de cero: cero = 1 sólo cuando el dato
-- es 0x00 (añadido justificado para terminar los bucles).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_detector_cero is
end entity;

architecture tb of tb_detector_cero is
    component detector_cero is
        port (
            d    : in  std_logic_vector(7 downto 0);
            cero : out std_logic
        );
    end component;

    signal d     : std_logic_vector(7 downto 0) := (others => '0');
    signal cero  : std_logic;

    procedure comprobar(
        signal d_s   : out std_logic_vector(7 downto 0);
        signal c_s   : in  std_logic;
        constant v   : in natural;
        constant esp : in std_logic
    ) is
    begin
        d_s <= std_logic_vector(to_unsigned(v, 8));
        wait for 10 ns;
        assert c_s = esp
            report "detector_cero: para " & integer'image(v) &
                   " devolvió " & std_logic'image(c_s)
            severity failure;
    end procedure;
begin
    dut : detector_cero port map (d => d, cero => cero);

    stim : process
    begin
        comprobar(d, cero, 0, '1');
        comprobar(d, cero, 1, '0');
        comprobar(d, cero, 128, '0');
        comprobar(d, cero, 255, '0');
        report "tb_detector_cero: OK" severity note;
        wait;
    end process;
end architecture;
