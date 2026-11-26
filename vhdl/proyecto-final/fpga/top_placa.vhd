-- ============================================================
-- Envoltorio de placa del proyecto final (DE10-Standard).
--
-- Conecta el motor de microcódigo genérico con dos hardware
-- distintos, elegidos con SW[9:8]:
--   00 = multiplicación shift-add (datapath3_rtl)
--   01 = popcount (datapath3_rtl)
--   10 = motor paso a paso NEMA 17 (motor_pasos)
--
-- El mismo control_gen gobierna los tres programas; solo cambia
-- la ROM activa (por el modo) y el periférico que interpreta los
-- campos genéricos de la microinstrucción.
--
-- Controles:
--   SW[9:8]  modo
--   SW[7:0]  A (shift-add), x (popcount) o pasos (motor)
--   KEY0     ejecutar/capturar (en shift-add: 1.ª pulsación A,
--            2.ª pulsación B y arranque)
--   KEY1     invertir sentido del motor
--   KEY3     reset general
--
-- Salidas:
--   HEX5:4  operando A / x / pasos programados
--   HEX3:2  operando B / pasos restantes
--   HEX1:0  resultado
--   LEDR    1:0 modo, 3:2 estado, 4 cero, 5 fin, 6 ocupado,
--           7 espera B, 8 sentido; en modo motor, 3:0 = fases
--   GPIO    STEP (GPIO_0[0]), DIR (GPIO_0[1]), EN (GPIO_0[2]),
--           MS0..MS2 (GPIO_0[3..5]) para el driver A4988/DRV8825
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_placa is
    generic (
        FREC_MOTOR_HZ : natural := 100   -- frecuencia del tick del motor
    );
    port (
        clk     : in  std_logic;                     -- CLOCK_50
        key     : in  std_logic_vector(3 downto 0);  -- activo bajo
        sw      : in  std_logic_vector(9 downto 0);
        ledr    : out std_logic_vector(9 downto 0);
        hex0    : out std_logic_vector(6 downto 0);  -- activo bajo
        hex1    : out std_logic_vector(6 downto 0);
        hex2    : out std_logic_vector(6 downto 0);
        hex3    : out std_logic_vector(6 downto 0);
        hex4    : out std_logic_vector(6 downto 0);
        hex5    : out std_logic_vector(6 downto 0);
        step_out : out std_logic;                    -- GPIO_0[0] -> STEP
        dir_out  : out std_logic;                    -- GPIO_0[1] -> DIR
        en_out   : out std_logic;                    -- GPIO_0[2] -> EN (activo bajo)
        ms_out   : out std_logic_vector(2 downto 0)  -- GPIO_0[3..5] -> MS1/MS2/MS3
    );
end entity;

