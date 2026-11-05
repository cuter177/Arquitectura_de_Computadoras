-- ============================================================
-- tb_memoria_principal.vhd — banco de prueba de la RAM
--
-- Comprueba: (1) el patrón de fábrica (palabra i = i*3 + 7) en
-- varias direcciones; (2) el puerto de escritura wr_* cargado
-- desde el testbench y su lectura de verificación; (3) que las
-- palabras vecinas no se alteran.
-- Autochequeo: assert ... severity failure + report final OK.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_memoria_principal is
end entity;

architecture tb of tb_memoria_principal is
  constant T_CICLO : time := 10 ns;

  signal clk     : std_logic                     := '0';
  signal rst     : std_logic                     := '1';
  signal addr    : unsigned(9 downto 0)          := (others => '0');
  signal req     : std_logic                     := '0';
  signal ready   : std_logic;
  signal data    : unsigned(31 downto 0);
  signal wr_en   : std_logic                     := '0';
  signal wr_addr : unsigned(9 downto 0)          := (others => '0');
  signal wr_data : unsigned(31 downto 0)         := (others => '0');

  -- Patrón de fábrica: palabra i = i*3 + 7
  function dato_esperado(a : unsigned(9 downto 0)) return unsigned is
  begin
    return resize(to_unsigned(to_integer(a(9 downto 2)), 32) * 3 + 7, 32);
  end function;
begin
  clk <= not clk after T_CICLO / 2;

  mem : entity work.memoria_principal
    port map (
      clk     => clk,
      rst     => rst,
      addr    => addr,
      req     => req,
      ready   => ready,
      data    => data,
      wr_en   => wr_en,
      wr_addr => wr_addr,
      wr_data => wr_data
    );

  estimulos : process
    -- Lee una dirección y devuelve el dato leído
    procedure leer(constant a     : in  unsigned(9 downto 0);
                   variable res   : out unsigned(31 downto 0)) is
    begin
      addr <= a;
      req  <= '1';
      wait until rising_edge(clk) and ready = '1';
      res := data;
      req <= '0';
      wait until rising_edge(clk);
    end procedure;

    -- Lee una dirección y comprueba que coincide con el dato esperado
    procedure comprobar(constant a         : in unsigned(9 downto 0);
                        constant esperado  : in unsigned(31 downto 0)) is
      variable res : unsigned(31 downto 0);
    begin
      leer(a, res);
      assert res = esperado
        report "Fallo de lectura en addr=" & integer'image(to_integer(a)) &
               ": se esperaba " & integer'image(to_integer(esperado)) &
               " y se obtuvo " & integer'image(to_integer(res))
        severity failure;
    end procedure;
  begin
    -- Arranque con reset (recarga el patrón de fábrica)
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- 1) Patrón de fábrica en varias direcciones
    comprobar(to_unsigned(0, 10),    dato_esperado(to_unsigned(0, 10)));   -- 7
    comprobar(to_unsigned(4, 10),    dato_esperado(to_unsigned(4, 10)));   -- 10
    comprobar(to_unsigned(64, 10),   dato_esperado(to_unsigned(64, 10)));  -- 55
    comprobar(to_unsigned(1020, 10), dato_esperado(to_unsigned(1020, 10)));-- 772

    -- 2) Escritura desde el testbench y lectura de verificación
    wait until rising_edge(clk);
    wr_addr <= to_unsigned(20, 10);          -- palabra 5
    wr_data <= x"A5A5F00F";
    wr_en   <= '1';
    wait until rising_edge(clk);
    wr_en   <= '0';
    comprobar(to_unsigned(20, 10), x"A5A5F00F");
    comprobar(to_unsigned(0, 10),  dato_esperado(to_unsigned(0, 10)));  -- intacta

    -- 3) Otra escritura sobre una palabra con contenido de fábrica
    wait until rising_edge(clk);
    wr_addr <= to_unsigned(64, 10);          -- palabra 16
    wr_data <= x"000000AA";
    wr_en   <= '1';
    wait until rising_edge(clk);
    wr_en   <= '0';
    comprobar(to_unsigned(64, 10), x"000000AA");
    comprobar(to_unsigned(4, 10),  dato_esperado(to_unsigned(4, 10)));  -- intacta

    report "tb_memoria_principal: OK (patrón de fábrica, lecturas y escrituras correctas)";
    finish;
  end process;
end architecture;
