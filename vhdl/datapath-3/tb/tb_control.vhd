-- ============================================================
-- Testbench de la unidad de control: comprueba la secuencia de
-- pasos (direcciones de microcódigo) de los 4 algoritmos.
--   * Con cero = '1': la secuencia debe coincidir con las
--     tablas §8 del plan y llegar a "fin" en la dirección exacta.
--   * Con cero = '0': ningún algoritmo debe terminar (los bucles
--     se repiten) en 100 microciclos.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_control is
end entity;

architecture tb of tb_control is
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

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
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
    signal fin     : std_logic;
    signal paso    : std_logic_vector(6 downto 0);
    signal ciclos  : std_logic_vector(15 downto 0);

    type seq_t is array (natural range <>) of natural;

    -- secuencias esperadas con cero = '1' (plan §8)
    constant SEQ_EXP1 : seq_t := (0, 1, 2, 3, 4, 5, 6, 7, 8, 10);
    constant SEQ_EXP2 : seq_t :=
        (32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 63);
    constant SEQ_EXP3 : seq_t :=
        (64, 65, 66, 67, 68, 69, 70, 71, 78);
    constant SEQ_EXP4 : seq_t :=
        (96, 97, 98, 99, 100, 101, 102, 103, 117);
begin
    dut : control port map (
        clk => clk, rst => rst, cero => cero, modo => modo,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
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
            modo <= m;
            rst  <= '1';
            tick;
            rst  <= '0';
        end procedure;

        procedure comprobar_secuencia(constant s : in seq_t) is
        begin
            for i in s'range loop
                assert to_integer(unsigned(paso)) = s(i)
                    report "control: paso " & integer'image(i) &
                           " = " & integer'image(to_integer(unsigned(paso))) &
                           ", esperaba " & integer'image(s(i))
                    severity failure;
                tick;
            end loop;
            assert fin = '1'
                report "control: no llegó a fin tras la secuencia esperada"
                severity failure;
        end procedure;

        procedure comprobar_bucle_infinito is
        begin
            for i in 1 to 100 loop
                assert fin = '0'
                    report "control: terminó con cero = 0 (no debería)"
                    severity failure;
                tick;
            end loop;
        end procedure;
    begin
        -- con cero = '1': secuencias exactas
        cero <= '1';

        reiniciar("00");
        comprobar_secuencia(SEQ_EXP1);

        reiniciar("01");
        comprobar_secuencia(SEQ_EXP2);

        reiniciar("10");
        comprobar_secuencia(SEQ_EXP3);

        reiniciar("11");
        comprobar_secuencia(SEQ_EXP4);

        -- con cero = '0': los bucles no terminan
        cero <= '0';

        reiniciar("00");
        comprobar_bucle_infinito;

        reiniciar("01");
        comprobar_bucle_infinito;

        reiniciar("10");
        comprobar_bucle_infinito;

        reiniciar("11");
        comprobar_bucle_infinito;

        report "tb_control: OK" severity note;
        wait;
    end process;
end architecture;
