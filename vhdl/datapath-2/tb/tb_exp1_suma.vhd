-- ============================================================
-- tb_exp1_suma.vhd — Experimento 1: S(n) = 1 + 2 + ... + n
--
-- Instancia datapath + control en modo 00 (suma) y presenta la
-- entrada externa (n) en el paso 1, donde la microinstrucción usa
-- sel_sup = 00 (EXT1). Al activarse 'fin' comprueba la salida:
--   n = 1 -> 1 ; n = 3 -> 6 ; n = 5 -> 15.
-- Señales expuestas para las ondas: clk, rst, modo, paso, ciclos,
-- fin, acc_q, rf_dout, cero, dato_out.
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
  signal acc_q    : unsigned(7 downto 0);
  signal rf_dout  : unsigned(7 downto 0);
  signal dato_out : unsigned(7 downto 0);

  signal sel_sup : unsigned(1 downto 0);
  signal wr_acc  : std_logic;
  signal clr_acc : std_logic;
  signal addr    : unsigned(2 downto 0);
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
      sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc, addr => addr,
      wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf, sh => sh,
      out_en => out_en, paso => paso, ciclos => ciclos, fin => fin);

  dp : entity work.datapath
    port map (
      clk => clk, rst => rst, ext1 => ext1, sel_sup => sel_sup,
      wr_acc => wr_acc, clr_acc => clr_acc, addr => addr, wr_rf => wr_rf,
      op_alu => op_alu, sel_inf => sel_inf, sh => sh, out_en => out_en,
      dato_out => dato_out, cero => cero, acc_q => acc_q, rf_dout => rf_dout);

  -- Presenta n en el paso 1 (única lectura de EXT1 del modo 00)
  ext1 <= n_actual when paso = 1 else (others => '0');

  process
    procedure ejecutar(constant n     : in unsigned(7 downto 0);
                       constant esp   : in unsigned(7 downto 0)) is
    begin
      n_actual <= n;
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';
      -- Esperar a 'fin'
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert acc_q = esp
        report "Suma S(" & integer'image(to_integer(n)) &
               "): se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(acc_q))
        severity failure;
      assert dato_out = esp
        report "dato_out de la suma incorrecto para n=" &
               integer'image(to_integer(n)) severity failure;
      report "S(" & integer'image(to_integer(n)) & ") = " &
             integer'image(to_integer(acc_q)) & " en " &
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
