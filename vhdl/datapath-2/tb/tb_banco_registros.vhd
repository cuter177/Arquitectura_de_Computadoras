-- ============================================================
-- tb_banco_registros.vhd — Banco de prueba del banco de registros
--
-- Verifica el reinicio (todos los registros a 0), la escritura
-- síncrona en varias direcciones y la lectura combinacional.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_banco_registros is
end entity;

architecture tb of tb_banco_registros is
  constant T_CICLO : time := 10 ns;
  signal clk  : std_logic := '0';
  signal rst  : std_logic := '0';
  signal addr : unsigned(2 downto 0) := "000";
  signal din  : unsigned(7 downto 0) := (others => '0');
  signal wr   : std_logic := '0';
  signal dout : unsigned(7 downto 0);
begin
  clk <= not clk after T_CICLO / 2;

  dut : entity work.banco_registros
    port map (clk => clk, rst => rst, addr => addr, din => din, wr => wr,
              dout => dout);

  process
    procedure escribir(constant dir : in unsigned(2 downto 0);
                       constant val : in unsigned(7 downto 0)) is
    begin
      addr <= dir;
      din  <= val;
      wr   <= '1';
      wait until rising_edge(clk);
      wr   <= '0';
      wait until rising_edge(clk);
    end procedure;

    procedure leer(constant dir : in unsigned(2 downto 0);
                   constant esp : in unsigned(7 downto 0)) is
    begin
      addr <= dir;
      wait for 1 ns;
      assert dout = esp
        report "Lectura incorrecta en R" & integer'image(to_integer(dir)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dout))
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

    report "tb_banco_registros: OK - reset, escritura y lectura de 8 registros";
    finish;
  end process;
end architecture;
