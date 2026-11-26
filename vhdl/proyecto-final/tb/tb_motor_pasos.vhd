-- ============================================================
-- Testbench del controlador del motor NEMA 17 integrado con el
-- motor de microcódigo genérico. Comprueba la secuencia de fases,
-- el sentido de giro, el contador de pasos y el flag "cero".
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.microcodigo_pkg.all;

entity tb_motor_pasos is
end entity;

architecture tb of tb_motor_pasos is
    component control_gen is
        generic (PROGRAMA : rom_t := ROM);
        port (
            clk : in std_logic; rst : in std_logic; enable : in std_logic;
            cero : in std_logic; modo : in std_logic_vector(1 downto 0);
            sel_sup : out std_logic_vector(1 downto 0);
            wr_acc : out std_logic; clr_acc : out std_logic;
            addr : out std_logic_vector(2 downto 0); wr_rf : out std_logic;
            op_alu : out std_logic_vector(2 downto 0); sel_inf : out std_logic;
            sh : out std_logic_vector(1 downto 0); out_en : out std_logic;
            g_dato : out std_logic_vector(ANCHO_DATO - 1 downto 0);
            g_wr : out std_logic; g_en : out std_logic;
            fin : out std_logic; paso : out std_logic_vector(ANCHO_PASO - 1 downto 0);
            ciclos : out std_logic_vector(15 downto 0)
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

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal enable     : std_logic := '1';
    signal modo       : std_logic_vector(1 downto 0) := "10";
    signal sentido    : std_logic := '0';
    signal dato_in    : std_logic_vector(7 downto 0) := x"04";
    signal cero       : std_logic;
    signal sel_sup    : std_logic_vector(1 downto 0);
    signal wr_acc     : std_logic;
    signal clr_acc    : std_logic;
    signal addr       : std_logic_vector(2 downto 0);
    signal wr_rf      : std_logic;
    signal op_alu     : std_logic_vector(2 downto 0);
    signal sel_inf    : std_logic;
    signal sh         : std_logic_vector(1 downto 0);
    signal out_en     : std_logic;
    signal g_dato     : std_logic_vector(ANCHO_DATO - 1 downto 0);
    signal g_wr       : std_logic;
    signal g_en       : std_logic;
    signal fin        : std_logic;
    signal paso       : std_logic_vector(ANCHO_PASO - 1 downto 0);
    signal ciclos     : std_logic_vector(15 downto 0);
    signal fases      : std_logic_vector(3 downto 0);
    signal paso_pulso : std_logic;
    signal pasos_rest : std_logic_vector(7 downto 0);

    type fases_t is array (0 to 15) of std_logic_vector(3 downto 0);
    type seq_t is array (natural range <>) of std_logic_vector(3 downto 0);

    constant ADELANTE4 : seq_t := (x"3", x"6", x"C", x"9");
    constant ATRAS4    : seq_t := (x"9", x"C", x"6", x"3");
    constant ADELANTE8 : seq_t := (x"3", x"6", x"C", x"9",
                                  x"3", x"6", x"C", x"9");
begin
    u_control : control_gen port map (
        clk => clk, rst => rst, enable => enable, cero => cero, modo => modo,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf,
        sh => sh, out_en => out_en, g_dato => g_dato, g_wr => g_wr, g_en => g_en,
        fin => fin, paso => paso, ciclos => ciclos
    );

    u_motor : motor_pasos port map (
        clk => clk, rst => rst, carga => g_wr, avance => g_en,
        sentido => sentido, dato_in => dato_in,
        fase_cod => g_dato(1 downto 0), fases => fases,
        paso_pulso => paso_pulso, cero => cero, pasos_rest => pasos_rest
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure ejecutar(constant pasos : in std_logic_vector(7 downto 0);
                           constant dir : in std_logic;
                           constant esperado : in seq_t) is
            variable observadas : fases_t := (others => (others => '0'));
            variable k          : natural := 0;
            variable n          : natural := 0;
        begin
            dato_in <= pasos;
            sentido <= dir;
            rst <= '1';
            tick;
            rst <= '0';
            while fin = '0' and n < 200 loop
                tick;
                n := n + 1;
                if g_en = '1' and paso_pulso = '1' and k < 16 then
                    observadas(k) := fases;
                    k := k + 1;
                end if;
            end loop;
            tick;

            assert fin = '1'
                report "tb_motor_pasos: el programa del motor no terminó"
                severity failure;
            assert pasos_rest = x"00"
                report "tb_motor_pasos: quedan pasos sin ejecutar"
                severity failure;
            assert k = esperado'length
                report "tb_motor_pasos: se generaron " & integer'image(k) &
                       " pasos, esperaba " & integer'image(esperado'length)
                severity failure;
            for i in esperado'range loop
                assert observadas(i) = esperado(i)
                    report "tb_motor_pasos: fase " & integer'image(i) &
                           " = " & integer'image(to_integer(unsigned(observadas(i)))) &
                           ", esperaba " & integer'image(to_integer(unsigned(esperado(i))))
                    severity failure;
            end loop;
            report "tb_motor_pasos: " & integer'image(to_integer(unsigned(pasos))) &
                   " pasos, sentido " & std_logic'image(dir) &
                   ", " & integer'image(k) & " fases en " &
                   integer'image(n) & " microciclos"
                severity note;
        end procedure;
    begin
        enable <= '1';
        modo   <= "10";

        ejecutar(x"04", '0', ADELANTE4);
        ejecutar(x"04", '1', ATRAS4);
        ejecutar(x"08", '0', ADELANTE8);
        ejecutar(x"01", '0', ADELANTE4(0 to 0));
        ejecutar(x"00", '0', ADELANTE4(0 to -1));

        report "tb_motor_pasos: OK" severity note;
        wait;
    end process;
end architecture;
