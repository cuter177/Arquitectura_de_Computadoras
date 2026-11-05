-- ============================================================
-- cache_conjuntos.vhd — caché asociativa por conjuntos (8 x 2 vías)
--
-- Reparto de la dirección de 10 bits (mini-ejemplo Stallings):
--   tag(5) = addr(9..5) | conjunto(3) = addr(4..2) | offset(2)
-- La caché se organiza en 8 conjuntos de 2 líneas (vías); cada
-- bloque solo puede ocupar las dos líneas de su conjunto. En el
-- ciclo COMPARE se comparan en paralelo las 2 etiquetas del
-- conjunto seleccionado.
--
-- Reemplazo LRU (Stallings §5.2): 1 bit por conjunto que indica
-- la vía usada más recientemente; la víctima es la otra vía. Si
-- hay una vía inválida se usa antes que reemplazar.
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

entity cache_conjuntos is
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

architecture rtl of cache_conjuntos is
  constant N_CONJUNTOS : natural := 8;
  constant N_VIAS      : natural := 2;
  constant N_LINEAS    : natural := N_CONJUNTOS * N_VIAS;  -- = 16

  subtype tag_t is unsigned(4 downto 0);
  type etiquetas_t is array (0 to N_LINEAS - 1) of tag_t;
  type datos_t     is array (0 to N_LINEAS - 1) of unsigned(31 downto 0);

  signal etiquetas : etiquetas_t                             := (others => (others => '0'));
  signal datos     : datos_t                                 := (others => (others => '0'));
  signal valid     : std_logic_vector(N_LINEAS - 1 downto 0) := (others => '0');
  -- lru(c) = vía más reciente del conjunto c (la otra es la víctima)
  signal lru       : std_logic_vector(N_CONJUNTOS - 1 downto 0) := (others => '0');

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
    variable tag_v     : tag_t;
    variable conj_v    : natural range 0 to N_CONJUNTOS - 1;
    variable base      : natural range 0 to N_LINEAS - 1;
    variable encontrada : boolean;
    variable idx_hit   : natural range 0 to N_LINEAS - 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid      <= (others => '0');
        lru        <= (others => '0');
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
            tag_v  := addr_reg(9 downto 5);
            conj_v := to_integer(addr_reg(4 downto 2));
            base   := conj_v * N_VIAS;

            -- Búsqueda por conjuntos: comparación paralela de las 2 etiquetas
            encontrada := false;
            idx_hit    := base;
            for v in 0 to N_VIAS - 1 loop
              if valid(base + v) = '1' and etiquetas(base + v) = tag_v then
                encontrada := true;
                idx_hit    := base + v;
              end if;
            end loop;

            if encontrada then
              -- Acierto: el dato ya está en una de las dos vías
              data_r   <= datos(idx_hit);
              hit_r    <= '1';
              -- La vía accedida pasa a ser la más reciente del conjunto
              if (idx_hit - base) = 1 then
                lru(conj_v) <= '1';
              else
                lru(conj_v) <= '0';
              end if;
              estado_r <= EST_DONE;
            else
              -- Fallo: se pide el bloque a memoria
              hit_r <= '0';
              -- Línea destino: vía inválida si la hay; si no, la no-MRU (LRU)
              if valid(base) = '0' then
                fill_idx <= base;
              elsif valid(base + 1) = '0' then
                fill_idx <= base + 1;
              elsif lru(conj_v) = '0' then
                fill_idx <= base + 1;  -- vía 1 es la más antigua
              else
                fill_idx <= base;      -- vía 0 es la más antigua
              end if;
              mem_addr_r <= addr_reg(9 downto 2) & "00";
              estado_r   <= EST_FETCH;
            end if;

          when 2 =>  -- FETCH_MEM
            mem_req_r <= '1';
            if mem_ready = '1' then
              datos(fill_idx)     <= mem_data;
              etiquetas(fill_idx) <= addr_reg(9 downto 5);
              valid(fill_idx)     <= '1';
              data_r              <= mem_data;
              mem_req_r           <= '0';
              -- La vía cargada pasa a ser la más reciente del conjunto
              if (fill_idx mod N_VIAS) = 1 then
                lru(fill_idx / N_VIAS) <= '1';
              else
                lru(fill_idx / N_VIAS) <= '0';
              end if;
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
