-- ============================================================
-- tb_mux_inferior.vhd — Banco de prueba del mux inferior
--
-- Comprueba los 2 códigos de selección.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mux_inferior is
end entity;

architecture tb of tb_mux_inferior is
  signal alu_out : unsigned(7 downto 0) := to_unsigned(55, 8);
  signal acc_out : unsigned(7 downto 0) := to_unsigned(66, 8);
  signal sel_inf : std_logic := '0';
  signal dout    : unsigned(7 downto 0);
begin
  dut : entity work.mux_inferior
    port map (alu_out => alu_out, acc_out => acc_out, sel_inf => sel_inf,
              dout => dout);

  process
  begin
    sel_inf <= '0';
    wait for 1 ns;
    assert dout = alu_out report "mux_inferior sel=0 debe dar la ALU"
      severity failure;

    sel_inf <= '1';
    wait for 1 ns;
    assert dout = acc_out report "mux_inferior sel=1 debe dar bus_acc"
      severity failure;

    report "tb_mux_inferior: OK - 2 códigos verificados";
    finish;
  end process;
end architecture;
