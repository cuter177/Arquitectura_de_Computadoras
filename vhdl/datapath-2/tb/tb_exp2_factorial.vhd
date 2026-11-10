-- ============================================================
-- tb_exp2_factorial.vhd — Experimento 2: n!
--
-- Instancia datapath + control en modo 01 (factorial). La entrada
-- externa (EXT1) se presenta en los pasos 32 (=1), 33 (=n),
-- 34 (=2) y 38 (=0), que son las microinstrucciones con
-- sel_sup = 00 del modo 01. La multiplicación se hace por sumas
-- repetidas dentro del propio microcódigo (R6 <- R6 + R3).
-- Comprobaciones:
--   * resultados: n = 1 -> 1 ; n = 3 -> 6 ; n = 5 -> 120;
--   * al 'fin', out_en = 1, addr = R2 y dato_out/rf_dout = n!;
--   * 'paso' queda en 46 (saltos condicionales 35/40/44 -> 46);
--   * un monitor verifica direcciones A/B, código de operación y
--     que los pasos de test (35) no escriban en el banco.
-- Todo el estado vive en el banco de registros: no hay
-- registros dedicados fuera de R0..R7.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_exp2_factorial is
end entity;

architecture tb of tb_exp2_factorial is
  constant T_CICLO : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '0';
  signal modo     : unsigned(1 downto 0) := "01";
  signal ext1     : unsigned(7 downto 0) := (others => '0');
  signal cero     : std_logic;
  signal paso     : unsigned(6 downto 0);
  signal ciclos   : unsigned(15 downto 0);
  signal fin      : std_logic;
  signal rf_dout  : unsigned(7 downto 0);
  signal dato_out : unsigned(7 downto 0);

  signal sel_sup : unsigned(1 downto 0);
  signal addr    : unsigned(2 downto 0);
  signal addr_b  : unsigned(2 downto 0);
  signal wr_rf   : std_logic;
  signal op_alu  : unsigned(2 downto 0);
  signal sel_inf : std_logic;
  signal sh      : unsigned(1 downto 0);
  signal out_en  : std_logic;

  signal n_actual : unsigned(7 downto 0) := (others => '0');
begin
  clk <= not clk after T_CICLO / 2;

  ctrl : entity work.control
    port map (
      clk => clk, rst => rst, modo => modo, cero => cero,
      sel_sup => sel_sup, addr => addr, addr_b => addr_b,
      wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf, sh => sh,
      out_en => out_en, paso => paso, ciclos => ciclos, fin => fin);

  dp : entity work.datapath
    port map (
      clk => clk, rst => rst, ext1 => ext1, sel_sup => sel_sup,
      addr => addr, addr_b => addr_b, wr_rf => wr_rf,
      op_alu => op_alu, sel_inf => sel_inf, sh => sh, out_en => out_en,
      dato_out => dato_out, cero => cero, rf_dout => rf_dout);

  -- Entradas externas del modo 01:
  --   paso 32 = 1 (fact inicial), 33 = n (veces = n-1),
  --   paso 34 = 2 (i inicial), 38 = 0 (P inicial)
  with paso select
    ext1 <= to_unsigned(1, 8)  when to_unsigned(32, 7),
            n_actual           when to_unsigned(33, 7),
            to_unsigned(2, 8)  when to_unsigned(34, 7),
            to_unsigned(0, 8)  when to_unsigned(38, 7),
            (others => '0')    when others;

  -- Monitor de coherencia del microcódigo (muestrea en cada flanco)
  monitor : process
  begin
    wait until rising_edge(clk);
    case to_integer(paso) is
      when 33 =>  -- R5 <- EXT1(n) - 1  (veces = n - 1)
        assert addr = "101" and wr_rf = '1' and op_alu = "100" and
               sel_sup = "00" and sel_inf = '0'
          report "Paso 33 incoherente: se esperaba R5 <- n - 1"
          severity failure;
      when 35 =>  -- test de R5 (sin escritura) y salto si cero
        assert addr = "101" and wr_rf = '0' and op_alu = "000"
          report "Paso 35 incoherente: test de R5 sin escritura"
          severity failure;
      when 39 =>  -- R6 <- R6 + R3 (bucle interno)
        assert addr = "110" and addr_b = "011" and wr_rf = '1' and
               op_alu = "001" and sel_inf = '0'
          report "Paso 39 incoherente: se esperaba R6 <- R6 + R3"
          severity failure;
      when 42 =>  -- R2 <- R6 (copia por la lectura B)
        assert addr = "010" and addr_b = "110" and wr_rf = '1' and
               sel_sup = "11" and sel_inf = '1'
          report "Paso 42 incoherente: se esperaba copia R2 <- R6"
          severity failure;
      when 46 =>  -- salida: dato_out <- R2, sin escritura
        assert addr = "010" and wr_rf = '0' and out_en = '1'
          report "Paso 46 incoherente: se esperaba out_en con addr = R2"
          severity failure;
      when others => null;
    end case;
  end process;

  process
    procedure ejecutar(constant n   : in unsigned(7 downto 0);
                       constant esp : in unsigned(7 downto 0)) is
    begin
      n_actual <= n;
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert dato_out = esp
        report "Factorial " & integer'image(to_integer(n)) &
               "!: dato_out se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dato_out))
        severity failure;
      assert rf_dout = esp
        report "Factorial " & integer'image(to_integer(n)) &
               "!: lectura A del banco se esperaba " &
               integer'image(to_integer(esp)) & " y se obtuvo " &
               integer'image(to_integer(rf_dout))
        severity failure;
      assert paso = to_unsigned(46, 7)
        report "Tras los bucles 'paso' debe quedar en 46 (salto a fin)"
        severity failure;
      assert out_en = '1'
        report "En fin out_en debe seguir activo" severity failure;
      assert cero = '0'
        report "n! >= 1: cero debe ser 0 en el paso final"
        severity failure;
      report "fact(" & integer'image(to_integer(n)) & ") = " &
             integer'image(to_integer(dato_out)) & " en " &
             integer'image(to_integer(ciclos)) & " microciclos";
      wait until rising_edge(clk);
    end procedure;
  begin
    modo <= "01";

    ejecutar(to_unsigned(1, 8), to_unsigned(1, 8));     -- 1! = 1
    ejecutar(to_unsigned(3, 8), to_unsigned(6, 8));     -- 3! = 6
    ejecutar(to_unsigned(5, 8), to_unsigned(120, 8));   -- 5! = 120

    report "tb_exp2_factorial: OK - 1!=1, 3!=6, 5!=120";
    finish;
  end process;
end architecture;
