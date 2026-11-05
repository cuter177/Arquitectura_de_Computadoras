-- ============================================================
-- tb_alu.vhd — Banco de prueba de la ALU (autochequeo)
--
-- Comprueba las 8 operaciones con a = 5 y b = 3:
--   000 pasar A = 5       001 suma = 8         010 resta = 2
--   011 inc   = 6         100 dec  = 4         101 OR = 7
--   110 AND   = 1         111 NOT A = 250 (0xF6)
-- Aritmética módulo 256.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_alu is
end entity;

architecture tb of tb_alu is
  signal a      : unsigned(7 downto 0) := (others => '0');
  signal b      : unsigned(7 downto 0) := (others => '0');
  signal op_alu : unsigned(2 downto 0) := "000";
  signal f      : unsigned(7 downto 0);
begin
  dut : entity work.alu
    port map (a => a, b => b, op_alu => op_alu, f => f);

  process
    procedure probar(constant op    : in unsigned(2 downto 0);
                     constant esp   : in unsigned(7 downto 0)) is
    begin
      op_alu <= op;
      wait for 1 ns;
      assert f = esp
        report "ALU op=" & integer'image(to_integer(op)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(f))
        severity failure;
    end procedure;
  begin
    a <= to_unsigned(5, 8);
    b <= to_unsigned(3, 8);

    probar("000", to_unsigned(5, 8));    -- pasar A
    probar("001", to_unsigned(8, 8));    -- A + B
    probar("010", to_unsigned(2, 8));    -- A - B
    probar("011", to_unsigned(6, 8));    -- A + 1
    probar("100", to_unsigned(4, 8));    -- A - 1
    probar("101", to_unsigned(7, 8));    -- A OR B
    probar("110", to_unsigned(1, 8));    -- A AND B
    probar("111", to_unsigned(250, 8));  -- NOT A

    -- Casos límite: desbordamiento del módulo 256
    a <= to_unsigned(255, 8);
    b <= to_unsigned(1, 8);
    probar("001", to_unsigned(0, 8));    -- 255 + 1 = 0 (módulo 256)
    probar("011", to_unsigned(0, 8));    -- 255 + 1 = 0
    a <= to_unsigned(0, 8);
    probar("100", to_unsigned(255, 8));  -- 0 - 1 = 255 (módulo 256)

    report "tb_alu: OK - 8 operaciones y casos límite verificados";
    finish;
  end process;
end architecture;
