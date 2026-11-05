-- ============================================================
-- Testbench del buffer de salida: con en = '1' pasa el dato y
-- con en = '0' la salida queda en alta impedancia (tri-estado).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_buffer_salida is
end entity;

architecture tb of tb_buffer_salida is
    component buffer_salida is
        port (
            d_in : in  std_logic_vector(7 downto 0);
            en   : in  std_logic;
            y    : out std_logic_vector(7 downto 0)
        );
    end component;

    signal d_in : std_logic_vector(7 downto 0) := x"5A";
    signal en   : std_logic := '0';
    signal y    : std_logic_vector(7 downto 0);
begin
    dut : buffer_salida port map (d_in => d_in, en => en, y => y);

    stim : process
    begin
        en <= '0';
        wait for 10 ns;
        assert y = "ZZZZZZZZ"
            report "buffer_salida: con en=0 no queda en alta impedancia"
            severity failure;

        en <= '1';
        wait for 10 ns;
        assert y = x"5A"
            report "buffer_salida: con en=1 no pasa el dato" severity failure;

        d_in <= x"C3";
        wait for 10 ns;
        assert y = x"C3"
            report "buffer_salida: no sigue el dato de entrada" severity failure;

        report "tb_buffer_salida: OK" severity note;
        wait;
    end process;
end architecture;
