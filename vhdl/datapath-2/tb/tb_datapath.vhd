-- ============================================================
-- tb_datapath.vhd — Banco de prueba del datapath integrado
--
-- Ejerce el datapath directamente con micro-operaciones manuales
-- del experimento 1 (suma) para n = 5, comprobando paso a paso el
-- acumulador y el banco de registros:
--   i = n = 5 ; s = 0
--   s = s + i = 5 ; i = i - 1 = 4
--   s = s + i = 9 ...
-- Las señales quedan expuestas para la captura de ondas.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_datapath is
end entity;

architecture tb of tb_datapath is
  constant T_CICLO : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '0';
  signal ext1     : unsigned(7 downto 0) := (others => '0');
  signal sel_sup  : unsigned(1 downto 0) := "00";
  signal wr_acc   : std_logic := '0';
  signal clr_acc  : std_logic := '0';
  signal addr     : unsigned(2 downto 0) := "000";
  signal wr_rf    : std_logic := '0';
  signal op_alu   : unsigned(2 downto 0) := "000";
  signal sel_inf  : std_logic := '0';
  signal sh       : unsigned(1 downto 0) := "00";
  signal out_en   : std_logic := '0';
  signal dato_out : unsigned(7 downto 0);
  signal cero     : std_logic;
  signal acc_q    : unsigned(7 downto 0);
  signal rf_dout  : unsigned(7 downto 0);
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.datapath
    port map (
      clk => clk, rst => rst, ext1 => ext1, sel_sup => sel_sup,
      wr_acc => wr_acc, clr_acc => clr_acc, addr => addr, wr_rf => wr_rf,
      op_alu => op_alu, sel_inf => sel_inf, sh => sh, out_en => out_en,
      dato_out => dato_out, cero => cero, acc_q => acc_q, rf_dout => rf_dout);

  process
    -- Carga EXT1 en el acumulador
    procedure cargar_ext(constant val : in unsigned(7 downto 0)) is
    begin
      ext1    <= val;
      sel_sup <= "00";
      wr_acc  <= '1';
      wait until rising_edge(clk);
      wr_acc  <= '0';
    end procedure;

    -- Copia bus_acc en el registro dir
    procedure escribir_rf(constant dir : in unsigned(2 downto 0)) is
    begin
      addr  <= dir;
      wr_rf <= '1';
      wait until rising_edge(clk);
      wr_rf <= '0';
    end procedure;

    -- Acc <- rf_out[dir]
    procedure leer_rf(constant dir : in unsigned(2 downto 0)) is
    begin
      addr    <= dir;
      sel_sup <= "10";
      wr_acc  <= '1';
      wait until rising_edge(clk);
      wr_acc  <= '0';
    end procedure;

    -- Acc <- ALU(acc, rf_out[dir]) con la operación op; devuelve cero
    procedure op_con_rf(constant dir : in unsigned(2 downto 0);
                        constant op  : in unsigned(2 downto 0)) is
    begin
      addr    <= dir;
      op_alu  <= op;
      sel_sup <= "11";
      sel_inf <= '0';
      sh      <= "00";
      wr_acc  <= '1';
      wait until rising_edge(clk);
      wr_acc  <= '0';
    end procedure;
  begin
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- i = n = 5 en R1
    cargar_ext(to_unsigned(5, 8));
    escribir_rf("001");
    -- s = 0 en R2
    clr_acc <= '1';
    wait until rising_edge(clk);
    clr_acc <= '0';
    escribir_rf("010");

    -- Primera iteración: s = 0 + 5 = 5
    leer_rf("010");                 -- acc <- s
    op_con_rf("001", "001");        -- acc <- s + i
    wait for 1 ns;
    assert acc_q = to_unsigned(5, 8)
      report "s tras 1 iteración: se esperaba 5" severity failure;
    escribir_rf("010");             -- R2 <- s

    -- i = i - 1 = 4
    leer_rf("001");                 -- acc <- i
    op_con_rf("000", "100");        -- acc <- i - 1 (A-1 no usa RF)
    wait for 1 ns;
    assert acc_q = to_unsigned(4, 8)
      report "i tras decremento: se esperaba 4" severity failure;
    escribir_rf("001");

    -- Segunda iteración: s = 5 + 4 = 9
    leer_rf("010");
    op_con_rf("001", "001");
    wait for 1 ns;
    assert acc_q = to_unsigned(9, 8)
      report "s tras 2 iteraciones: se esperaba 9" severity failure;

    -- Salida habilitada
    out_en <= '1';
    wait for 1 ns;
    assert dato_out = to_unsigned(9, 8)
      report "dato_out debe reflejar el acumulador" severity failure;

    report "tb_datapath: OK - micro-operaciones del exp. 1 verificadas";
    finish;
  end process;
end architecture;
