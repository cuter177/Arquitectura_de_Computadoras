-- ============================================================
-- Envoltorio de placa de datapath-3 (Terasic DE10-Standard)
--
-- No es parte del diseño lógico: conecta la unidad de control y el
-- datapath de datapath-3 a los periféricos de la placa para poder
-- ejecutar los cuatro experimentos sin simulador. Vive en fpga/ (y
-- no en src/) para que scripts/vhdl-analizar y scripts/vhdl-sim
-- sigan trabajando con los módulos originales de la unidad.
--
-- Controles:
--   SW[9:8]  modo: 00 suma, 01 factorial, 10 multiplicación,
--                  11 Fibonacci
--   SW[7:0]  operando n (suma/factorial/Fibonacci) o A/B
--            (multiplicación)
--   KEY0     ejecutar / capturar
--            - suma, factorial y Fibonacci: una pulsación captura
--              el operando y ejecuta
--            - multiplicación: 1.ª captura A, 2.ª captura B y ejecuta
--   KEY3     reset general
--   KEY1/2   sin uso
--
-- Salidas:
--   HEX5:HEX4  operando A / n (8 bits)
--   HEX3:HEX2  operando B (8 bits; 00 en modos de un operando)
--   HEX1:HEX0  resultado (8 bits)
--   LEDR[1:0]  modo (en LISTO se muestra el de los switches)
--   LEDR[3:2]  estado: 00 listo, 01 esperando B, 10 ocupado, 11 fin
--   LEDR[4]    cero del resultado (latcheado en FIN)
--   LEDR[5]    resultado válido (estado = FIN)
--   LEDR[6]    ocupado (ARRANQUE, EJECUTANDO o CAPTURA)
--   LEDR[7]    esperando B (estado = ESPERA_B)
--   LEDR[8]    out_en del buffer de salida
--   LEDR[9]    0
--
-- Decisiones de diseño:
--   - El control se mantiene en reset en LISTO, ESPERA_B y ARRANQUE.
--     ARRANQUE dura un ciclo para que el control cargue la base
--     paso = modo * 32 con el modo ya latcheado.
--   - El resultado se captura en CAPTURA, un ciclo después de que
--     fin se active: en ese flanco la última microinstrucción ya ha
--     escrito el acumulador y dato_out (con out_en = 1) es estable.
--   - En FIN el control queda parado con fin = 1 y out_en = 1; no se
--     resetea para conservar el resultado y la habilitación del buffer.
--   - No se derivan relojes: todo funciona a 50 MHz y el resultado
--     queda latcheado. No se usa divisor ni antirrebote.
--   - KEY0 pasa por pulsador (un flanco = una acción). Un pequeño
--     registro "armado" evita un pulso espurio si KEY0 está pulsado
--     al salir del reset.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_placa is
    port (
        clk  : in  std_logic;                     -- CLOCK_50
        key  : in  std_logic_vector(3 downto 0);  -- KEY[3..0], activo bajo
        sw   : in  std_logic_vector(9 downto 0);  -- SW[9..0]
        ledr : out std_logic_vector(9 downto 0);  -- LEDR[9..0]
        hex0 : out std_logic_vector(6 downto 0);  -- HEX0, activo bajo
        hex1 : out std_logic_vector(6 downto 0);
        hex2 : out std_logic_vector(6 downto 0);
        hex3 : out std_logic_vector(6 downto 0);
        hex4 : out std_logic_vector(6 downto 0);
        hex5 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture estructural of top_placa is
    ------------------------------------------------------------------
    -- Componentes del diseño original y de la base común de la placa
    ------------------------------------------------------------------
    component control is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            cero    : in  std_logic;
            modo    : in  std_logic_vector(1 downto 0);
            sel_sup : out std_logic_vector(1 downto 0);
            wr_acc  : out std_logic;
            clr_acc : out std_logic;
            addr    : out std_logic_vector(2 downto 0);
            wr_rf   : out std_logic;
            op_alu  : out std_logic_vector(2 downto 0);
            sel_inf : out std_logic;
            sh      : out std_logic_vector(1 downto 0);
            out_en  : out std_logic;
            fin     : out std_logic;
            paso    : out std_logic_vector(6 downto 0);
            ciclos  : out std_logic_vector(15 downto 0)
        );
    end component;

    component datapath is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ext_data : in  std_logic_vector(7 downto 0);
            sel_sup  : in  std_logic_vector(1 downto 0);
            wr_acc   : in  std_logic;
            clr_acc  : in  std_logic;
            addr     : in  std_logic_vector(2 downto 0);
            wr_rf    : in  std_logic;
            op_alu   : in  std_logic_vector(2 downto 0);
            sel_inf  : in  std_logic;
            sh       : in  std_logic_vector(1 downto 0);
            out_en   : in  std_logic;
            cero     : out std_logic;
            dato_out : out std_logic_vector(7 downto 0);
            acc_q    : out std_logic_vector(7 downto 0);
            rf_dout  : out std_logic_vector(7 downto 0)
        );
    end component;

    component pulsador is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            entrada : in  std_logic;
            pulso   : out std_logic
        );
    end component;

    component hex7seg is
        port (
            valor  : in  std_logic_vector(3 downto 0);
            salida : out std_logic_vector(6 downto 0)
        );
    end component;

    ------------------------------------------------------------------
    -- Estados del envoltorio
    ------------------------------------------------------------------
    type estado_t is (LISTO, ESPERA_B, ARRANQUE, EJECUTANDO, CAPTURA, FIN);

    signal rst_global : std_logic;
    signal pulso_run  : std_logic;
    signal armado     : std_logic := '0';

    signal estado        : estado_t := LISTO;
    signal modo_reg      : std_logic_vector(1 downto 0) := (others => '0');
    signal a_reg         : std_logic_vector(7 downto 0) := (others => '0');
    signal b_reg         : std_logic_vector(7 downto 0) := (others => '0');
    signal resultado_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal cero_reg      : std_logic := '0';

    signal rst_dp : std_logic;

    -- palabra de control y estado del control
    signal sel_sup : std_logic_vector(1 downto 0);
    signal wr_acc  : std_logic;
    signal clr_acc : std_logic;
    signal addr    : std_logic_vector(2 downto 0);
    signal wr_rf   : std_logic;
    signal op_alu  : std_logic_vector(2 downto 0);
    signal sel_inf : std_logic;
    signal sh      : std_logic_vector(1 downto 0);
    signal out_en  : std_logic;
    signal paso    : std_logic_vector(6 downto 0) := (others => '0');
    signal fin_control : std_logic := '0';

    -- datos del datapath
    signal ext_data : std_logic_vector(7 downto 0);
    signal dato_out : std_logic_vector(7 downto 0);
    signal cero     : std_logic;

    -- valores visibles en los displays y LEDs
    signal estado_visible : std_logic_vector(1 downto 0);
    signal modo_visible   : std_logic_vector(1 downto 0);
    signal a_mostrado     : std_logic_vector(7 downto 0);
    signal b_mostrado     : std_logic_vector(7 downto 0);
    signal ledr_s         : std_logic_vector(9 downto 0);
