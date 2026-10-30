-- ============================================================
-- tb_buffer_salida.vhd — Banco de prueba del buffer de salida
--
-- Comprueba que con en = 1 pasa el dato y con en = 0 da 0.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_buffer_salida is
end entity;

architecture tb of tb_buffer_salida is
  signal d        : unsigned(7 downto 0) := to_unsigned(123, 8);
  signal en       : std_logic := '0';
  signal dato_out : unsigned(7 downto 0);
begin
  dut : entity work.buffer_salida
    port map (d => d, en => en, dato_out => dato_out);

  process
  begin
    en <= '1';
    wait for 1 ns;
    assert dato_out = to_unsigned(123, 8)
      report "buffer_salida: en=1 debe pasar el dato" severity failure;

    en <= '0';
    wait for 1 ns;
    assert dato_out = to_unsigned(0, 8)
      report "buffer_salida: en=0 debe dar 0" severity failure;

    report "tb_buffer_salida: OK - habilitado y deshabilitado";
    finish;
  end process;
end architecture;
