-- ============================================================
-- tb_comparacion_mapeos.vhd — comparación de los 3 mapeos
--
-- Instancia las tres cachés (directa, asociativa total y por
-- conjuntos) sobre UNA sola memoria principal compartida, con
-- un arbitraje round-robin entre los pedidos de bloque. Las
-- tres reciben LA MISMA traza de 20 accesos y el mismo modelo
-- de memoria, de modo que la comparación es justa.
--
-- Autochequeo: por acceso compara dato y acierto/fallo de cada
-- caché contra el patrón esperado; al final verifica los totales
-- (directo 7/13, asociativa 13/7, conjuntos 10/10) y emite con
-- `report` la tabla de aciertos, fallos y tasa de cada mapeo:
-- esa salida es la fuente de la tabla de resultados del reporte.
--
-- Señales expuestas para captura lado a lado: clk, rst, ciclo,
-- addr, req/ready/hit/data/estado por módulo (hit_directo,
-- hit_asociativa, hit_conjuntos...) y los contadores de aciertos
-- y fallos de cada uno.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_comparacion_mapeos is
end entity;

architecture tb of tb_comparacion_mapeos is
  constant T_CICLO : time    := 10 ns;
  constant N_MOD   : natural := 3;  -- 0 = directo, 1 = asociativa, 2 = conjuntos

  -- Traza de accesos (direcciones byte de 10 bits) — misma que los tbs individuales
  type traza_t is array (0 to 19) of unsigned(9 downto 0);
  constant TRAZA : traza_t := (
    to_unsigned(0, 10),   to_unsigned(4, 10),   to_unsigned(8, 10),
    to_unsigned(64, 10),  to_unsigned(0, 10),   to_unsigned(68, 10),
    to_unsigned(8, 10),   to_unsigned(0, 10),   to_unsigned(128, 10),
    to_unsigned(4, 10),   to_unsigned(8, 10),   to_unsigned(0, 10),
    to_unsigned(4, 10),   to_unsigned(8, 10),   to_unsigned(12, 10),
    to_unsigned(4, 10),   to_unsigned(64, 10),  to_unsigned(128, 10),
    to_unsigned(0, 10),   to_unsigned(4, 10));

  -- Acierto (1) o fallo (0) esperado por módulo en cada acceso
  constant ESP_DIRECTO    : std_logic_vector(0 to 19) := "00000011001011010001";
  constant ESP_ASOCIATIVA : std_logic_vector(0 to 19) := "00001011011111011111";
  constant ESP_CONJUNTOS  : std_logic_vector(0 to 19) := "00001011011111010001";

  -- Dato de fábrica de la memoria: palabra i = i*3 + 7
  function dato_esperado(a : unsigned(9 downto 0)) return unsigned is
  begin
    return resize(to_unsigned(to_integer(a(9 downto 2)), 32) * 3 + 7, 32);
  end function;

  signal clk   : std_logic             := '0';
  signal rst   : std_logic             := '1';
  signal ciclo : unsigned(15 downto 0) := (others => '0');

  -- Estímulo: la misma dirección para las tres cachés, req por módulo
  signal addr : unsigned(9 downto 0) := (others => '0');
  type req_arr_t is array (0 to N_MOD - 1) of std_logic;
  signal req : req_arr_t := (others => '0');

  -- Respuesta de cada caché
  type data_arr_t   is array (0 to N_MOD - 1) of unsigned(31 downto 0);
  type addr_arr_t   is array (0 to N_MOD - 1) of unsigned(9 downto 0);
  type estado_arr_t is array (0 to N_MOD - 1) of unsigned(1 downto 0);

  signal ready  : std_logic_vector(N_MOD - 1 downto 0);
  signal data   : data_arr_t;
  signal hit    : std_logic_vector(N_MOD - 1 downto 0);
  signal estado : estado_arr_t;

  -- Interface de cada caché con la memoria compartida
  signal mem_addr_arr  : addr_arr_t;
  signal mem_req_arr   : std_logic_vector(N_MOD - 1 downto 0);
  signal mem_data_arr  : data_arr_t;
  signal mem_ready_arr : std_logic_vector(N_MOD - 1 downto 0);

  -- Interface arbitro <-> memoria compartida
  signal mem_addr  : unsigned(9 downto 0) := (others => '0');
  signal mem_req   : std_logic            := '0';
  signal mem_data  : unsigned(31 downto 0);
  signal mem_ready : std_logic;

  -- Concesión del arbitro (registrada): grant_s atiende en el ciclo
  -- actual; prev_s es la concesión cuya respuesta devuelve la memoria
  signal grant_s : integer range -1 to N_MOD - 1 := -1;
  signal prev_s  : integer range -1 to N_MOD - 1 := -1;

  -- Nombres legibles por módulo para la captura de ondas
  signal req_directo     : std_logic;
  signal req_asociativa  : std_logic;
  signal req_conjuntos   : std_logic;
  signal ready_directo   : std_logic;
  signal ready_asociativa : std_logic;
  signal ready_conjuntos : std_logic;
  signal hit_directo     : std_logic;
  signal hit_asociativa  : std_logic;
  signal hit_conjuntos   : std_logic;

  -- Métricas por módulo visibles en las ondas
  signal hits_directo      : unsigned(15 downto 0) := (others => '0');
  signal misses_directo    : unsigned(15 downto 0) := (others => '0');
  signal hits_asociativa   : unsigned(15 downto 0) := (others => '0');
  signal misses_asociativa : unsigned(15 downto 0) := (others => '0');
  signal hits_conjuntos    : unsigned(15 downto 0) := (others => '0');
  signal misses_conjuntos  : unsigned(15 downto 0) := (others => '0');
