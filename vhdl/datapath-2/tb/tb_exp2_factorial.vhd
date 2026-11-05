-- ============================================================
-- tb_exp2_factorial.vhd — Experimento 2: n!
--
-- Instancia datapath + control en modo 01 (factorial). La entrada
-- externa (EXT1) se presenta en los pasos 33 (=1), 35 (=n) y 38 (=2),
-- que son las microinstrucciones con sel_sup = 00 del modo 01.
-- Al activarse 'fin' comprueba la salida:
--   n = 1 -> 1 ; n = 5 -> 120.
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

  -- Entradas externas del modo 01: paso 33 = 1, 35 = n, 38 = 2
  with paso select
    ext1 <= to_unsigned(1, 8) when to_unsigned(33, 7),
            n_actual          when to_unsigned(35, 7),
            to_unsigned(2, 8) when to_unsigned(38, 7),
            (others => '0')   when others;

  process
    procedure ejecutar(constant n     : in unsigned(7 downto 0);
                       constant esp   : in unsigned(7 downto 0)) is
    begin
      n_actual <= n;
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert acc_q = esp
        report "Factorial " & integer'image(to_integer(n)) &
               "!: se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(acc_q))
        severity failure;
      report "fact(" & integer'image(to_integer(n)) & ") = " &
             integer'image(to_integer(acc_q)) & " en " &
             integer'image(to_integer(ciclos)) & " microciclos";
      wait until rising_edge(clk);
    end procedure;
  begin
    modo <= "01";

    ejecutar(to_unsigned(1, 8), to_unsigned(1, 8));     -- 1! = 1
    ejecutar(to_unsigned(5, 8), to_unsigned(120, 8));   -- 5! = 120

    report "tb_exp2_factorial: OK - 1!=1, 5!=120";
    finish;
  end process;
end architecture;
