-- ============================================================
-- Testbench del shifter: el modo pasar (sh = 00) es el que usan
-- los 4 experimentos (imprescindible); los otros 3 códigos son
-- provisionales y se comprueban para fijar el comportamiento.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_shifter is
end entity;

architecture tb of tb_shifter is
    component shifter is
        port (
            d_in  : in  std_logic_vector(7 downto 0);
            sh    : in  std_logic_vector(1 downto 0);
            d_out : out std_logic_vector(7 downto 0)
        );
    end component;

    signal d_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal sh    : std_logic_vector(1 downto 0) := (others => '0');
    signal d_out : std_logic_vector(7 downto 0);

    procedure comprobar(
        signal d_s   : out std_logic_vector(7 downto 0);
        signal sh_s  : out std_logic_vector(1 downto 0);
        signal out_s : in  std_logic_vector(7 downto 0);
        constant d   : in std_logic_vector(7 downto 0);
        constant sv  : in natural;
        constant esp : in std_logic_vector(7 downto 0)
    ) is
    begin
        d_s <= d;
        sh_s <= std_logic_vector(to_unsigned(sv, 2));
        wait for 10 ns;
        assert out_s = esp
            report "shifter: sh=" & integer'image(sv) &
                   " dio un valor inesperado"
            severity failure;
    end procedure;
begin
    dut : shifter port map (d_in => d_in, sh => sh, d_out => d_out);

    stim : process
    begin
        -- paso idéntico (los experimentos usan siempre este modo)
        comprobar(d_in, sh, d_out, x"A5", 0, x"A5");
        comprobar(d_in, sh, d_out, x"00", 0, x"00");
        comprobar(d_in, sh, d_out, x"FF", 0, x"FF");
        -- códigos provisionales
        comprobar(d_in, sh, d_out, x"81", 1, x"02");  -- << 1
        comprobar(d_in, sh, d_out, x"81", 2, x"40");  -- >> 1 lógico
        comprobar(d_in, sh, d_out, x"81", 3, x"C0");  -- >> 1 aritmético
        report "tb_shifter: OK" severity note;
        wait;
    end process;
end architecture;
