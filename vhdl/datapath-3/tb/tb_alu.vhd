-- ============================================================
-- Testbench de la ALU: verifica las 8 operaciones con a=5, b=3,
-- incluyendo que "pasar A" (000) devuelve A y no cero.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu is
end entity;

architecture tb of tb_alu is
    component alu is
        port (
            a  : in  std_logic_vector(7 downto 0);
            b  : in  std_logic_vector(7 downto 0);
            op : in  std_logic_vector(2 downto 0);
            f  : out std_logic_vector(7 downto 0)
        );
    end component;

    signal a  : std_logic_vector(7 downto 0) := (others => '0');
    signal b  : std_logic_vector(7 downto 0) := (others => '0');
    signal op : std_logic_vector(2 downto 0) := (others => '0');
    signal f  : std_logic_vector(7 downto 0);

    procedure comprobar(
        signal a_s    : out std_logic_vector(7 downto 0);
        signal b_s    : out std_logic_vector(7 downto 0);
        signal op_s   : out std_logic_vector(2 downto 0);
        signal f_s    : in  std_logic_vector(7 downto 0);
        constant av   : in  natural;
        constant bv   : in  natural;
        constant opv  : in  natural;
        constant esp  : in  natural
    ) is
    begin
        a_s  <= std_logic_vector(to_unsigned(av, 8));
        b_s  <= std_logic_vector(to_unsigned(bv, 8));
        op_s <= std_logic_vector(to_unsigned(opv, 3));
        wait for 10 ns;
        assert f_s = std_logic_vector(to_unsigned(esp, 8))
            report "alu: a=" & integer'image(av) &
                   " b=" & integer'image(bv) &
                   " op=" & integer'image(opv) &
                   " dio " & integer'image(to_integer(unsigned(f_s))) &
                   ", esperaba " & integer'image(esp)
            severity failure;
    end procedure;
begin
    dut : alu port map (a => a, b => b, op => op, f => f);

    stim : process
    begin
        comprobar(a, b, op, f, 5, 3, 0, 5);    -- Pasar A (no es cero)
        comprobar(a, b, op, f, 5, 3, 1, 8);    -- A + B
        comprobar(a, b, op, f, 5, 3, 2, 2);    -- A - B
        comprobar(a, b, op, f, 5, 3, 3, 6);    -- A + 1
        comprobar(a, b, op, f, 5, 3, 4, 4);    -- A - 1
        comprobar(a, b, op, f, 5, 3, 5, 7);    -- A OR B
        comprobar(a, b, op, f, 5, 3, 6, 1);    -- A AND B
        comprobar(a, b, op, f, 5, 3, 7, 250);  -- NOT A
        -- desbordamiento silencioso documentado (módulo 256)
        comprobar(a, b, op, f, 255, 1, 1, 0);
        report "tb_alu: OK" severity note;
        wait;
    end process;
end architecture;
