-- ============================================================
-- mux_inferior.vhd — Mux de 2 entradas que alimenta al shifter
--
-- Elige qué valor entra al shifter:
--   0 = resultado de la ALU
--   1 = bus_acc (salida del acumulador)
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux_inferior is
  port (
    alu_out : in  unsigned(7 downto 0);
    acc_out : in  unsigned(7 downto 0);
    sel_inf : in  std_logic;
    dout    : out unsigned(7 downto 0)
  );
end entity;

architecture combinacional of mux_inferior is
begin
  dout <= acc_out when sel_inf = '1' else alu_out;
end architecture;
