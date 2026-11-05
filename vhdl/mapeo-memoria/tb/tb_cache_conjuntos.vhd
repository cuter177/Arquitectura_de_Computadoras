-- ============================================================
-- tb_cache_conjuntos.vhd — banco de prueba de la caché por conjuntos
--
-- Ejecuta LA MISMA traza de 20 accesos que tb_cache_directo y
-- tb_cache_asociativa para que la comparación sea justa. Con
-- 8 conjuntos x 2 vías, el conjunto 0 recibe 3 bloques (las
-- palabras 0, 16 y 32), de modo que hay conflictos parciales:
-- se comporta de forma intermedia entre el mapeo directo (35%
-- de aciertos) y el asociativo total (65%).
--
-- Autochequeo por acceso: dato devuelto y acierto/fallo esperado.
-- Totales verificados: 10 aciertos y 10 fallos.
-- Señales expuestas para la captura de ondas: clk, rst, ciclo,
-- addr, req, ready, hit, data, estado, caches_hits, caches_misses.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_cache_conjuntos is
end entity;

architecture tb of tb_cache_conjuntos is
  constant T_CICLO : time := 10 ns;

  -- Traza de accesos (direcciones byte de 10 bits) — misma que los otros tbs
  type traza_t is array (0 to 19) of unsigned(9 downto 0);
  constant TRAZA : traza_t := (
    to_unsigned(0, 10),   to_unsigned(4, 10),   to_unsigned(8, 10),
    to_unsigned(64, 10),  to_unsigned(0, 10),   to_unsigned(68, 10),
    to_unsigned(8, 10),   to_unsigned(0, 10),   to_unsigned(128, 10),
    to_unsigned(4, 10),   to_unsigned(8, 10),   to_unsigned(0, 10),
    to_unsigned(4, 10),   to_unsigned(8, 10),   to_unsigned(12, 10),
    to_unsigned(4, 10),   to_unsigned(64, 10),  to_unsigned(128, 10),
    to_unsigned(0, 10),   to_unsigned(4, 10));

  -- Acierto (1) o fallo (0) esperado en cada acceso de la traza
  constant ESPERADO_HIT : std_logic_vector(0 to 19) := "00001011011111010001";

  -- Dato de fábrica de la memoria: palabra i = i*3 + 7
  function dato_esperado(a : unsigned(9 downto 0)) return unsigned is
  begin
    return resize(to_unsigned(to_integer(a(9 downto 2)), 32) * 3 + 7, 32);
  end function;

  signal clk    : std_logic            := '0';
  signal rst    : std_logic            := '1';
  signal ciclo  : unsigned(15 downto 0) := (others => '0');
  signal addr   : unsigned(9 downto 0) := (others => '0');
  signal req    : std_logic            := '0';
  signal ready  : std_logic;
  signal data   : unsigned(31 downto 0);
  signal hit    : std_logic;
  signal estado : unsigned(1 downto 0);

  -- Interface caché <-> memoria
  signal mem_addr  : unsigned(9 downto 0);
  signal mem_req   : std_logic;
  signal mem_data  : unsigned(31 downto 0);
  signal mem_ready : std_logic;

  -- Métricas visibles en las ondas
  signal caches_hits   : unsigned(15 downto 0) := (others => '0');
  signal caches_misses : unsigned(15 downto 0) := (others => '0');
begin
  clk <= not clk after T_CICLO / 2;

  contador_ciclos : process(clk)
  begin
    if rising_edge(clk) then
      ciclo <= ciclo + 1;
    end if;
  end process;

  -- Memoria principal (puerto de escritura sin usar en este tb)
  mem : entity work.memoria_principal
    port map (
      clk     => clk,
      rst     => rst,
      addr    => mem_addr,
      req     => mem_req,
      ready   => mem_ready,
      data    => mem_data,
      wr_en   => '0',
      wr_addr => (others => '0'),
      wr_data => (others => '0')
    );

  dut : entity work.cache_conjuntos
    port map (
      clk       => clk,
      rst       => rst,
      addr      => addr,
      req       => req,
      ready     => ready,
      data      => data,
      hit       => hit,
      estado    => estado,
      mem_addr  => mem_addr,
      mem_req   => mem_req,
      mem_data  => mem_data,
      mem_ready => mem_ready
    );

  estimulos : process
    -- Un acceso completo a la caché, con autochequeo
    procedure acceso(constant a        : in unsigned(9 downto 0);
                     constant esp_hit  : in std_logic) is
    begin
      addr <= a;
      req  <= '1';
      wait until rising_edge(clk) and ready = '1';
      assert data = dato_esperado(a)
        report "Dato incorrecto en addr=" & integer'image(to_integer(a)) &
               ": se esperaba " & integer'image(to_integer(dato_esperado(a))) &
               " y se obtuvo " & integer'image(to_integer(data))
        severity failure;
      assert hit = esp_hit
        report "Resultado inesperado en addr=" & integer'image(to_integer(a)) &
               ": hit=" & std_logic'image(hit) &
               " y se esperaba " & std_logic'image(esp_hit)
        severity failure;
      if hit = '1' then
        caches_hits <= caches_hits + 1;
      else
        caches_misses <= caches_misses + 1;
      end if;
      req <= '0';
      wait until rising_edge(clk);
    end procedure;
  begin
    -- Arranque con reset
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- Traza común de accesos
    for i in TRAZA'range loop
      acceso(TRAZA(i), ESPERADO_HIT(i));
    end loop;

    -- Verificación de totales: 10 aciertos y 10 fallos
    assert caches_hits = to_unsigned(10, 16)
      report "Se esperaban 10 aciertos y se obtuvieron " &
             integer'image(to_integer(caches_hits))
      severity failure;
    assert caches_misses = to_unsigned(10, 16)
      report "Se esperaban 10 fallos y se obtuvieron " &
             integer'image(to_integer(caches_misses))
      severity failure;

    report "tb_cache_conjuntos: OK - 10 aciertos / 10 fallos (50% de aciertos)";
    finish;
  end process;
end architecture;