architecture estructural of top_placa is
    component control_gen is
        port (
            clk : in std_logic; rst : in std_logic; enable : in std_logic;
            cero : in std_logic; modo : in std_logic_vector(1 downto 0);
            sel_sup : out std_logic_vector(1 downto 0);
            wr_acc : out std_logic; clr_acc : out std_logic;
            addr : out std_logic_vector(2 downto 0); wr_rf : out std_logic;
            op_alu : out std_logic_vector(2 downto 0); sel_inf : out std_logic;
            sh : out std_logic_vector(1 downto 0); out_en : out std_logic;
            g_dato : out std_logic_vector(7 downto 0);
            g_wr : out std_logic; g_en : out std_logic;
            fin : out std_logic; paso : out std_logic_vector(6 downto 0);
            ciclos : out std_logic_vector(15 downto 0)
        );
    end component;

    component datapath3_rtl is
        port (
            clk : in std_logic; rst : in std_logic;
            ext_data : in std_logic_vector(7 downto 0);
            sel_sup : in std_logic_vector(1 downto 0);
            wr_acc : in std_logic; clr_acc : in std_logic;
            addr : in std_logic_vector(2 downto 0); wr_rf : in std_logic;
            op_alu : in std_logic_vector(2 downto 0); sel_inf : in std_logic;
            sh : in std_logic_vector(1 downto 0); out_en : in std_logic;
            cero : out std_logic; dato_out : out std_logic_vector(7 downto 0);
            acc_q : out std_logic_vector(7 downto 0);
            rf_dout : out std_logic_vector(7 downto 0)
        );
    end component;

    component motor_pasos is
        port (
            clk : in std_logic; rst : in std_logic;
            carga : in std_logic; avance : in std_logic; sentido : in std_logic;
            dato_in : in std_logic_vector(7 downto 0);
            fase_cod : in std_logic_vector(1 downto 0);
            fases : out std_logic_vector(3 downto 0);
            paso_pulso : out std_logic; cero : out std_logic;
            pasos_rest : out std_logic_vector(7 downto 0)
        );
    end component;

    component divisor is
        generic (
            FRECUENCIA_ENTRADA_HZ : natural := 50_000_000;
            FRECUENCIA_SALIDA_HZ  : natural := 1
        );
        port (clk : in std_logic; rst : in std_logic; tick : out std_logic);
    end component;

    component pulsador is
        port (clk : in std_logic; rst : in std_logic;
              entrada : in std_logic; pulso : out std_logic);
    end component;

    component hex7seg is
        port (valor : in std_logic_vector(3 downto 0);
              salida : out std_logic_vector(6 downto 0));
    end component;

    type estado_t is (LISTO, ESPERA_B, ARRANQUE, EJECUTANDO, CAPTURA, FIN);

    signal rst_global : std_logic;
    signal pulso_run  : std_logic;
    signal pulso_dir  : std_logic;
    signal armado     : std_logic := '0';

    signal estado        : estado_t := LISTO;
    signal modo_reg      : std_logic_vector(1 downto 0) := "00";
    signal a_reg         : std_logic_vector(7 downto 0) := (others => '0');
    signal b_reg         : std_logic_vector(7 downto 0) := (others => '0');
    signal resultado_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal cero_reg      : std_logic := '0';
    signal sentido_reg   : std_logic := '0';

    signal rst_dp : std_logic;
    signal tick   : std_logic;
    signal enable : std_logic;

    signal sel_sup : std_logic_vector(1 downto 0);
    signal wr_acc  : std_logic;
    signal clr_acc : std_logic;
    signal addr    : std_logic_vector(2 downto 0);
    signal wr_rf   : std_logic;
    signal op_alu  : std_logic_vector(2 downto 0);
    signal sel_inf : std_logic;
    signal sh      : std_logic_vector(1 downto 0);
    signal out_en  : std_logic;
    signal paso    : std_logic_vector(6 downto 0);
    signal fin_control : std_logic;

    signal g_dato : std_logic_vector(7 downto 0);
    signal g_wr   : std_logic;
    signal g_en   : std_logic;
    signal motor_carga  : std_logic;
    signal motor_avance : std_logic;

    signal cero_dp    : std_logic;
    signal cero_motor : std_logic;
    signal cero_sel   : std_logic;
    signal ext_data   : std_logic_vector(7 downto 0);
    signal dato_out   : std_logic_vector(7 downto 0);
    signal fases      : std_logic_vector(3 downto 0);
    signal paso_pulso : std_logic;
    signal pasos_rest : std_logic_vector(7 downto 0);

    signal estado_visible : std_logic_vector(1 downto 0);
    signal modo_visible   : std_logic_vector(1 downto 0);
    signal a_mostrado     : std_logic_vector(7 downto 0);
    signal b_mostrado     : std_logic_vector(7 downto 0);
    signal ledr_s         : std_logic_vector(9 downto 0);
