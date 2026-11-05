-- ============================================================
-- memoria_principal.vhd — RAM de comportamiento de 1 KiB
--
-- Memoria principal de la unidad mapeo-memoria: 256 palabras
-- (bloques) de 4 bytes, direccionamiento a nivel de byte con
-- direcciones de 10 bits. Latencia de lectura: 1 ciclo.
--
-- La memoria arranca cargada con un patrón determinista
-- (palabra i = i*3 + 7) para que los bancos de prueba puedan
-- verificar el dato devuelto. Además expone un puerto de
-- escritura síncrona (wr_*) reservado a los testbenches, para
-- cargar contenidos arbitrarios en la simulación.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memoria_principal is
  port (
    -- reloj y reset (reset asíncrono de contenido: recarga el patrón)
    clk     : in  std_logic;
    rst     : in  std_logic;
    -- puerto de lectura (lo usan las cachés)
    addr    : in  unsigned(9 downto 0);
    req     : in  std_logic;
    ready   : out std_logic;
    data    : out unsigned(31 downto 0);
    -- puerto de escritura (solo bancos de prueba)
    wr_en   : in  std_logic;
    wr_addr : in  unsigned(9 downto 0);
    wr_data : in  unsigned(31 downto 0)
  );
end entity;

architecture comportamiento of memoria_principal is
  constant N_PALABRAS : natural := 256;

  type ram_t is array (0 to N_PALABRAS - 1) of unsigned(31 downto 0);

  -- Patrón de inicialización: palabra i = i*3 + 7.
  function dato_inicial(idx : natural) return unsigned is
  begin
    return resize(to_unsigned(idx, 32) * 3 + 7, 32);
  end function;

  signal data_r  : unsigned(31 downto 0) := (others => '0');
  signal ready_r : std_logic             := '0';
begin
  data  <= data_r;
  ready <= ready_r;

  process(clk)
    variable ram : ram_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        -- Carga del patrón de fábrica en cada reset
        for i in 0 to N_PALABRAS - 1 loop
          ram(i) := dato_inicial(i);
        end loop;
        data_r  <= (others => '0');
        ready_r <= '0';
      else
        -- Escritura síncrona (prioritaria en el mismo ciclo)
        if wr_en = '1' then
          ram(to_integer(wr_addr(9 downto 2))) := wr_data;
        end if;

        -- Lectura con latencia de 1 ciclo
        if req = '1' then
          data_r  <= ram(to_integer(addr(9 downto 2)));
          ready_r <= '1';
        else
          ready_r <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;
