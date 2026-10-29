-- ============================================================
-- acumulador.vhd — Registro acumulador de 8 bits del datapath-2
--
-- Registro con carga (wr) y borrado (clear) síncronos.
-- 'clear' tiene prioridad sobre 'wr': si ambos están activos en
-- el flanco, el acumulador se pone a cero.
-- 'rst' asíncrono lo pone a cero.
-- La salida q es la fuente de datos del datapath ("bus del acumulador").
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity acumulador is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    d     : in  unsigned(7 downto 0);  -- dato de entrada
    wr    : in  std_logic;             -- carga en el flanco
    clear : in  std_logic;             -- borrado (prioridad sobre wr)
    q     : out unsigned(7 downto 0)   -- valor retenido
  );
end entity;

architecture rtl of acumulador is
  signal q_r : unsigned(7 downto 0) := (others => '0');
begin
  q <= q_r;

  process(clk, rst)
  begin
    if rst = '1' then
      q_r <= (others => '0');
    elsif rising_edge(clk) then
      if clear = '1' then
        q_r <= (others => '0');
      elsif wr = '1' then
        q_r <= d;
      end if;
    end if;
  end process;
end architecture;
