-- ============================================================
-- cache_asociativa.vhd — caché asociativa total (16 líneas x 4 B)
--
-- Reparto de la dirección de 10 bits (mini-ejemplo Stallings):
--   tag(8) = addr(9..2) | offset(2)
-- Cualquier bloque puede ocupar cualquier línea: en el ciclo
-- COMPARE se comparan en paralelo las 16 etiquetas con el tag
-- solicitado (búsqueda asociativa tipo CAM).
--
-- Reemplazo LRU (Stallings §5.2): cada línea lleva un contador
-- de antigüedad (0 = más reciente, 15 = más antigua); la víctima
-- de un fallo es la de mayor contador. El contador se mantiene
-- como permutación de 0..15 con el reajuste estándar.
--
-- Máquina de estados (igual que el resto de la unidad):
--   IDLE -> COMPARE -> (FETCH_MEM -> DONE) | DONE
-- Códigos de 'estado': 0 = IDLE, 1 = COMPARE, 2 = FETCH_MEM, 3 = DONE.
--
-- Solo lectura (fetch de instrucciones): sin dirty bit ni política
-- de escritura. Latencia de memoria principal: 1 ciclo.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_asociativa is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    addr      : in  unsigned(9 downto 0);  -- dirección solicitada (byte)
    req       : in  std_logic;             -- pulso de solicitud de lectura
    ready     : out std_logic;             -- dato válido
    data      : out unsigned(31 downto 0); -- palabra devuelta
    hit       : out std_logic;             -- 1 si acierto en caché
    estado    : out unsigned(1 downto 0);  -- estado de la FSM (para ondas)
    -- hacia memoria principal (solo lectura)
    mem_addr  : out unsigned(9 downto 0);
    mem_req   : out std_logic;
    mem_data  : in  unsigned(31 downto 0);
    mem_ready : in  std_logic
  );
end entity;

architecture rtl of cache_asociativa is
  constant N_LINEAS : natural := 16;

  subtype tag_t is unsigned(7 downto 0);
  type etiquetas_t is array (0 to N_LINEAS - 1) of tag_t;
  type datos_t     is array (0 to N_LINEAS - 1) of unsigned(31 downto 0);
  type lru_t       is array (0 to N_LINEAS - 1) of natural range 0 to N_LINEAS - 1;

  signal etiquetas : etiquetas_t                             := (others => (others => '0'));
  signal datos     : datos_t                                 := (others => (others => '0'));
  signal valid     : std_logic_vector(N_LINEAS - 1 downto 0) := (others => '0');
  signal lru       : lru_t                                   := (others => 0);

  -- Códigos de la FSM
  constant EST_IDLE    : unsigned(1 downto 0) := "00";
  constant EST_COMPARE : unsigned(1 downto 0) := "01";
  constant EST_FETCH   : unsigned(1 downto 0) := "10";
  constant EST_DONE    : unsigned(1 downto 0) := "11";

  signal estado_r   : unsigned(1 downto 0)  := EST_IDLE;
  signal req_prev   : std_logic             := '0';
  signal addr_reg   : unsigned(9 downto 0)  := (others => '0');
  signal data_r     : unsigned(31 downto 0) := (others => '0');
  signal hit_r      : std_logic             := '0';
  signal ready_r    : std_logic             := '0';
  signal mem_addr_r : unsigned(9 downto 0)  := (others => '0');
  signal mem_req_r  : std_logic             := '0';
  signal fill_idx   : natural range 0 to N_LINEAS - 1 := 0;
begin
  ready    <= ready_r;
  data     <= data_r;
  hit      <= hit_r;
  estado   <= estado_r;
  mem_addr <= mem_addr_r;
  mem_req  <= mem_req_r;

  process(clk)
    variable tag_v    : tag_t;
    variable encontrada : boolean;
    variable idx_hit  : natural range 0 to N_LINEAS - 1;
    variable libre    : boolean;
    variable idx_libre : natural range 0 to N_LINEAS - 1;
    variable idx_victima : natural range 0 to N_LINEAS - 1;
    variable edad_max : natural range 0 to N_LINEAS - 1;
    variable edad_acc : natural range 0 to N_LINEAS - 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid      <= (others => '0');
        lru        <= (others => 0);
        estado_r   <= EST_IDLE;
        req_prev   <= '0';
        ready_r    <= '0';
        hit_r      <= '0';
        mem_req_r  <= '0';
        data_r     <= (others => '0');
        mem_addr_r <= (others => '0');
        fill_idx   <= 0;
      else
        req_prev <= req;

        case to_integer(estado_r) is
          when 0 =>  -- IDLE
            ready_r <= '0';
            -- Solo arranca con flanco de subida de req (evita accesos repetidos)
            if req = '1' and req_prev = '0' then
              addr_reg <= addr;
              estado_r <= EST_COMPARE;
            end if;

          when 1 =>  -- COMPARE
            tag_v := addr_reg(9 downto 2);

            -- Búsqueda asociativa: comparación paralela de los 16 tags.
            -- Además se eligen la línea libre y la víctima LRU.
            encontrada := false;
            idx_hit    := 0;
            libre      := false;
            idx_libre  := 0;
            idx_victima := 0;
            edad_max   := 0;
            for i in 0 to N_LINEAS - 1 loop
              if valid(i) = '1' and etiquetas(i) = tag_v then
                encontrada := true;
                idx_hit    := i;
              end if;
              if valid(i) = '0' and not libre then
                libre     := true;
                idx_libre := i;
              end if;
              if lru(i) > edad_max then
                edad_max    := lru(i);
                idx_victima := i;
              end if;
            end loop;

            if encontrada then
              -- Acierto: el dato ya está en alguna línea
              data_r   <= datos(idx_hit);
              hit_r    <= '1';
              -- Actualización LRU: la línea accedida pasa a ser la más reciente
              edad_acc := lru(idx_hit);
              for i in 0 to N_LINEAS - 1 loop
                if i /= idx_hit and lru(i) < edad_acc then
                  lru(i) <= lru(i) + 1;
                end if;
              end loop;
              lru(idx_hit) <= 0;
              estado_r <= EST_DONE;
            else
              -- Fallo: se pide el bloque a memoria; la línea destino es la
              -- libre si la hay, y si no la menos reciente (LRU).
              hit_r <= '0';
              if libre then
                fill_idx <= idx_libre;
              else
                fill_idx <= idx_victima;
              end if;
              mem_addr_r <= addr_reg(9 downto 2) & "00";
              estado_r   <= EST_FETCH;
            end if;

          when 2 =>  -- FETCH_MEM
            mem_req_r <= '1';
            if mem_ready = '1' then
              datos(fill_idx)    <= mem_data;
              etiquetas(fill_idx) <= addr_reg(9 downto 2);
              valid(fill_idx)    <= '1';
              data_r             <= mem_data;
              mem_req_r          <= '0';
              -- Actualización LRU tras la carga
              edad_acc := lru(fill_idx);
              for i in 0 to N_LINEAS - 1 loop
                if i /= fill_idx and lru(i) < edad_acc then
                  lru(i) <= lru(i) + 1;
                end if;
              end loop;
              lru(fill_idx) <= 0;
              estado_r <= EST_DONE;
            end if;

          when others =>  -- DONE
            ready_r  <= '1';
            estado_r <= EST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
