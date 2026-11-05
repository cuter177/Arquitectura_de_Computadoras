-- ============================================================
-- tb_detector_cero.vhd — Banco de prueba del detector de cero
--
-- Comprueba 0 -> 1, 1 -> 0 y 255 -> 0.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_detector_cero is
end entity;

architecture tb of tb_detector_cero is
  signal d    : unsigned(7 downto 0) := (others => '0');
  signal cero : std_logic;
begin
  dut : entity work.detector_cero
    port map (d => d, cero => cero);

  process
  begin
    d <= to_unsigned(0, 8);
    wait for 1 ns;
    assert cero = '1' report "detector_cero: 0 debe dar 1" severity failure;

    d <= to_unsigned(1, 8);
    wait for 1 ns;
    assert cero = '0' report "detector_cero: 1 debe dar 0" severity failure;

    d <= to_unsigned(255, 8);
    wait for 1 ns;
    assert cero = '0' report "detector_cero: 255 debe dar 0" severity failure;

    report "tb_detector_cero: OK - 0, 1 y 255 verificados";
    finish;
  end process;
end architecture;