begin
    ------------------------------------------------------------------
    -- Entradas de la placa
    ------------------------------------------------------------------
    rst_global <= not key(3);

    u_pulsador : pulsador
        port map (
            clk     => clk,
            rst     => rst_global,
            entrada => not key(0),
            pulso   => pulso_run
        );

    -- Armado: si KEY0 está pulsado al salir del reset, el pulsador
    -- emite un pulso espurio. No se acepta hasta ver KEY0 suelto.
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                armado <= '0';
            elsif pulso_run = '0' then
                armado <= '1';
            end if;
        end if;
    end process;

    -- El control y el datapath están resetados en LISTO, ESPERA_B y
    -- ARRANQUE. En FIN se dejan parados para conservar out_en y el
    -- resultado del buffer.
    rst_dp <= '1' when estado = LISTO or
                       estado = ESPERA_B or
                       estado = ARRANQUE
              else '0';

    ------------------------------------------------------------------
    -- FSM del envoltorio
    ------------------------------------------------------------------
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                estado        <= LISTO;
                modo_reg      <= (others => '0');
                a_reg         <= (others => '0');
                b_reg         <= (others => '0');
                resultado_reg <= (others => '0');
                cero_reg      <= '0';
            else
                case estado is
                    when LISTO =>
                        if pulso_run = '1' and armado = '1' then
                            modo_reg      <= sw(9 downto 8);
                            a_reg         <= sw(7 downto 0);
                            b_reg         <= (others => '0');
                            resultado_reg <= (others => '0');
                            cero_reg      <= '0';
                            if sw(9 downto 8) = "10" then
                                estado <= ESPERA_B;
                            else
                                estado <= ARRANQUE;
                            end if;
                        end if;

                    when ESPERA_B =>
                        if pulso_run = '1' and armado = '1' then
                            b_reg  <= sw(7 downto 0);
                            estado <= ARRANQUE;
                        end if;

                    when ARRANQUE =>
                        -- un ciclo con rst_dp = 1 para cargar la base
                        -- de microcódigo con el modo ya latcheado
                        estado <= EJECUTANDO;

                    when EJECUTANDO =>
                        if fin_control = '1' then
                            estado <= CAPTURA;
                        end if;

                    when CAPTURA =>
                        -- el acumulador ya ha escrito el resultado y
                        -- out_en = 1, así que dato_out es estable
                        resultado_reg <= dato_out;
                        cero_reg      <= cero;
                        estado        <= FIN;

                    when FIN =>
                        if pulso_run = '1' and armado = '1' then
                            modo_reg      <= sw(9 downto 8);
                            a_reg         <= sw(7 downto 0);
                            b_reg         <= (others => '0');
                            resultado_reg <= (others => '0');
                            cero_reg      <= '0';
                            if sw(9 downto 8) = "10" then
                                estado <= ESPERA_B;
                            else
                                estado <= ARRANQUE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Entrada externa (EXT1) según el paso del microcódigo
    --   suma:        1 -> n
    --   factorial:  33 -> 1, 35 -> n, 38 -> 2
    --   multiplic.: 65 -> A, 67 -> B
    --   Fibonacci:  98 -> 1, 100 -> n
    -- Los rangos de pasos de cada modo no se solapan, así que basta
    -- con mirar 'paso' (igual que hacen los testbenches de la unidad).
    ------------------------------------------------------------------
    process (paso, a_reg, b_reg)
    begin
        case to_integer(unsigned(paso)) is
            when 1 =>
                ext_data <= a_reg;
            when 33 =>
                ext_data <= x"01";
            when 35 =>
                ext_data <= a_reg;
            when 38 =>
                ext_data <= x"02";
            when 65 =>
                ext_data <= a_reg;
            when 67 =>
                ext_data <= b_reg;
            when 98 =>
                ext_data <= x"01";
            when 100 =>
                ext_data <= a_reg;
            when others =>
                ext_data <= (others => '0');
        end case;
    end process;

    ------------------------------------------------------------------
    -- Valores visibles: en LISTO/ESPERA_B se muestra lo que se edita
    ------------------------------------------------------------------
    modo_visible <= sw(9 downto 8) when estado = LISTO else modo_reg;
    a_mostrado   <= sw(7 downto 0) when estado = LISTO else a_reg;
    b_mostrado   <= sw(7 downto 0) when estado = ESPERA_B else b_reg;

    ------------------------------------------------------------------
    -- Control y datapath originales
    ------------------------------------------------------------------
    u_control : control
        port map (
            clk     => clk,
            rst     => rst_dp,
            cero    => cero,
            modo    => modo_reg,
            sel_sup => sel_sup,
            wr_acc  => wr_acc,
            clr_acc => clr_acc,
            addr    => addr,
            wr_rf   => wr_rf,
            op_alu  => op_alu,
            sel_inf => sel_inf,
            sh      => sh,
            out_en  => out_en,
            fin     => fin_control,
            paso    => paso,
            ciclos  => open
        );

    u_datapath : datapath
        port map (
            clk      => clk,
            rst      => rst_dp,
            ext_data => ext_data,
            sel_sup  => sel_sup,
            wr_acc   => wr_acc,
            clr_acc  => clr_acc,
            addr     => addr,
            wr_rf    => wr_rf,
            op_alu   => op_alu,
            sel_inf  => sel_inf,
            sh       => sh,
            out_en   => out_en,
            cero     => cero,
            dato_out => dato_out,
            acc_q    => open,
            rf_dout  => open
        );

    ------------------------------------------------------------------
    -- Salidas de la placa
    ------------------------------------------------------------------
    process (estado)
    begin
        case estado is
            when LISTO =>
                estado_visible <= "00";
            when ESPERA_B =>
                estado_visible <= "01";
            when FIN =>
                estado_visible <= "11";
            when others =>
                estado_visible <= "10";
        end case;
    end process;

    process (estado, estado_visible, modo_visible, cero_reg, out_en)
    begin
        ledr_s <= (others => '0');
        ledr_s(1 downto 0) <= modo_visible;
        ledr_s(3 downto 2) <= estado_visible;
        ledr_s(4) <= cero_reg;
        ledr_s(8) <= out_en;

        case estado is
            when ESPERA_B =>
                ledr_s(7) <= '1';
            when ARRANQUE | EJECUTANDO | CAPTURA =>
                ledr_s(6) <= '1';
            when FIN =>
                ledr_s(5) <= '1';
            when others =>
                null;
        end case;
    end process;

    ledr <= ledr_s;

    u_hex5 : hex7seg
        port map (
            valor  => a_mostrado(7 downto 4),
            salida => hex5
        );

    u_hex4 : hex7seg
        port map (
            valor  => a_mostrado(3 downto 0),
            salida => hex4
        );

    u_hex3 : hex7seg
        port map (
            valor  => b_mostrado(7 downto 4),
            salida => hex3
        );

    u_hex2 : hex7seg
        port map (
            valor  => b_mostrado(3 downto 0),
            salida => hex2
        );

    u_hex1 : hex7seg
        port map (
            valor  => resultado_reg(7 downto 4),
            salida => hex1
        );

    u_hex0 : hex7seg
        port map (
            valor  => resultado_reg(3 downto 0),
            salida => hex0
        );
end architecture;
