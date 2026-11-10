-- ============================================================
-- tb_control.vhd — Banco de prueba de la unidad de control
--
-- Verifica el secuenciamiento de la FSM (sin datapath):
--   * tras el reinicio, 'paso' salta a la base del modo (modo*32);
--   * la secuencia de la suma (modo 00) avanza por los pasos 1,2,
--     3,4,5 y el bucle queda en el rango 3..5;
--   * con cero = 0 el bucle no termina (no se activa 'fin');
--   * forzando cero = 1, el paso 4 (R1 <- R1 - 1) salta al 6,
--     que tiene fin = 1, y la FSM se detiene.
-- 'ciclos' cuenta los microciclos ejecutados.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_control is
end entity;

architecture tb of tb_control is
  constant T_CICLO : time := 10 ns;

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal modo    : unsigned(1 downto 0) := "00";
  signal cero    : std_logic := '0';
  signal sel_sup : unsigned(1 downto 0);
  signal addr    : unsigned(2 downto 0);
  signal addr_b  : unsigned(2 downto 0);
  signal wr_rf   : std_logic;
  signal op_alu  : unsigned(2 downto 0);
  signal sel_inf : std_logic;
  signal sh      : unsigned(1 downto 0);
  signal out_en  : std_logic;
  signal paso    : unsigned(6 downto 0);
  signal ciclos  : unsigned(15 downto 0);
  signal fin     : std_logic;
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.control
    port map (
      clk => clk, rst => rst, modo => modo, cero => cero,
      sel_sup => sel_sup, addr => addr, addr_b => addr_b,
      wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf, sh => sh,
      out_en => out_en, paso => paso, ciclos => ciclos, fin => fin);

  process
    procedure reiniciar is
    begin
      rst <= '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk);  -- fija la base del modo
    end procedure;
  begin
    -- Reinicio y base del modo 00 (0)
    modo <= "00";
    reiniciar;
    wait for 1 ns;
    assert paso = to_unsigned(0, 7)
      report "La base del modo 00 debe ser el paso 0" severity failure;

    -- Con cero = 0: la secuencia avanza por 1,2,3,4,5 y el bucle
    -- de acumulación (R2 <- R2+R1 / R1 <- R1-1 / salta) queda en 3..5
    for i in 0 to 40 loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;
    assert fin = '0'
      report "Con cero=0 el bucle de la suma no debe terminar" severity failure;
    assert paso >= 3 and paso <= 5
      report "El paso debe permanecer en el bucle de la suma (3..5)"
      severity failure;

    -- Forzando cero = 1 desde el arranque: en el paso 4 salta al 6,
    -- que tiene fin = 1, y la FSM debe detenerse.
    modo <= "00";
    cero <= '1';
    reiniciar;
    for i in 0 to 20 loop
      wait until rising_edge(clk);
      exit when fin = '1';
    end loop;
    wait for 1 ns;
    cero <= '0';
    assert fin = '1'
      report "Con cero=1 la suma debe saltar al paso 6 y activar 'fin'"
      severity failure;

    -- Base del modo 01 (factorial) = 32
    modo <= "01";
    reiniciar;
    wait for 1 ns;
    assert paso = to_unsigned(32, 7)
      report "La base del modo 01 debe ser el paso 32" severity failure;

    -- Base del modo 10 (multiplicación) = 64
    modo <= "10";
    reiniciar;
    wait for 1 ns;
    assert paso = to_unsigned(64, 7)
      report "La base del modo 10 debe ser el paso 64" severity failure;

    report "tb_control: OK - base por modo, bucle y fin verificados";
    finish;
  end process;
end architecture;
