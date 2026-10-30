-- ============================================================
-- tb_acumulador.vhd — Banco de prueba del acumulador (autochequeo)
--
-- Verifica el reinicio, la carga (wr), la retención cuando no se
-- carga y la prioridad del clear sobre wr.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_acumulador is
end entity;

architecture tb of tb_acumulador is
  constant T_CICLO : time := 10 ns;
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '0';
  signal d     : unsigned(7 downto 0) := (others => '0');
  signal wr    : std_logic := '0';
  signal clear : std_logic := '0';
  signal q     : unsigned(7 downto 0);
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.acumulador
    port map (clk => clk, rst => rst, d => d, wr => wr, clear => clear, q => q);

  process
  begin
    -- Reinicio asíncrono
    rst <= '1';
    wait for 2 ns;
    assert q = 0 report "rst no pone el acumulador a cero" severity failure;
    wait until rising_edge(clk);
    rst <= '0';

    -- Carga de un valor
    d <= to_unsigned(42, 8);
    wr <= '1';
    wait until rising_edge(clk);
    wr <= '0';
    wait for 1 ns;
    assert q = to_unsigned(42, 8)
      report "Carga fallida: se esperaba 42 y se obtuvo " &
             integer'image(to_integer(q))
      severity failure;

    -- Retención: sin wr, mantiene el valor
    d <= to_unsigned(99, 8);
    wait until rising_edge(clk);
    wait for 1 ns;
    assert q = to_unsigned(42, 8) report "No se retuvo el valor" severity failure;

    -- clear tiene prioridad sobre wr
    d <= to_unsigned(7, 8);
    wr <= '1';
    clear <= '1';
    wait until rising_edge(clk);
    wr <= '0';
    clear <= '0';
    wait for 1 ns;
    assert q = 0 report "clear no tuvo prioridad sobre wr" severity failure;

    report "tb_acumulador: OK - reset, carga, retención y prioridad de clear";
    finish;
  end process;
end architecture;
