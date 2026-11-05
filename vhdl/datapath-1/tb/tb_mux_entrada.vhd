-- ============================================================
-- Testbench del MUX de entrada: constante 0 con sel = '0',
-- dato externo con sel = '1', y comprobación del genérico
-- ANCHO (instancia de 8 bits y otra de 4 bits).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_mux_entrada is
end entity;

architecture tb of tb_mux_entrada is
    component mux_entrada is
        generic (
            ANCHO : natural := 8
        );
        port (
            dato_ext : in  std_logic_vector(ANCHO - 1 downto 0);
            sel      : in  std_logic;
            y        : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    signal dato8 : std_logic_vector(7 downto 0) := (others => '0');
    signal sel8  : std_logic := '0';
    signal y8    : std_logic_vector(7 downto 0);

    signal dato4 : std_logic_vector(3 downto 0) := (others => '0');
    signal sel4  : std_logic := '0';
    signal y4    : std_logic_vector(3 downto 0);
begin
    dut8 : mux_entrada
        generic map (ANCHO => 8)
        port map (dato_ext => dato8, sel => sel8, y => y8);

    dut4 : mux_entrada
        generic map (ANCHO => 4)
        port map (dato_ext => dato4, sel => sel4, y => y4);

    stim : process
    begin
        -- sel = '0' => constante 0, ignorando el dato externo
        dato8 <= x"3C";
        sel8  <= '0';
        wait for 10 ns;
        assert y8 = x"00"
            report "mux_entrada: con sel=0 no elige la constante 0"
            severity failure;

        -- sel = '1' => pasa el dato externo
        sel8 <= '1';
        wait for 10 ns;
        assert y8 = x"3C"
            report "mux_entrada: con sel=1 no elige el dato externo"
            severity failure;

        -- sigue el dato externo cuando cambia
        dato8 <= x"A5";
        wait for 10 ns;
        assert y8 = x"A5"
            report "mux_entrada: no sigue los cambios del dato externo"
            severity failure;

        -- vuelve a la constante 0
        sel8 <= '0';
        wait for 10 ns;
        assert y8 = x"00"
            report "mux_entrada: con sel=0 no vuelve a la constante 0"
            severity failure;

        -- genérico ANCHO = 4
        dato4 <= "1010";
        sel4  <= '1';
        wait for 10 ns;
        assert y4 = "1010"
            report "mux_entrada (ANCHO=4): con sel=1 no elige el dato externo"
            severity failure;

        sel4 <= '0';
        wait for 10 ns;
        assert y4 = "0000"
            report "mux_entrada (ANCHO=4): con sel=0 no elige la constante 0"
            severity failure;

        report "tb_mux_entrada: OK" severity note;
        wait;
    end process;
end architecture;
