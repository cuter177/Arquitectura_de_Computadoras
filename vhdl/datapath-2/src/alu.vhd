-- ============================================================
-- alu.vhd — Unidad aritmético-lógica de 8 bits del datapath-2
--
-- Ocho operaciones seleccionadas por los bits A2 A1 A0 (op_alu),
-- según la tabla oficial de la asignatura:
--   000 pasar A      001 A + B       010 A - B       011 A + 1
--   100 A - 1        101 A OR B      110 A AND B     111 NOT A
--
-- Aritmética módulo 256 (8 bits, sin bit de acarreo a la salida).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
  port (
    a      : in  unsigned(7 downto 0);   -- operando A (acumulador)
    b      : in  unsigned(7 downto 0);   -- operando B (banco de registros)
    op_alu : in  unsigned(2 downto 0);   -- selector de operación A2 A1 A0
    f      : out unsigned(7 downto 0)    -- resultado
  );
end entity;

architecture combinacional of alu is
begin
  with op_alu select
    f <= a                 when "000",  -- pasar A
         a + b             when "001",  -- suma
         a - b             when "010",  -- resta
         a + 1             when "011",  -- incremento
         a - 1             when "100",  -- decremento
         a or b            when "101",  -- OR
         a and b           when "110",  -- AND
         not a             when others;  -- NOT (111)
end architecture;