begin
    rst_global <= not key(3);

    u_pulsador_run : pulsador port map (
        clk => clk, rst => rst_global, entrada => not key(0), pulso => pulso_run);

    u_pulsador_dir : pulsador port map (
        clk => clk, rst => rst_global, entrada => not key(1), pulso => pulso_dir);

    -- Armado: no aceptar KEY0 si estaba pulsado al salir del reset
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

    -- KEY1 invierte el sentido del motor
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                sentido_reg <= '0';
            elsif pulso_dir = '1' then
                sentido_reg <= not sentido_reg;
            end if;
        end if;
    end process;

    rst_dp <= '1' when estado = LISTO or estado = ESPERA_B or
                       estado = ARRANQUE
              else '0';

    -- El motor necesita un tick lento para que las fases se vean;
    -- los programas del datapath corren a la frecuencia de la placa.
    u_divisor : divisor
        generic map (
            FRECUENCIA_ENTRADA_HZ => 50_000_000,
            FRECUENCIA_SALIDA_HZ  => FREC_MOTOR_HZ
        )
        port map (clk => clk, rst => rst_global, tick => tick);

    enable  <= tick when modo_reg = "10" else '1';
    cero_sel <= cero_motor when modo_reg = "10" else cero_dp;

    -- El periférico debe avanzar solo en el tick de habilitación;
    -- si no, el motor decrementaría el contador en cada ciclo de 50 MHz.
    motor_carga  <= g_wr and enable;
    motor_avance <= g_en and enable;

    -- FSM del envoltorio
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                estado        <= LISTO;
                modo_reg      <= "00";
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
                            if sw(9 downto 8) = "00" then
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
                        estado <= EJECUTANDO;

                    when EJECUTANDO =>
                        if fin_control = '1' then
                            estado <= CAPTURA;
                        end if;

                    when CAPTURA =>
                        if modo_reg = "10" then
                            resultado_reg <= pasos_rest;
                        else
                            resultado_reg <= dato_out;
                        end if;
                        cero_reg <= cero_sel;
                        estado   <= FIN;

                    when FIN =>
                        if pulso_run = '1' and armado = '1' then
                            modo_reg      <= sw(9 downto 8);
                            a_reg         <= sw(7 downto 0);
                            b_reg         <= (others => '0');
                            resultado_reg <= (others => '0');
                            cero_reg      <= '0';
                            if sw(9 downto 8) = "00" then
                                estado <= ESPERA_B;
                            else
                                estado <= ARRANQUE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- EXT1 según el micropaso (los rangos de cada programa no se solapan)
    process (paso, modo_reg, a_reg, b_reg)
    begin
        ext_data <= (others => '0');
        if not is_x(paso) then
            if modo_reg = "00" then
                case to_integer(unsigned(paso)) is
                    when 1 => ext_data <= x"01";
                    when 3 => ext_data <= a_reg;
                    when 5 => ext_data <= b_reg;
                    when others => null;
                end case;
            elsif modo_reg = "01" then
                case to_integer(unsigned(paso)) is
                    when 33 => ext_data <= x"01";
                    when 35 => ext_data <= a_reg;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    modo_visible <= sw(9 downto 8) when estado = LISTO else modo_reg;
    a_mostrado   <= sw(7 downto 0) when estado = LISTO else a_reg;
    b_mostrado   <= pasos_rest when modo_reg = "10" and estado /= LISTO else
                    sw(7 downto 0) when estado = ESPERA_B else
                    b_reg;

    ------------------------------------------------------------------
    -- Motor de microcódigo y los dos hardware que gobierna
    ------------------------------------------------------------------
    u_control : control_gen port map (
        clk => clk, rst => rst_dp, enable => enable, cero => cero_sel,
        modo => modo_reg,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf,
        sh => sh, out_en => out_en,
        g_dato => g_dato, g_wr => g_wr, g_en => g_en,
        fin => fin_control, paso => paso, ciclos => open
    );

    u_datapath : datapath3_rtl port map (
        clk => clk, rst => rst_dp, ext_data => ext_data,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf,
        sh => sh, out_en => out_en, cero => cero_dp, dato_out => dato_out,
        acc_q => open, rf_dout => open
    );

    u_motor : motor_pasos port map (
        clk => clk, rst => rst_dp, carga => motor_carga, avance => motor_avance,
        sentido => sentido_reg, dato_in => a_reg,
        fase_cod => g_dato(1 downto 0), fases => fases,
        paso_pulso => paso_pulso, cero => cero_motor, pasos_rest => pasos_rest
    );

    -- Interfaz con el driver del motor (señales de 3.3 V)
    step_out <= paso_pulso when modo_reg = "10" else '0';
    dir_out  <= sentido_reg;
    en_out   <= '0';                 -- A4988/DRV8825: ENABLE activo a nivel bajo
    ms_out   <= "000";               -- paso completo

    ------------------------------------------------------------------
    -- Salidas visibles
    ------------------------------------------------------------------
    process (estado)
    begin
        case estado is
            when LISTO    => estado_visible <= "00";
            when ESPERA_B => estado_visible <= "01";
            when FIN      => estado_visible <= "11";
            when others   => estado_visible <= "10";
        end case;
    end process;

    process (estado, estado_visible, modo_visible, cero_reg, sentido_reg,
             modo_reg, fases)
    begin
        ledr_s <= (others => '0');
        if modo_reg = "10" and estado /= LISTO then
            -- en modo motor, las cuatro fases se ven directamente
            ledr_s(3 downto 0) <= fases;
        else
            ledr_s(1 downto 0) <= modo_visible;
            ledr_s(3 downto 2) <= estado_visible;
        end if;
        ledr_s(4) <= cero_reg;
        if estado = FIN then
            ledr_s(5) <= '1';
        end if;
        if estado = ARRANQUE or estado = EJECUTANDO or estado = CAPTURA then
            ledr_s(6) <= '1';
        end if;
        if estado = ESPERA_B then
            ledr_s(7) <= '1';
        end if;
        ledr_s(8) <= sentido_reg;
    end process;
    ledr <= ledr_s;

    u_hex5 : hex7seg port map (valor => a_mostrado(7 downto 4), salida => hex5);
    u_hex4 : hex7seg port map (valor => a_mostrado(3 downto 0), salida => hex4);
    u_hex3 : hex7seg port map (valor => b_mostrado(7 downto 4), salida => hex3);
    u_hex2 : hex7seg port map (valor => b_mostrado(3 downto 0), salida => hex2);
    u_hex1 : hex7seg port map (valor => resultado_reg(7 downto 4), salida => hex1);
    u_hex0 : hex7seg port map (valor => resultado_reg(3 downto 0), salida => hex0);
end architecture;
