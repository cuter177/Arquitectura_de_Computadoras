-- ============================================================
-- Controlador de motor paso a paso bipolar NEMA 17 (Steren
-- MOT-200: 1.8 grados/paso, 200 pasos/vuelta).
--
-- Recibe la palabra genérica del control (g_wr, g_en y g_dato)
-- y mantiene el número de pasos pendientes, la fase activa y el
-- sentido de giro. Produce:
--   * fases      : patrón de excitación de los dos bobinados
--                  (paso completo, dos fases activas, 4 estados)
--   * paso_pulso : pulso de un ciclo por cada cambio de fase
--                  (se conecta a STEP del driver A4988/DRV8825)
--   * cero       : flag para el control cuando se agotan los pasos
--
-- La lógica es 3.3 V: la corriente de 1.7 A por fase la suministra
-- el driver externo con fuente propia, no la FPGA.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity motor_pasos is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        carga     : in  std_logic;                     -- g_wr: cargar número de pasos
        avance    : in  std_logic;                     -- g_en: avanzar una fase
        sentido   : in  std_logic;                     -- '0' adelante, '1' atrás
        dato_in   : in  std_logic_vector(7 downto 0);  -- número de pasos (1..255)
        fase_cod  : in  std_logic_vector(1 downto 0);  -- g_dato(1:0): fase deseada
        fases     : out std_logic_vector(3 downto 0);  -- patrón de bobinas
        paso_pulso: out std_logic;                     -- pulso STEP
        cero      : out std_logic;                     -- pasos agotados
        pasos_rest: out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of motor_pasos is
    signal pasos_reg : unsigned(7 downto 0) := (others => '0');
    signal fase_act  : std_logic_vector(1 downto 0) := "00";
    signal cambio    : std_logic := '0';
begin
    -- Decodificación de la fase activa: excitación de dos fases.
    -- Adelante: 0011 -> 0110 -> 1100 -> 1001
    -- Atrás:    1001 -> 1100 -> 0110 -> 0011
    process (fase_act, sentido)
        variable indice : natural range 0 to 3;
    begin
        indice := to_integer(unsigned(fase_act));
        if sentido = '1' then
            indice := 3 - indice;
        end if;
        case indice is
            when 0 => fases <= "0011";
            when 1 => fases <= "0110";
            when 2 => fases <= "1100";
            when others => fases <= "1001";
        end case;
    end process;

    cero       <= '1' when pasos_reg = 0 else '0';
    paso_pulso <= cambio;
    pasos_rest <= std_logic_vector(pasos_reg);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pasos_reg <= (others => '0');
                fase_act  <= "00";
                cambio    <= '0';
            elsif carga = '1' then
                pasos_reg <= unsigned(dato_in);
                -- centinela: la primera fase (código 00) debe generar
                -- un pulso STEP; con "11" garantizamos el cambio en el
                -- siguiente paso, y con cero pasos no se emite ninguno.
                fase_act  <= "11";
                cambio    <= '0';
            elsif avance = '1' and pasos_reg > 0 then
                pasos_reg <= pasos_reg - 1;
                if fase_act /= fase_cod then
                    fase_act <= fase_cod;
                    cambio   <= '1';
                else
                    cambio <= '0';
                end if;
            else
                cambio <= '0';
            end if;
        end if;
    end process;
end architecture;
