-- ============================================================
-- tb_exp1_suma.vhd — Experimento 1: S(n) = 1 + 2 + ... + n
--
-- Instancia datapath + control en modo 00 (suma) y presenta la
-- entrada externa (n) en el paso 1, donde la microinstrucción usa
-- sel_sup = 00 (EXT1). El paso 2 carga R2 <- 0 desde EXT1 (0).
-- Comprobaciones:
--   * resultados: n = 1 -> 1 ; n = 3 -> 6 ; n = 5 -> 15;
--   * al 'fin', out_en = 1, addr = R2 y dato_out/rf_dout = S(n);
--   * 'paso' queda en 6 (salto condicional 4 -> 6 con cero = 1);
--   * un monitor verifica en cada flanco la coherencia de las
--     direcciones A/B y el código de operación en los pasos 3, 4 y 6.
-- Todo el estado vive en el banco de registros: no hay
-- registros dedicados fuera de R0..R7.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_exp1_suma is
end entity;

architecture tb of tb_exp1_suma is
  constant T_CICLO : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '0';
  signal modo     : unsigned(1 downto 0) := "00";
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

  -- Entrada externa: n en el paso 1 y 0 en el paso 2 (EXT1)
  ext1 <= n_actual when paso = 1 else (others => '0');

  -- Monitor de coherencia: en cada flanco comprueba que las
  -- microinstrucciones activas usan las direcciones y el código
  -- de operación esperados (lectura A = destino, B = segundo operando)
  monitor : process
  begin
    wait until rising_edge(clk);
    case to_integer(paso) is
      when 3 =>   -- R2 <- R2 + R1
        assert addr = "010" and addr_b = "001" and wr_rf = '1' and
               op_alu = "001" and sel_inf = '0'
          report "Paso 3 incoherente: se esperaba R2 <- R2 + R1"
          severity failure;
      when 4 =>   -- R1 <- R1 - 1 (salto condicional si cero)
        assert addr = "001" and wr_rf = '1' and op_alu = "100"
          report "Paso 4 incoherente: se esperaba R1 <- R1 - 1"
          severity failure;
      when 6 =>   -- salida: dato_out <- R2, sin escritura
        assert addr = "010" and wr_rf = '0' and out_en = '1'
          report "Paso 6 incoherente: se esperaba out_en con addr = R2"
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
      -- Esperar a 'fin'
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert dato_out = esp
        report "Suma S(" & integer'image(to_integer(n)) &
               "): dato_out se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dato_out))
        severity failure;
      assert rf_dout = esp
        report "Suma S(" & integer'image(to_integer(n)) &
               "): lectura A del banco se esperaba " &
               integer'image(to_integer(esp)) & " y se obtuvo " &
               integer'image(to_integer(rf_dout))
        severity failure;
      assert paso = to_unsigned(6, 7)
        report "Tras el bucle 'paso' debe quedar en 6 (salto 4 -> 6)"
        severity failure;
      assert out_en = '1'
        report "En fin out_en debe seguir activo" severity failure;
      assert cero = '0'
        report "S(n) >= 1: cero debe ser 0 en el paso final"
        severity failure;
      report "S(" & integer'image(to_integer(n)) & ") = " &
             integer'image(to_integer(dato_out)) & " en " &
             integer'image(to_integer(ciclos)) & " microciclos";
      wait until rising_edge(clk);
    end procedure;
  begin
    modo <= "00";

    ejecutar(to_unsigned(1, 8), to_unsigned(1, 8));    -- S(1) = 1
    ejecutar(to_unsigned(3, 8), to_unsigned(6, 8));    -- S(3) = 6
    ejecutar(to_unsigned(5, 8), to_unsigned(15, 8));   -- S(5) = 15

    report "tb_exp1_suma: OK - S(1)=1, S(3)=6, S(5)=15";
    finish;
  end process;
end architecture;
