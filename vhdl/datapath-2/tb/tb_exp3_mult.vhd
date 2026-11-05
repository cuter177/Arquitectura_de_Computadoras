-- ============================================================
-- tb_exp3_mult.vhd — Experimento 3: P = A x B
--
-- Instancia datapath + control en modo 10 (multiplicación). La
-- entrada externa (EXT1) se presenta en los pasos 65 (=A) y 67 (=B).
-- La multiplicación se realiza por sumas repetidas con la rutina
-- compartida del microcódigo. Al activarse 'fin' comprueba:
--   4x3 = 12 ; 5x5 = 25 ; 15x15 = 225 ; B=0 -> 0.
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

  signal a_actual : unsigned(7 downto 0) := (others => '0');
  signal b_actual : unsigned(7 downto 0) := (others => '0');
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

  -- Entradas externas del modo 10: paso 65 = A, 67 = B
  with paso select
    ext1 <= a_actual        when to_unsigned(65, 7),
            b_actual        when to_unsigned(67, 7),
            (others => '0') when others;

  process
    procedure ejecutar(constant a     : in unsigned(7 downto 0);
                       constant b     : in unsigned(7 downto 0);
                       constant esp   : in unsigned(7 downto 0)) is
    begin
      a_actual <= a;
      b_actual <= b;
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk) and fin = '1';
      wait for 1 ns;
      assert acc_q = esp
        report "Producto " & integer'image(to_integer(a)) & "x" &
               integer'image(to_integer(b)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(acc_q))
        severity failure;
      report "mult(" & integer'image(to_integer(a)) & "," &
             integer'image(to_integer(b)) & ") = " &
             integer'image(to_integer(acc_q)) & " en " &
             integer'image(to_integer(ciclos)) & " microciclos";
      wait until rising_edge(clk);
    end procedure;
  begin
    modo <= "10";

    ejecutar(to_unsigned(4, 8),  to_unsigned(3, 8),   to_unsigned(12, 8));
    ejecutar(to_unsigned(5, 8),  to_unsigned(5, 8),   to_unsigned(25, 8));
    ejecutar(to_unsigned(15, 8), to_unsigned(15, 8),  to_unsigned(225, 8));
    ejecutar(to_unsigned(7, 8),  to_unsigned(0, 8),   to_unsigned(0, 8));

    report "tb_exp3_mult: OK - 4x3=12, 5x5=25, 15x15=225, B=0 -> 0";
    finish;
  end process;
end architecture;
