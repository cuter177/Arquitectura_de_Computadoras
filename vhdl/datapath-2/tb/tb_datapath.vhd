-- ============================================================
-- tb_datapath.vhd — Banco de prueba del datapath integrado
--
-- Ejerce el datapath directamente con micro-operaciones manuales
-- (sin unidad de control), reproduciendo la sumatoria S(5) con el
-- banco de registros como único almacenamiento:
--   R1 = i = 5 ; R2 = s = 0
--   R2 <- R2 + R1 ; R1 <- R1 - 1   (hasta i = 0)
-- Disciplina de direcciones (la escritura usa addr como destino):
--   * sumas: destino = lectura A (addr), segundo operando = lectura B
--   * copias: destino = addr, origen = addr_b con sel_sup = 11 (bypass)
-- Comprueba además el detector de cero (i llega a 0), la lectura
-- doble A/B y el buffer de salida sobre la lectura A.
-- Todos los resultados intermedios viven en R0..R7: el banco
-- de registros es el único almacenamiento del datapath.
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
  signal addr     : unsigned(2 downto 0) := "000";
  signal addr_b   : unsigned(2 downto 0) := "000";
  signal wr_rf    : std_logic := '0';
  signal op_alu   : unsigned(2 downto 0) := "000";
  signal sel_inf  : std_logic := '0';
  signal sh       : unsigned(1 downto 0) := "00";
  signal out_en   : std_logic := '0';
  signal dato_out : unsigned(7 downto 0);
  signal cero     : std_logic;
  signal rf_dout  : unsigned(7 downto 0);
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.datapath
    port map (
      clk => clk, rst => rst, ext1 => ext1, sel_sup => sel_sup,
      addr => addr, addr_b => addr_b, wr_rf => wr_rf,
      op_alu => op_alu, sel_inf => sel_inf, sh => sh, out_en => out_en,
      dato_out => dato_out, cero => cero, rf_dout => rf_dout);

  process
    -- Microciclo de escritura: R[dir] <- EXT1(val) (bypass, sel_inf = 1)
    procedure ext_a_reg(constant val : in unsigned(7 downto 0);
                        constant dir : in unsigned(2 downto 0)) is
    begin
      ext1    <= val;
      sel_sup <= "00";
      addr    <= dir;
      addr_b  <= "000";
      wr_rf   <= '1';
      op_alu  <= "000";
      sel_inf <= '1';
      sh      <= "00";
      out_en  <= '0';
      wait until rising_edge(clk);
      wait for 1 ns;
      wr_rf <= '0';
    end procedure;

    -- Microciclo de suma: R[dir] <- R[dir] + R[orig]
    -- (lectura A = destino por addr, lectura B = origen por addr_b)
    procedure suma_en(constant dir  : in unsigned(2 downto 0);
                      constant orig : in unsigned(2 downto 0)) is
    begin
      sel_sup <= "10";
      addr    <= dir;
      addr_b  <= orig;
      wr_rf   <= '1';
      op_alu  <= "001";
      sel_inf <= '0';
      sh      <= "00";
      out_en  <= '0';
      wait until rising_edge(clk);
      wait for 1 ns;
      wr_rf <= '0';
    end procedure;

    -- Microciclo de decremento: R[dir] <- R[dir] - 1
    procedure dec_en(constant dir : in unsigned(2 downto 0)) is
    begin
      sel_sup <= "10";
      addr    <= dir;
      addr_b  <= "000";
      wr_rf   <= '1';
      op_alu  <= "100";
      sel_inf <= '0';
      sh      <= "00";
      out_en  <= '0';
      wait until rising_edge(clk);
      wait for 1 ns;
      wr_rf <= '0';
    end procedure;

    -- Microciclo de copia por la lectura B: R[dir] <- R[orig]
    -- (sel_sup = 11 toma rf_b; bypass con sel_inf = 1)
    procedure copia_b(constant dir  : in unsigned(2 downto 0);
                      constant orig : in unsigned(2 downto 0)) is
    begin
      sel_sup <= "11";
      addr    <= dir;
      addr_b  <= orig;
      wr_rf   <= '1';
      op_alu  <= "000";
      sel_inf <= '1';
      sh      <= "00";
      out_en  <= '0';
      wait until rising_edge(clk);
      wait for 1 ns;
      wr_rf <= '0';
    end procedure;
  begin
    -- Reset asíncrono: banco a cero
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';
    wait for 1 ns;
    assert rf_dout = to_unsigned(0, 8)
      report "Tras el reset la lectura A debe ser 0" severity failure;

    ----------------------------------------------------------------
    -- Sumatoria manual S(5) = 15 usando sólo el banco de registros
    ----------------------------------------------------------------
    ext_a_reg(to_unsigned(5, 8), "001");           -- R1 = 5
    assert rf_dout = to_unsigned(5, 8)
      report "R1 debe valer 5 tras cargar EXT1" severity failure;
    assert cero = '0'
      report "cero debe ser 0 con sh_out = 5" severity failure;

    suma_en("010", "001");                         -- R2 = 0 + 5 = 5
    assert rf_dout = to_unsigned(5, 8)
      report "R2 tras 1 suma: se esperaba 5" severity failure;

    dec_en("001");                                 -- R1 = 4
    assert rf_dout = to_unsigned(4, 8)
      report "R1 tras 1er decremento: se esperaba 4" severity failure;

    suma_en("010", "001");                         -- R2 = 5 + 4 = 9
    assert rf_dout = to_unsigned(9, 8)
      report "R2 tras 2 sumas: se esperaba 9" severity failure;

    dec_en("001");                                 -- R1 = 3
    assert rf_dout = to_unsigned(3, 8)
      report "R1 tras 2o decremento: se esperaba 3" severity failure;

    suma_en("010", "001");                         -- R2 = 9 + 3 = 12
    assert rf_dout = to_unsigned(12, 8)
      report "R2 tras 3 sumas: se esperaba 12" severity failure;

    dec_en("001");                                 -- R1 = 2
    assert rf_dout = to_unsigned(2, 8)
      report "R1 tras 3er decremento: se esperaba 2" severity failure;

    suma_en("010", "001");                         -- R2 = 12 + 2 = 14
    assert rf_dout = to_unsigned(14, 8)
      report "R2 tras 4 sumas: se esperaba 14" severity failure;

    dec_en("001");                                 -- R1 = 1
    assert rf_dout = to_unsigned(1, 8)
      report "R1 tras 4o decremento: se esperaba 1" severity failure;

    suma_en("010", "001");                         -- R2 = 14 + 1 = 15
    assert rf_dout = to_unsigned(15, 8)
      report "R2 final: se esperaba 15 (S(5))" severity failure;

    -- Último decremento R1 <- 0: se comprueba 'cero' ANTES del
    -- flanco (con R1 aún en 1: A-1 = 0 activa el detector)
    sel_sup <= "10";
    addr    <= "001";
    addr_b  <= "000";
    wr_rf   <= '1';
    op_alu  <= "100";
    sel_inf <= '0';
    wait for 1 ns;
    assert cero = '1'
      report "cero debe ser 1 con R1 = 1 y op = A-1 (resultado 0)"
      severity failure;
    wait until rising_edge(clk);
    wait for 1 ns;
    wr_rf <= '0';
    assert rf_dout = to_unsigned(0, 8)
      report "R1 final debe ser 0" severity failure;
    assert cero = '0'
      report "tras escribir R1 = 0 el shifter ya no da 0 (A-1 = 255)"
      severity failure;

    ----------------------------------------------------------------
    -- Lectura doble A/B: R4 <- EXT1(7) y luego R4 <- R4 + R2
    -- (A = R4 = 7 por addr, B = R2 = 15 por addr_b, en el mismo ciclo)
    ----------------------------------------------------------------
    ext_a_reg(to_unsigned(7, 8), "100");           -- R4 = 7
    assert rf_dout = to_unsigned(7, 8)
      report "R4 debe valer 7 tras cargar EXT1" severity failure;

    suma_en("100", "010");                         -- R4 = 7 + 15 = 22
    assert rf_dout = to_unsigned(22, 8)
      report "R4 <- R4 + R2: se esperaba 7 + 15 = 22" severity failure;

    ----------------------------------------------------------------
    -- Copia por el puerto B (sel_sup = 11, bypass): R5 <- R4
    ----------------------------------------------------------------
    copia_b("101", "100");                         -- R5 = 22
    assert rf_dout = to_unsigned(22, 8)
      report "R5 <- R4 (copia por lectura B): se esperaba 22"
      severity failure;

    ----------------------------------------------------------------
    -- Buffer de salida: dato_out = lectura A sólo con out_en = 1
    ----------------------------------------------------------------
    addr   <= "010";            -- apunta a R2 = 15
    out_en <= '0';
    wait for 1 ns;
    assert dato_out = to_unsigned(0, 8)
      report "dato_out debe ser 0 con out_en = 0" severity failure;
    out_en <= '1';
    wait for 1 ns;
    assert dato_out = to_unsigned(15, 8)
      report "dato_out con out_en = 1 y addr = R2: se esperaba 15"
      severity failure;
    addr <= "101";              -- apunta a R5 = 22
    wait for 1 ns;
    assert dato_out = to_unsigned(22, 8)
      report "dato_out con addr = R5: se esperaba 22" severity failure;
    out_en <= '0';
    wait for 1 ns;
    assert dato_out = to_unsigned(0, 8)
      report "dato_out debe volver a 0 al deshabilitar" severity failure;

    report "tb_datapath: OK - S(5)=15 en R2, lectura doble 7+15=22, " &
           "copia R5=22, detector de cero y buffer de salida verificados";
    finish;
  end process;
end architecture;
