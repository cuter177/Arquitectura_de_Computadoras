-- ============================================================
-- Envoltorio de placa de datapath-2 (Terasic DE10-Standard)
--
-- No es parte del diseño lógico: conecta la unidad de control y el
-- datapath de datapath-2 a los periféricos de la placa para poder
-- ejecutar los tres experimentos sin simulador. Vive en fpga/ (y no
-- en src/) para que scripts/vhdl-analizar y scripts/vhdl-sim sigan
-- trabajando con los módulos originales de la unidad.
--
-- Controles:
--   SW[9:8]  modo: 00 suma, 01 factorial, 10 multiplicación
--                  11 inválido (no arranca; se avisa por LEDR8)
--   SW[7:0]  operando n (suma/factorial) o A/B (multiplicación)
--   KEY0     ejecutar / capturar
--            - suma y factorial: una pulsación captura n y ejecuta
--            - multiplicación: 1.ª captura A, 2.ª captura B y ejecuta
--   KEY3     reset general
--   KEY1/2   sin uso
--
-- Salidas:
--   HEX5:HEX4  operando A / n (8 bits)
--   HEX3:HEX2  operando B (8 bits; 00 en suma/factorial)
--   HEX1:HEX0  resultado (8 bits)
--   LEDR[1:0]  modo (en LISTO se muestra el de los switches)
--   LEDR[3:2]  estado: 00 listo, 01 esperando B, 10 ejecutando, 11 fin
--   LEDR[4]    cero del resultado (latcheado en FIN)
--   LEDR[5]    resultado válido (estado = FIN)
--   LEDR[6]    ocupado (estado = EJECUTANDO)
--   LEDR[7]    esperando B (estado = ESPERA_B)
--   LEDR[8]    modo inválido (SW[9:8] = 11 en LISTO/FIN)
--   LEDR[9]    0
--
-- Decisiones de diseño:
--   - El control se mantiene en reset (paso = 0) en LISTO, ESPERA_B
--     y FIN. Así la secuencia de dos pulsaciones de KEY0 no consume
--     ext1 ni avanza la FSM hasta que A y B están capturadas.
--   - El modo se latchea en la pulsación y no cambia durante la
--     ejecución.
--   - El resultado se captura en la transición EJECUTANDO -> FIN,
--     cuando out_en = 1 y dato_out ya es estable.
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
            modo    : in  unsigned(1 downto 0);
            cero    : in  std_logic;
            sel_sup : out unsigned(1 downto 0);
            addr    : out unsigned(2 downto 0);
            addr_b  : out unsigned(2 downto 0);
            wr_rf   : out std_logic;
            op_alu  : out unsigned(2 downto 0);
            sel_inf : out std_logic;
            sh      : out unsigned(1 downto 0);
            out_en  : out std_logic;
            paso    : out unsigned(6 downto 0);
            ciclos  : out unsigned(15 downto 0);
            fin     : out std_logic
        );
    end component;

    component datapath is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ext1     : in  unsigned(7 downto 0);
            sel_sup  : in  unsigned(1 downto 0);
            addr     : in  unsigned(2 downto 0);
            addr_b   : in  unsigned(2 downto 0);
            wr_rf    : in  std_logic;
            op_alu   : in  unsigned(2 downto 0);
            sel_inf  : in  std_logic;
            sh       : in  unsigned(1 downto 0);
            out_en   : in  std_logic;
            dato_out : out unsigned(7 downto 0);
            cero     : out std_logic;
            rf_dout  : out unsigned(7 downto 0)
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
    constant EST_LISTO      : unsigned(1 downto 0) := "00";
    constant EST_ESPERA_B   : unsigned(1 downto 0) := "01";
    constant EST_EJECUTANDO : unsigned(1 downto 0) := "10";
    constant EST_FIN        : unsigned(1 downto 0) := "11";

    signal rst_global : std_logic;
    signal pulso_run  : std_logic;
    signal armado     : std_logic := '0';

    signal estado        : unsigned(1 downto 0) := EST_LISTO;
    signal modo_reg      : unsigned(1 downto 0) := (others => '0');
    signal a_reg         : unsigned(7 downto 0) := (others => '0');
    signal b_reg         : unsigned(7 downto 0) := (others => '0');
    signal resultado_reg : unsigned(7 downto 0) := (others => '0');
    signal cero_reg      : std_logic := '0';

    signal rst_dp : std_logic;

    -- palabra de control y estado del control
    signal sel_sup : unsigned(1 downto 0);
    signal addr    : unsigned(2 downto 0);
    signal addr_b  : unsigned(2 downto 0);
    signal wr_rf   : std_logic;
    signal op_alu  : unsigned(2 downto 0);
    signal sel_inf : std_logic;
    signal sh      : unsigned(1 downto 0);
    signal out_en  : std_logic;
    signal paso    : unsigned(6 downto 0);
    signal fin     : std_logic;

    -- datos del datapath
    signal ext1     : unsigned(7 downto 0);
    signal dato_out : unsigned(7 downto 0);
    signal cero     : std_logic;

    -- valores visibles en los displays
    signal modo_visible : unsigned(1 downto 0);
    signal a_mostrado   : unsigned(7 downto 0);
    signal b_mostrado   : unsigned(7 downto 0);
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

    -- El control y el datapath están resetados en LISTO, ESPERA_B y FIN.
    rst_dp <= '1' when estado = EST_LISTO or
                       estado = EST_ESPERA_B or
                       estado = EST_FIN
              else '0';

    ------------------------------------------------------------------
    -- FSM del envoltorio
    ------------------------------------------------------------------
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                estado        <= EST_LISTO;
                modo_reg      <= (others => '0');
                a_reg         <= (others => '0');
                b_reg         <= (others => '0');
                resultado_reg <= (others => '0');
                cero_reg      <= '0';
            else
                case estado is
                    when EST_LISTO =>
                        if pulso_run = '1' and armado = '1' then
                            if sw(9 downto 8) = "11" then
                                -- modo inválido: no se arranca
                                null;
                            else
                                modo_reg      <= unsigned(sw(9 downto 8));
                                a_reg         <= unsigned(sw(7 downto 0));
                                b_reg         <= (others => '0');
                                resultado_reg <= (others => '0');
                                cero_reg      <= '0';
                                if sw(9 downto 8) = "10" then
                                    estado <= EST_ESPERA_B;
                                else
                                    estado <= EST_EJECUTANDO;
                                end if;
                            end if;
                        end if;

                    when EST_ESPERA_B =>
                        if pulso_run = '1' and armado = '1' then
                            b_reg  <= unsigned(sw(7 downto 0));
                            estado <= EST_EJECUTANDO;
                        end if;

                    when EST_EJECUTANDO =>
                        if fin = '1' then
                            resultado_reg <= dato_out;
                            cero_reg      <= cero;
                            estado        <= EST_FIN;
                        end if;

                    when EST_FIN =>
                        if pulso_run = '1' and armado = '1' then
                            if sw(9 downto 8) = "11" then
                                -- modo inválido: no se arranca
                                null;
                            else
                                modo_reg      <= unsigned(sw(9 downto 8));
                                a_reg         <= unsigned(sw(7 downto 0));
                                b_reg         <= (others => '0');
                                resultado_reg <= (others => '0');
                                cero_reg      <= '0';
                                if sw(9 downto 8) = "10" then
                                    estado <= EST_ESPERA_B;
                                else
                                    estado <= EST_EJECUTANDO;
                                end if;
                            end if;
                        end if;

                    when others =>
                        estado <= EST_LISTO;
                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Entrada externa (EXT1) según el paso del microcódigo
    --   suma:        1 -> n, 2 -> 0
    --   factorial:  32 -> 1, 33 -> n, 34 -> 2, 38 -> 0
    --   multiplic.: 64 -> A, 65 -> B, 66 -> 0
    -- Los rangos de pasos de cada modo no se solapan, así que basta
    -- con mirar 'paso' (igual que hacen los testbenches de la unidad).
    ------------------------------------------------------------------
    process (paso, a_reg, b_reg)
    begin
        case to_integer(paso) is
            when 1 =>
                ext1 <= a_reg;
            when 32 =>
                ext1 <= to_unsigned(1, 8);
            when 33 =>
                ext1 <= a_reg;
            when 34 =>
                ext1 <= to_unsigned(2, 8);
            when 64 =>
                ext1 <= a_reg;
            when 65 =>
                ext1 <= b_reg;
            when others =>
                ext1 <= (others => '0');
        end case;
    end process;

    ------------------------------------------------------------------
    -- Valores visibles: en LISTO/ESPERA_B se muestra lo que se edita
    ------------------------------------------------------------------
    modo_visible <= unsigned(sw(9 downto 8)) when estado = EST_LISTO
                    else modo_reg;
    a_mostrado   <= unsigned(sw(7 downto 0)) when estado = EST_LISTO
                    else a_reg;
    b_mostrado   <= unsigned(sw(7 downto 0)) when estado = EST_ESPERA_B
                    else b_reg;

    ------------------------------------------------------------------
    -- Control y datapath originales
    ------------------------------------------------------------------
    u_control : control
        port map (
            clk     => clk,
            rst     => rst_dp,
            modo    => modo_reg,
            cero    => cero,
            sel_sup => sel_sup,
            addr    => addr,
            addr_b  => addr_b,
            wr_rf   => wr_rf,
            op_alu  => op_alu,
            sel_inf => sel_inf,
            sh      => sh,
            out_en  => out_en,
            paso    => paso,
            ciclos  => open,
            fin     => fin
        );

    u_datapath : datapath
        port map (
            clk      => clk,
            rst      => rst_dp,
            ext1     => ext1,
            sel_sup  => sel_sup,
            addr     => addr,
            addr_b   => addr_b,
            wr_rf    => wr_rf,
            op_alu   => op_alu,
            sel_inf  => sel_inf,
            sh       => sh,
            out_en   => out_en,
            dato_out => dato_out,
            cero     => cero,
            rf_dout  => open
        );

    ------------------------------------------------------------------
    -- Salidas de la placa
    ------------------------------------------------------------------
    ledr(1 downto 0) <= std_logic_vector(modo_visible);
    ledr(3 downto 2) <= std_logic_vector(estado);
    ledr(4) <= cero_reg;
    ledr(5) <= '1' when estado = EST_FIN else '0';
    ledr(6) <= '1' when estado = EST_EJECUTANDO else '0';
    ledr(7) <= '1' when estado = EST_ESPERA_B else '0';
    ledr(8) <= '1' when (estado = EST_LISTO or estado = EST_FIN) and
                        (sw(9 downto 8) = "11")
               else '0';
    ledr(9) <= '0';

    u_hex5 : hex7seg
        port map (
            valor  => std_logic_vector(a_mostrado(7 downto 4)),
            salida => hex5
        );

    u_hex4 : hex7seg
        port map (
            valor  => std_logic_vector(a_mostrado(3 downto 0)),
            salida => hex4
        );

    u_hex3 : hex7seg
        port map (
            valor  => std_logic_vector(b_mostrado(7 downto 4)),
            salida => hex3
        );

    u_hex2 : hex7seg
        port map (
            valor  => std_logic_vector(b_mostrado(3 downto 0)),
            salida => hex2
        );

    u_hex1 : hex7seg
        port map (
            valor  => std_logic_vector(resultado_reg(7 downto 4)),
            salida => hex1
        );

    u_hex0 : hex7seg
        port map (
            valor  => std_logic_vector(resultado_reg(3 downto 0)),
            salida => hex0
        );
end architecture;
