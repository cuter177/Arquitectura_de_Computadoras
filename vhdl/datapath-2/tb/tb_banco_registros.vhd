-- ============================================================
-- tb_banco_registros.vhd — Banco de prueba del banco de registros
--
-- Verifica el reinicio (todos los registros a 0), la escritura
-- síncrona en varias direcciones, la lectura combinacional por el
-- puerto A y la doble lectura simultánea (addr_a y addr_b).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_banco_registros is
end entity;

architecture tb of tb_banco_registros is
  constant T_CICLO : time := 10 ns;
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '0';
  signal addr_a : unsigned(2 downto 0) := "000";
  signal addr_b : unsigned(2 downto 0) := "000";
  signal din    : unsigned(7 downto 0) := (others => '0');
  signal wr     : std_logic := '0';
  signal dout_a : unsigned(7 downto 0);
  signal dout_b : unsigned(7 downto 0);
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.banco_registros
    port map (clk => clk, rst => rst, addr_a => addr_a, addr_b => addr_b,
              din => din, wr => wr, dout_a => dout_a, dout_b => dout_b);

  process
    procedure escribir(constant dir : in unsigned(2 downto 0);
                       constant val : in unsigned(7 downto 0)) is
    begin
      addr_a <= dir;
      din    <= val;
      wr     <= '1';
      wait until rising_edge(clk);
      wr     <= '0';
      wait until rising_edge(clk);
    end procedure;

    -- Lectura por el puerto A
    procedure leer(constant dir : in unsigned(2 downto 0);
                   constant esp : in unsigned(7 downto 0)) is
    begin
      addr_a <= dir;
      wait for 1 ns;
      assert dout_a = esp
        report "Lectura A incorrecta en R" & integer'image(to_integer(dir)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dout_a))
        severity failure;
    end procedure;

    -- Doble lectura simultánea: A y B en el mismo microciclo
    procedure leer_doble(constant dir_a : in unsigned(2 downto 0);
                         constant esp_a : in unsigned(7 downto 0);
                         constant dir_b : in unsigned(2 downto 0);
                         constant esp_b : in unsigned(7 downto 0)) is
    begin
      addr_a <= dir_a;
      addr_b <= dir_b;
      wait for 1 ns;
      assert dout_a = esp_a and dout_b = esp_b
        report "Doble lectura (A=R" & integer'image(to_integer(dir_a)) &
               ", B=R" & integer'image(to_integer(dir_b)) &
               "): se esperaba " & integer'image(to_integer(esp_a)) &
               "/" & integer'image(to_integer(esp_b)) &
               " y se obtuvo " & integer'image(to_integer(dout_a)) &
               "/" & integer'image(to_integer(dout_b))
        severity failure;
    end procedure;
  begin
    -- Reinicio
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    for i in 0 to 7 loop
      leer(to_unsigned(i, 3), to_unsigned(0, 8));
    end loop;

    -- Escrituras en los extremos y en el centro
    escribir(to_unsigned(0, 3), to_unsigned(11, 8));
    escribir(to_unsigned(7, 3), to_unsigned(240, 8));
    escribir(to_unsigned(3, 3), to_unsigned(128, 8));

    leer(to_unsigned(0, 3), to_unsigned(11, 8));
    leer(to_unsigned(7, 3), to_unsigned(240, 8));
    leer(to_unsigned(3, 3), to_unsigned(128, 8));
    -- Los registros no escritos siguen a cero
    leer(to_unsigned(1, 3), to_unsigned(0, 8));
    leer(to_unsigned(6, 3), to_unsigned(0, 8));

    -- Doble lectura: dos operandos distintos en el mismo flanco
    escribir(to_unsigned(5, 3), to_unsigned(77, 8));
    leer_doble(to_unsigned(3, 3), to_unsigned(128, 8),
               to_unsigned(5, 3), to_unsigned(77, 8));
    leer_doble(to_unsigned(5, 3), to_unsigned(77, 8),
               to_unsigned(3, 3), to_unsigned(128, 8));
    -- Mismo registro por los dos puertos
    leer_doble(to_unsigned(7, 3), to_unsigned(240, 8),
               to_unsigned(7, 3), to_unsigned(240, 8));
    -- Un puerto lee un registro mientras el otro apunta a uno a cero
    leer_doble(to_unsigned(0, 3), to_unsigned(11, 8),
               to_unsigned(2, 3), to_unsigned(0, 8));

    report "tb_banco_registros: OK - reset, escritura, lectura A y doble lectura";
    finish;
  end process;
end architecture;
