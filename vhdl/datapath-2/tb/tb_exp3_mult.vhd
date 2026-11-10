-- ============================================================
-- tb_exp3_mult.vhd — Experimento 3: P = A x B
--
-- Instancia datapath + control en modo 10 (multiplicación). La
-- entrada externa (EXT1) se presenta en los pasos 64 (=A),
-- 65 (=B) y 66 (=0). La multiplicación se realiza por sumas
-- repetidas (R6 <- R6 + R3) en el microcódigo.
-- Comprobaciones:
--   * resultados: 4x3 = 12 ; 5x5 = 25 ; 15x15 = 225 ; B = 0 -> 0;
--   * al 'fin', out_en = 1, addr = R6 y dato_out/rf_dout = P;
--   * 'paso' queda en 71 (saltos condicionales 67/69 -> 71);
--   * 'cero' refleja el resultado (1 si P = 0, 0 en otro caso);
--   * un monitor verifica direcciones A/B y el código de operación
--     de los pasos 64, 67 (test sin escritura), 68, 69 y 71.
-- Todo el estado vive en el banco de registros: no hay
-- registros dedicados fuera de R0..R7.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_exp3_mult is
end entity;

architecture tb of tb_exp3_mult is
  constant T_CICLO : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '0';
  signal modo     : unsigned(1 downto 0) := "10";
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

  signal a_actual : unsigned(7 downto 0) := (others => '0');
  signal b_actual : unsigned(7 downto 0) := (others => '0');
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

  -- Entradas externas del modo 10:
  --   paso 64 = A, 65 = B, 66 = 0 (P inicial)
  with paso select
    ext1 <= a_actual          when to_unsigned(64, 7),
            b_actual          when to_unsigned(65, 7),
            to_unsigned(0, 8) when to_unsigned(66, 7),
            (others => '0')   when others;

  -- Monitor de coherencia del microcódigo (muestrea en cada flanco)
  monitor : process
  begin
    wait until rising_edge(clk);
    case to_integer(paso) is
      when 64 =>  -- R3 <- A (EXT1, bypass)
        assert addr = "011" and wr_rf = '1' and sel_sup = "00" and
               sel_inf = '1'
          report "Paso 64 incoherente: se esperaba R3 <- A"
          severity failure;
      when 67 =>  -- test de R4 (sin escritura) y salto si cero
        assert addr = "100" and wr_rf = '0' and op_alu = "000"
          report "Paso 67 incoherente: test de R4 sin escritura"
          severity failure;
      when 68 =>  -- R6 <- R6 + R3 (bucle de sumas repetidas)
        assert addr = "110" and addr_b = "011" and wr_rf = '1' and
               op_alu = "001" and sel_inf = '0'
          report "Paso 68 incoherente: se esperaba R6 <- R6 + R3"
          severity failure;
      when 69 =>  -- R4 <- R4 - 1 (salto condicional si cero)
        assert addr = "100" and wr_rf = '1' and op_alu = "100"
          report "Paso 69 incoherente: se esperaba R4 <- R4 - 1"
          severity failure;
      when 71 =>  -- salida: dato_out <- R6, sin escritura
        assert addr = "110" and wr_rf = '0' and out_en = '1'
          report "Paso 71 incoherente: se esperaba out_en con addr = R6"
          severity failure;
      when others => null;
    end case;
  end process;

  process
    procedure ejecutar(constant a   : in unsigned(7 downto 0);
                       constant b   : in unsigned(7 downto 0);
                       constant esp : in unsigned(7 downto 0)) is
    begin
      a_actual <= a;
      b_actual <= b;
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert dato_out = esp
        report "Producto " & integer'image(to_integer(a)) & "x" &
               integer'image(to_integer(b)) &
               ": dato_out se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dato_out))
        severity failure;
      assert rf_dout = esp
        report "Producto " & integer'image(to_integer(a)) & "x" &
               integer'image(to_integer(b)) &
               ": lectura A del banco se esperaba " &
               integer'image(to_integer(esp)) & " y se obtuvo " &
               integer'image(to_integer(rf_dout))
        severity failure;
      assert paso = to_unsigned(71, 7)
        report "Tras el bucle 'paso' debe quedar en 71 (salto a fin)"
        severity failure;
      assert out_en = '1'
        report "En fin out_en debe seguir activo" severity failure;
      -- El detector de cero refleja el resultado publicado (R6)
      if esp = to_unsigned(0, 8) then
        assert cero = '1'
          report "Con P = 0 el detector debe activar cero"
          severity failure;
      else
        assert cero = '0'
          report "Con P /= 0 el detector debe mantener cero = 0"
          severity failure;
      end if;
      report "mult(" & integer'image(to_integer(a)) & "," &
             integer'image(to_integer(b)) & ") = " &
             integer'image(to_integer(dato_out)) & " en " &
             integer'image(to_integer(ciclos)) & " microciclos";
      wait until rising_edge(clk);
    end procedure;
  begin
    modo <= "10";

    ejecutar(to_unsigned(4, 8),  to_unsigned(3, 8),  to_unsigned(12, 8));
    ejecutar(to_unsigned(5, 8),  to_unsigned(5, 8),  to_unsigned(25, 8));
    ejecutar(to_unsigned(15, 8), to_unsigned(15, 8), to_unsigned(225, 8));
    ejecutar(to_unsigned(7, 8),  to_unsigned(0, 8),  to_unsigned(0, 8));

    report "tb_exp3_mult: OK - 4x3=12, 5x5=25, 15x15=225, B=0 -> 0";
    finish;
  end process;
end architecture;
