-- ============================================================
-- tb_mux_superior.vhd — Banco de prueba del mux superior
--
-- Comprueba los 4 códigos de selección.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mux_superior is
end entity;

architecture tb of tb_mux_superior is
  signal ext1    : unsigned(7 downto 0) := to_unsigned(10, 8);
  signal ext2    : unsigned(7 downto 0) := to_unsigned(20, 8);
  signal rf_out  : unsigned(7 downto 0) := to_unsigned(30, 8);
  signal sh_out  : unsigned(7 downto 0) := to_unsigned(40, 8);
  signal sel_sup : unsigned(1 downto 0) := "00";
  signal dout    : unsigned(7 downto 0);
begin
  dut : entity work.mux_superior
    port map (ext1 => ext1, ext2 => ext2, rf_out => rf_out, sh_out => sh_out,
              sel_sup => sel_sup, dout => dout);

  process
    procedure probar(constant sel : in unsigned(1 downto 0);
                     constant esp : in unsigned(7 downto 0)) is
    begin
      sel_sup <= sel;
      wait for 1 ns;
      assert dout = esp
        report "mux_superior sel=" & integer'image(to_integer(sel)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dout))
        severity failure;
    end procedure;
  begin
    probar("00", to_unsigned(10, 8));  -- ext1
    probar("01", to_unsigned(20, 8));  -- ext2
    probar("10", to_unsigned(30, 8));  -- rf_out
    probar("11", to_unsigned(40, 8));  -- sh_out

    report "tb_mux_superior: OK - los 4 códigos verificados";
    finish;
  end process;
end architecture;
