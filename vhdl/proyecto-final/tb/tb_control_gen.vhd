-- ============================================================
-- Testbench del motor de microcódigo genérico.
-- Comprueba, para los tres programas, la secuencia de pasos y
-- los saltos condicionales por el flag "cero", además de la
-- habilitación "enable" y las salidas genéricas del motor.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.microcodigo_pkg.all;

entity tb_control_gen is
end entity;

architecture tb of tb_control_gen is
    component control_gen is
        generic (
            PROGRAMA : rom_t := ROM
        );
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            enable  : in  std_logic;
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
            g_dato  : out std_logic_vector(ANCHO_DATO - 1 downto 0);
            g_wr    : out std_logic;
            g_en    : out std_logic;
            fin     : out std_logic;
            paso    : out std_logic_vector(ANCHO_PASO - 1 downto 0);
            ciclos  : out std_logic_vector(15 downto 0)
        );
    end component;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal enable  : std_logic := '1';
    signal cero    : std_logic := '1';
    signal modo    : std_logic_vector(1 downto 0) := "00";
    signal sel_sup : std_logic_vector(1 downto 0);
    signal wr_acc  : std_logic;
    signal clr_acc : std_logic;
    signal addr    : std_logic_vector(2 downto 0);
    signal wr_rf   : std_logic;
    signal op_alu  : std_logic_vector(2 downto 0);
    signal sel_inf : std_logic;
    signal sh      : std_logic_vector(1 downto 0);
    signal out_en  : std_logic;
    signal g_dato  : std_logic_vector(ANCHO_DATO - 1 downto 0);
    signal g_wr    : std_logic;
    signal g_en    : std_logic;
    signal fin     : std_logic;
    signal paso    : std_logic_vector(ANCHO_PASO - 1 downto 0);
    signal ciclos  : std_logic_vector(15 downto 0);

    type seq_t is array (natural range <>) of natural;

    -- cero = '1' en todos los puntos de salto condicional
    constant SEQ_SHIFT_ADD : seq_t :=
        (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 15, 16, 17, 18, 20);
    constant SEQ_POPCOUNT : seq_t :=
        (32, 33, 34, 35, 36, 37, 38, 39, 40, 44, 45, 48);
    constant SEQ_MOTOR : seq_t := (64, 65, 69);
begin
    dut : control_gen port map (
        clk => clk, rst => rst, enable => enable, cero => cero, modo => modo,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
        g_dato => g_dato, g_wr => g_wr, g_en => g_en,
        fin => fin, paso => paso, ciclos => ciclos
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure reiniciar(constant m : in std_logic_vector(1 downto 0)) is
        begin
            modo   <= m;
            enable <= '1';
            rst    <= '1';
            tick;
            rst    <= '0';
        end procedure;

        procedure comprobar_secuencia(constant s : in seq_t) is
        begin
            for i in s'range loop
                assert to_integer(unsigned(paso)) = s(i)
                    report "control_gen: paso " & integer'image(i) &
                           " = " & integer'image(to_integer(unsigned(paso))) &
                           ", esperaba " & integer'image(s(i))
                    severity failure;
                tick;
            end loop;
            assert fin = '1'
                report "control_gen: no llegó a fin tras la secuencia esperada"
                severity failure;
        end procedure;
    begin
        ------------------------------------------------------------------
        -- Programa 0: shift-add
        ------------------------------------------------------------------
        cero <= '1';
        reiniciar("00");
        comprobar_secuencia(SEQ_SHIFT_ADD);
        assert out_en = '1'
            report "control_gen: shift-add no habilitó la salida al fin"
            severity failure;

        ------------------------------------------------------------------
        -- Programa 1: popcount
        ------------------------------------------------------------------
        reiniciar("01");
        comprobar_secuencia(SEQ_POPCOUNT);
        assert out_en = '1'
            report "control_gen: popcount no habilitó la salida al fin"
            severity failure;

        ------------------------------------------------------------------
        -- Programa 2: motor NEMA 17 (cero = '1' corta en el primer paso)
        ------------------------------------------------------------------
        reiniciar("10");
        assert g_wr = '1'
            report "control_gen: el paso 64 debe cargar los pasos (g_wr)"
            severity failure;
        comprobar_secuencia(SEQ_MOTOR);

        reiniciar("10");
        assert to_integer(unsigned(paso)) = 64
            report "control_gen: base del motor incorrecta" severity failure;
        tick;                                    -- 64 -> 65
        assert to_integer(unsigned(paso)) = 65
            report "control_gen: primera fase incorrecta" severity failure;
        assert g_en = '1' and g_dato = x"00"
            report "control_gen: fase 0 no generada" severity failure;
        cero <= '0';
        tick;                                    -- 65 -> 66
        assert to_integer(unsigned(paso)) = 66 and g_dato = x"01"
            report "control_gen: fase 1 no generada" severity failure;
        tick;                                    -- 66 -> 67
        assert to_integer(unsigned(paso)) = 67 and g_dato = x"02"
            report "control_gen: fase 2 no generada" severity failure;
        tick;                                    -- 67 -> 68
        assert to_integer(unsigned(paso)) = 68 and g_dato = x"03"
            report "control_gen: fase 3 no generada" severity failure;
        tick;                                    -- 68 -> 65 (bucle)
        assert to_integer(unsigned(paso)) = 65
            report "control_gen: el motor no repitió la secuencia" severity failure;

        ------------------------------------------------------------------
        -- enable = '0' debe mantener el paso
        ------------------------------------------------------------------
        enable <= '0';
        tick;
        assert to_integer(unsigned(paso)) = 65
            report "control_gen: avanzó con enable = '0'" severity failure;
        assert ciclos /= x"0000"
            report "control_gen: contador de ciclos no avanzó" severity failure;

        report "tb_control_gen: OK" severity note;
        wait;
    end process;
end architecture;
