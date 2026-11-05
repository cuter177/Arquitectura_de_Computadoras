-- ============================================================
-- cache_directo.vhd — caché de mapeo directo (16 líneas x 4 B)
--
-- Reparto de la dirección de 10 bits (mini-ejemplo Stallings):
--   tag(4) = addr(9..6) | índice(4) = addr(5..2) | offset(2)
-- Cada bloque cabe en una única línea: índice = bloque mod 16.
-- No hay reemplazo: la línea la fija su índice.
--
-- Máquina de estados (igual en las 3 cachés de la unidad):
--   IDLE -> COMPARE -> (FETCH_MEM -> DONE) | DONE
-- Códigos de 'estado': 0 = IDLE, 1 = COMPARE, 2 = FETCH_MEM, 3 = DONE.
--
-- Solo lectura (fetch de instrucciones): sin dirty bit ni política
-- de escritura. Latencia de memoria principal: 1 ciclo.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_directo is
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

architecture rtl of cache_directo is
  constant N_LINEAS : natural := 16;

  subtype tag_t is unsigned(3 downto 0);
  type etiquetas_t is array (0 to N_LINEAS - 1) of tag_t;
  type datos_t     is array (0 to N_LINEAS - 1) of unsigned(31 downto 0);

  signal etiquetas : etiquetas_t                     := (others => (others => '0'));
  signal datos     : datos_t                         := (others => (others => '0'));
  signal valid     : std_logic_vector(N_LINEAS - 1 downto 0) := (others => '0');

  -- Códigos de la FSM
  constant EST_IDLE    : unsigned(1 downto 0) := "00";
  constant EST_COMPARE : unsigned(1 downto 0) := "01";
  constant EST_FETCH   : unsigned(1 downto 0) := "10";
  constant EST_DONE    : unsigned(1 downto 0) := "11";

  signal estado_r   : unsigned(1 downto 0) := EST_IDLE;
  signal req_prev   : std_logic            := '0';
  signal addr_reg   : unsigned(9 downto 0) := (others => '0');
  signal data_r     : unsigned(31 downto 0) := (others => '0');
  signal hit_r      : std_logic            := '0';
  signal ready_r    : std_logic            := '0';
  signal mem_addr_r : unsigned(9 downto 0) := (others => '0');
  signal mem_req_r  : std_logic            := '0';
begin
  ready    <= ready_r;
  data     <= data_r;
  hit      <= hit_r;
  estado   <= estado_r;
  mem_addr <= mem_addr_r;
  mem_req  <= mem_req_r;

  process(clk)
    variable idx : natural range 0 to N_LINEAS - 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid      <= (others => '0');
        estado_r   <= EST_IDLE;
        req_prev   <= '0';
        ready_r    <= '0';
        hit_r      <= '0';
        mem_req_r  <= '0';
        data_r     <= (others => '0');
        mem_addr_r <= (others => '0');
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
            idx := to_integer(addr_reg(5 downto 2));
            if valid(idx) = '1' and etiquetas(idx) = addr_reg(9 downto 6) then
              -- Acierto: el dato ya está en la línea
              data_r  <= datos(idx);
              hit_r   <= '1';
              estado_r <= EST_DONE;
            else
              -- Fallo: se pide el bloque completo a memoria
              hit_r      <= '0';
              mem_addr_r <= addr_reg(9 downto 2) & "00";
              estado_r   <= EST_FETCH;
            end if;

          when 2 =>  -- FETCH_MEM
            mem_req_r <= '1';
            if mem_ready = '1' then
              idx          := to_integer(addr_reg(5 downto 2));
              datos(idx)    <= mem_data;
              etiquetas(idx) <= addr_reg(9 downto 6);
              valid(idx)    <= '1';
              data_r        <= mem_data;
              mem_req_r     <= '0';
              estado_r      <= EST_DONE;
            end if;

          when others =>  -- DONE
            ready_r  <= '1';
            estado_r <= EST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
