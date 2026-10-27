-- ============================================================
-- Testbench del mux superior: las 4 selecciones (EXT1, EXT2,
-- RF y realimentación del shifter).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mux_superior is
end entity;

architecture tb of tb_mux_superior is
    component mux_superior is
        port (
            sel_sup : in  std_logic_vector(1 downto 0);
            ext1    : in  std_logic_vector(7 downto 0);
            ext2    : in  std_logic_vector(7 downto 0);
            rf      : in  std_logic_vector(7 downto 0);
            sh      : in  std_logic_vector(7 downto 0);
            y       : out std_logic_vector(7 downto 0)
        );
    end component;

    signal sel_sup : std_logic_vector(1 downto 0) := (others => '0');
    signal ext1    : std_logic_vector(7 downto 0) := x"11";
    signal ext2    : std_logic_vector(7 downto 0) := x"22";
    signal rf      : std_logic_vector(7 downto 0) := x"33";
    signal sh      : std_logic_vector(7 downto 0) := x"44";
    signal y       : std_logic_vector(7 downto 0);

    procedure comprobar(
        signal sel : out std_logic_vector(1 downto 0);
        signal y_s : in  std_logic_vector(7 downto 0);
        constant s : in natural;
        constant esp : in natural
    ) is
    begin
        sel <= std_logic_vector(to_unsigned(s, 2));
        wait for 10 ns;
        assert y_s = std_logic_vector(to_unsigned(esp, 8))
            report "mux_superior: sel_sup=" & integer'image(s) &
                   " dio " & integer'image(to_integer(unsigned(y_s))) &
                   ", esperaba " & integer'image(esp)
            severity failure;
    end procedure;
begin
    dut : mux_superior port map (
        sel_sup => sel_sup, ext1 => ext1, ext2 => ext2,
        rf => rf, sh => sh, y => y
    );

    stim : process
    begin
        comprobar(sel_sup, y, 0, 16#11#);  -- EXT1
        comprobar(sel_sup, y, 1, 16#22#);  -- EXT2 (reservado)
        comprobar(sel_sup, y, 2, 16#33#);  -- banco de registros
        comprobar(sel_sup, y, 3, 16#44#);  -- shifter (realimentación)
        report "tb_mux_superior: OK" severity note;
        wait;
    end process;
end architecture;