begin
  clk <= not clk after T_CICLO / 2;

  contador_ciclos : process(clk)
  begin
    if rising_edge(clk) then
      ciclo <= ciclo + 1;
    end if;
  end process;

  -- Nombres legibles (para las ondas lado a lado)
  req_directo      <= req(0);
  req_asociativa   <= req(1);
  req_conjuntos    <= req(2);
  ready_directo    <= ready(0);
  ready_asociativa <= ready(1);
  ready_conjuntos  <= ready(2);
  hit_directo      <= hit(0);
  hit_asociativa   <= hit(1);
  hit_conjuntos    <= hit(2);

  -- Memoria principal compartida (un único modelo y contenido)
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

  dut_directo : entity work.cache_directo
    port map (
      clk => clk, rst => rst, addr => addr, req => req(0),
      ready => ready(0), data => data(0), hit => hit(0), estado => estado(0),
      mem_addr => mem_addr_arr(0), mem_req => mem_req_arr(0),
      mem_data => mem_data_arr(0), mem_ready => mem_ready_arr(0)
    );

  dut_asociativa : entity work.cache_asociativa
    port map (
      clk => clk, rst => rst, addr => addr, req => req(1),
      ready => ready(1), data => data(1), hit => hit(1), estado => estado(1),
      mem_addr => mem_addr_arr(1), mem_req => mem_req_arr(1),
      mem_data => mem_data_arr(1), mem_ready => mem_ready_arr(1)
    );

  dut_conjuntos : entity work.cache_conjuntos
    port map (
      clk => clk, rst => rst, addr => addr, req => req(2),
      ready => ready(2), data => data(2), hit => hit(2), estado => estado(2),
      mem_addr => mem_addr_arr(2), mem_req => mem_req_arr(2),
      mem_data => mem_data_arr(2), mem_ready => mem_ready_arr(2)
    );

  -- ==========================================================
  -- Árbitro round-robin entre los pedidos de las tres cachés
  -- (memoria compartida con latencia de 1 ciclo)
  -- ==========================================================
  arbitro : process(clk)
    variable pend : natural range 0 to N_MOD - 1 := 0;
    variable g    : integer range -1 to N_MOD - 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pend    := 0;
        grant_s <= -1;
        prev_s  <= -1;
      else
        prev_s  <= grant_s;
        g := -1;
        for k in 0 to N_MOD - 1 loop
          if g = -1 and mem_req_arr((pend + k) mod N_MOD) = '1' then
            g := (pend + k) mod N_MOD;
          end if;
        end loop;
        grant_s <= g;
        if g /= -1 then
          pend := (g + 1) mod N_MOD;
        end if;
      end if;
    end if;
  end process;

  -- Concesión combinacional hacia la memoria
  mem_mux : process(all)
  begin
    if grant_s >= 0 then
      mem_addr <= mem_addr_arr(grant_s);
      mem_req  <= mem_req_arr(grant_s);
    else
      mem_addr <= (others => '0');
      mem_req  <= '0';
    end if;
  end process;

  -- Retorno de la memoria demultiplexado al concedido en el ciclo anterior
  mem_demux : process(all)
  begin
    mem_ready_arr <= (others => '0');
    mem_data_arr  <= (others => (others => '0'));
    if prev_s >= 0 then
      mem_ready_arr(prev_s) <= mem_ready;
      mem_data_arr(prev_s)  <= mem_data;
    end if;
  end process;

  estimulos : process
    variable fin : std_logic_vector(N_MOD - 1 downto 0);
  begin
    -- Arranque con reset
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- Traza común de accesos: las tres cachés ven la misma dirección;
    -- se espera a que las tres terminen el acceso (ready por módulo)
    for i in TRAZA'range loop
      addr <= TRAZA(i);
      req  <= (others => '1');
      fin  := (others => '0');
      while fin /= "111" loop
        wait until rising_edge(clk);
        if ready(0) = '1' and fin(0) = '0' then
          assert data(0) = dato_esperado(TRAZA(i))
            report "Dato incorrecto (directo) en addr=" & integer'image(to_integer(TRAZA(i)))
            severity failure;
          assert hit(0) = ESP_DIRECTO(i)
            report "Acuerdo directo inesperado en addr=" & integer'image(to_integer(TRAZA(i))) &
                   ": hit=" & std_logic'image(hit(0))
            severity failure;
          if hit(0) = '1' then
            hits_directo <= hits_directo + 1;
          else
            misses_directo <= misses_directo + 1;
          end if;
          fin(0) := '1';
        end if;
        if ready(1) = '1' and fin(1) = '0' then
          assert data(1) = dato_esperado(TRAZA(i))
            report "Dato incorrecto (asociativa) en addr=" & integer'image(to_integer(TRAZA(i)))
            severity failure;
          assert hit(1) = ESP_ASOCIATIVA(i)
            report "Acuerdo asociativa inesperado en addr=" & integer'image(to_integer(TRAZA(i))) &
                   ": hit=" & std_logic'image(hit(1))
            severity failure;
          if hit(1) = '1' then
            hits_asociativa <= hits_asociativa + 1;
          else
            misses_asociativa <= misses_asociativa + 1;
          end if;
          fin(1) := '1';
        end if;
        if ready(2) = '1' and fin(2) = '0' then
          assert data(2) = dato_esperado(TRAZA(i))
            report "Dato incorrecto (conjuntos) en addr=" & integer'image(to_integer(TRAZA(i)))
            severity failure;
          assert hit(2) = ESP_CONJUNTOS(i)
            report "Acuerdo conjuntos inesperado en addr=" & integer'image(to_integer(TRAZA(i))) &
                   ": hit=" & std_logic'image(hit(2))
            severity failure;
          if hit(2) = '1' then
            hits_conjuntos <= hits_conjuntos + 1;
          else
            misses_conjuntos <= misses_conjuntos + 1;
          end if;
          fin(2) := '1';
        end if;
      end loop;
      req <= (others => '0');
      wait until rising_edge(clk);
    end loop;

    -- Verificación de totales por módulo
    assert hits_directo = to_unsigned(7, 16)
      report "Directo: se esperaban 7 aciertos y se obtuvieron " &
             integer'image(to_integer(hits_directo)) severity failure;
    assert misses_directo = to_unsigned(13, 16)
      report "Directo: se esperaban 13 fallos y se obtuvieron " &
             integer'image(to_integer(misses_directo)) severity failure;
    assert hits_asociativa = to_unsigned(13, 16)
      report "Asociativa: se esperaban 13 aciertos y se obtuvieron " &
             integer'image(to_integer(hits_asociativa)) severity failure;
    assert misses_asociativa = to_unsigned(7, 16)
      report "Asociativa: se esperaban 7 fallos y se obtuvieron " &
             integer'image(to_integer(misses_asociativa)) severity failure;
    assert hits_conjuntos = to_unsigned(10, 16)
      report "Conjuntos: se esperaban 10 aciertos y se obtuvieron " &
             integer'image(to_integer(hits_conjuntos)) severity failure;
    assert misses_conjuntos = to_unsigned(10, 16)
      report "Conjuntos: se esperaban 10 fallos y se obtuvieron " &
             integer'image(to_integer(misses_conjuntos)) severity failure;

    -- Ordenación esperada: asociativo > conjuntos > directo
    assert hits_asociativa > hits_conjuntos and hits_conjuntos > hits_directo
      report "El orden de tasas no es el esperado (asociativa > conjuntos > directo)"
      severity failure;

    -- Tabla comparativa (fuente de la tabla de resultados del reporte)
    report "tb_comparacion_mapeos: OK - tabla comparativa sobre 20 accesos";
    report "  Mapeo        aciertos  fallos  tasa";
    report "  directo      " & integer'image(to_integer(hits_directo)) &
           "       " & integer'image(to_integer(misses_directo)) &
           "       " & integer'image((100 * to_integer(hits_directo)) / 20) & "%";
    report "  asociativa   " & integer'image(to_integer(hits_asociativa)) &
           "       " & integer'image(to_integer(misses_asociativa)) &
           "       " & integer'image((100 * to_integer(hits_asociativa)) / 20) & "%";
    report "  conjuntos    " & integer'image(to_integer(hits_conjuntos)) &
           "       " & integer'image(to_integer(misses_conjuntos)) &
           "       " & integer'image((100 * to_integer(hits_conjuntos)) / 20) & "%";

    finish;
  end process;
end architecture;
