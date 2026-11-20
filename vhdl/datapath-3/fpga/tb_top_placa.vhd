-- ============================================================
-- Testbench autochequeado de top_placa (datapath-3)
--
-- Comprueba el envoltorio de placa sin DE10-Standard:
--   - reset y estado inicial
--   - suma, factorial, multiplicación y Fibonacci
--   - captura del resultado (dato_out) y cero
--   - operandos A/B y modo latcheados
--   - una pulsación de KEY0 = una ejecución
--   - reset en mitad de una ejecución
--   - KEY0 pulsado al salir del reset no dispara nada
--   - cambio de switches durante la ejecución no altera el resultado
--
-- No usa reloj concurrente: el reloj se genera dentro del proceso
-- estimulador para que GHDL pueda vaciar la agenda al terminar.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_placa is
end entity;

architecture simulacion of tb_top_placa is
    constant PERIODO : time := 10 ns;
    constant TIMEOUT : natural := 1000;

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(3 downto 0) := (others => '1');
    signal sw   : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr : std_logic_vector(9 downto 0);
    signal hex0 : std_logic_vector(6 downto 0);
    signal hex1 : std_logic_vector(6 downto 0);
    signal hex2 : std_logic_vector(6 downto 0);
    signal hex3 : std_logic_vector(6 downto 0);
    signal hex4 : std_logic_vector(6 downto 0);
    signal hex5 : std_logic_vector(6 downto 0);

    component top_placa is
        port (
            clk  : in  std_logic;
            key  : in  std_logic_vector(3 downto 0);
            sw   : in  std_logic_vector(9 downto 0);
            ledr : out std_logic_vector(9 downto 0);
            hex0 : out std_logic_vector(6 downto 0);
            hex1 : out std_logic_vector(6 downto 0);
            hex2 : out std_logic_vector(6 downto 0);
            hex3 : out std_logic_vector(6 downto 0);
            hex4 : out std_logic_vector(6 downto 0);
            hex5 : out std_logic_vector(6 downto 0)
        );
    end component;

    -- Patrones de hex7seg: activo a nivel bajo (0 enciende).
    function patron(constant n : natural) return std_logic_vector is
        variable r : std_logic_vector(6 downto 0);
    begin
        case n is
            when 0  => r := "1000000";
            when 1  => r := "1111001";
            when 2  => r := "0100100";
            when 3  => r := "0110000";
            when 4  => r := "0011001";
            when 5  => r := "0010010";
            when 6  => r := "0000010";
            when 7  => r := "1111000";
            when 8  => r := "0000000";
            when 9  => r := "0010000";
            when 10 => r := "0001000";
            when 11 => r := "0000011";
            when 12 => r := "1000110";
            when 13 => r := "0100001";
            when 14 => r := "0000110";
            when 15 => r := "0001110";
            when others => r := "1111111";
        end case;
        return r;
    end function;

    procedure ciclos(constant n : natural;
                     signal clk : inout std_logic) is
    begin
        for i in 1 to n loop
            clk <= '0';
            wait for PERIODO / 2;
            clk <= '1';
            wait for PERIODO / 2;
        end loop;
    end procedure;

    procedure reset_placa(signal key : inout std_logic_vector(3 downto 0);
                          signal clk : inout std_logic) is
    begin
        key(3) <= '0';
        ciclos(3, clk);
        key(3) <= '1';
        ciclos(3, clk);
    end procedure;

    procedure pulsar(constant tecla : natural;
                     signal key : inout std_logic_vector(3 downto 0);
                     signal clk : inout std_logic) is
    begin
        key(tecla) <= '0';
        ciclos(2, clk);
        key(tecla) <= '1';
        ciclos(2, clk);
    end procedure;

    procedure aplicar_sw(constant modo : natural;
                         constant dato : natural;
                         signal sw : out std_logic_vector(9 downto 0)) is
    begin
        assert modo <= 3
            report "modo fuera de rango (0..3)"
            severity failure;
        assert dato <= 255
            report "dato fuera de rango (0..255)"
            severity failure;
        sw <= std_logic_vector(to_unsigned(modo, 2)) &
              std_logic_vector(to_unsigned(dato, 8));
        wait for 1 ns;
    end procedure;

    procedure esperar_fin(signal ledr : in std_logic_vector(9 downto 0);
                          signal clk : inout std_logic;
                          constant msg : string) is
    begin
        for i in 1 to TIMEOUT loop
            ciclos(1, clk);
            exit when ledr(5) = '1';
        end loop;
        assert ledr(5) = '1'
            report msg & ": no se llego al estado FIN"
            severity failure;
        wait for 1 ns;
    end procedure;

    procedure comprobar_valor8(constant valor : natural;
                               constant hi : std_logic_vector(6 downto 0);
                               constant lo : std_logic_vector(6 downto 0);
                               constant msg : string) is
    begin
        assert valor <= 255
            report msg & ": valor fuera de rango"
            severity failure;
        assert hi = patron(valor / 16)
            report msg & ": nibble alto incorrecto"
            severity failure;
        assert lo = patron(valor mod 16)
            report msg & ": nibble bajo incorrecto"
            severity failure;
    end procedure;

    procedure comprobar_ab(constant a : natural;
                           constant b : natural;
                           signal hex5 : in std_logic_vector(6 downto 0);
                           signal hex4 : in std_logic_vector(6 downto 0);
                           signal hex3 : in std_logic_vector(6 downto 0);
                           signal hex2 : in std_logic_vector(6 downto 0);
                           constant msg : string) is
    begin
        comprobar_valor8(a, hex5, hex4, msg & " (A)");
        comprobar_valor8(b, hex3, hex2, msg & " (B)");
    end procedure;

    procedure comprobar_resultado(constant valor : natural;
                                  signal hex1 : in std_logic_vector(6 downto 0);
                                  signal hex0 : in std_logic_vector(6 downto 0);
                                  constant msg : string) is
    begin
        comprobar_valor8(valor, hex1, hex0, msg & " (resultado)");
    end procedure;

    procedure comprobar_leds(constant modo : natural;
                             constant estado : natural;
                             constant cero : std_logic;
                             constant espera_b : std_logic;
                             constant ocupado : std_logic;
                             constant valido : std_logic;
                             signal ledr : in std_logic_vector(9 downto 0);
                             constant msg : string) is
    begin
        assert modo <= 3
            report msg & ": modo de test fuera de rango"
            severity failure;
        assert estado <= 3
            report msg & ": estado de test fuera de rango"
            severity failure;

        assert ledr(1 downto 0) = std_logic_vector(to_unsigned(modo, 2))
            report msg & ": LEDR[1:0] (modo) incorrecto"
            severity failure;
        assert ledr(3 downto 2) = std_logic_vector(to_unsigned(estado, 2))
            report msg & ": LEDR[3:2] (estado) incorrecto"
            severity failure;
        assert ledr(4) = cero
            report msg & ": LEDR[4] (cero) incorrecto"
            severity failure;
        assert ledr(5) = valido
            report msg & ": LEDR[5] (valido) incorrecto"
            severity failure;
        assert ledr(6) = ocupado
            report msg & ": LEDR[6] (ocupado) incorrecto"
            severity failure;
        assert ledr(7) = espera_b
            report msg & ": LEDR[7] (espera B) incorrecto"
            severity failure;
        assert ledr(8) = valido
            report msg & ": LEDR[8] (out_en) incorrecto"
            severity failure;
        assert ledr(9) = '0'
            report msg & ": LEDR[9] debe estar apagado"
            severity failure;
    end procedure;

begin
    dut : top_placa
        port map (
            clk  => clk,
            key  => key,
            sw   => sw,
            ledr => ledr,
            hex0 => hex0,
            hex1 => hex1,
            hex2 => hex2,
            hex3 => hex3,
            hex4 => hex4,
            hex5 => hex5
        );

    stim : process
    begin
        ------------------------------------------------------------------
        -- 0. Reset inicial
        ------------------------------------------------------------------
        key <= (others => '1');
        sw  <= (others => '0');
        wait for 1 ns;

        reset_placa(key, clk);
        wait for 1 ns;

        comprobar_leds(0, 0, '0', '0', '0', '0', ledr, "reset inicial");
        comprobar_ab(0, 0, hex5, hex4, hex3, hex2, "reset inicial");
        comprobar_resultado(0, hex1, hex0, "reset inicial");

        ------------------------------------------------------------------
        -- 1. Suma S(5) = 15
        ------------------------------------------------------------------
        aplicar_sw(0, 5, sw);
        comprobar_ab(5, 0, hex5, hex4, hex3, hex2, "suma 5 en LISTO");
        comprobar_resultado(0, hex1, hex0, "suma 5 en LISTO");
        comprobar_leds(0, 0, '0', '0', '0', '0', ledr, "suma 5 en LISTO");

        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "suma S(5)");
        comprobar_leds(0, 3, '0', '0', '0', '1', ledr, "suma S(5)");
        comprobar_ab(5, 0, hex5, hex4, hex3, hex2, "suma S(5)");
        comprobar_resultado(15, hex1, hex0, "suma S(5)");

        ------------------------------------------------------------------
        -- 2. Suma S(1) = 1 y S(3) = 6
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(0, 1, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "suma S(1)");
        comprobar_resultado(1, hex1, hex0, "suma S(1)");
        comprobar_ab(1, 0, hex5, hex4, hex3, hex2, "suma S(1)");

        reset_placa(key, clk);
        aplicar_sw(0, 3, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "suma S(3)");
        comprobar_resultado(6, hex1, hex0, "suma S(3)");
        comprobar_ab(3, 0, hex5, hex4, hex3, hex2, "suma S(3)");

        ------------------------------------------------------------------
        -- 3. Factorial 5! = 120 y 1! = 1
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(1, 5, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "factorial 5");
        comprobar_leds(1, 3, '0', '0', '0', '1', ledr, "factorial 5");
        comprobar_ab(5, 0, hex5, hex4, hex3, hex2, "factorial 5");
        comprobar_resultado(120, hex1, hex0, "factorial 5");

        reset_placa(key, clk);
        aplicar_sw(1, 1, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "factorial 1");
        comprobar_resultado(1, hex1, hex0, "factorial 1");
        comprobar_ab(1, 0, hex5, hex4, hex3, hex2, "factorial 1");

        ------------------------------------------------------------------
        -- 4. Multiplicacion 4 x 3 = 12
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(2, 4, sw);
        pulsar(0, key, clk);
        comprobar_leds(2, 1, '0', '1', '0', '0', ledr, "mult 4x3 espera B");
        comprobar_ab(4, 4, hex5, hex4, hex3, hex2, "mult 4x3 espera B");

        aplicar_sw(2, 3, sw);
        comprobar_ab(4, 3, hex5, hex4, hex3, hex2, "mult 4x3 B en vivo");

        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "mult 4x3");
        comprobar_leds(2, 3, '0', '0', '0', '1', ledr, "mult 4x3");
        comprobar_ab(4, 3, hex5, hex4, hex3, hex2, "mult 4x3");
        comprobar_resultado(12, hex1, hex0, "mult 4x3");

        ------------------------------------------------------------------
        -- 5. Multiplicacion 15 x 15 = 225
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(2, 15, sw);
        pulsar(0, key, clk);
        aplicar_sw(2, 15, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "mult 15x15");
        comprobar_ab(15, 15, hex5, hex4, hex3, hex2, "mult 15x15");
        comprobar_resultado(225, hex1, hex0, "mult 15x15");

        ------------------------------------------------------------------
        -- 6. Multiplicacion con resultado cero: 7 x 0 y 0 x 5
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(2, 7, sw);
        pulsar(0, key, clk);
        aplicar_sw(2, 0, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "mult 7x0");
        comprobar_leds(2, 3, '1', '0', '0', '1', ledr, "mult 7x0");
        comprobar_ab(7, 0, hex5, hex4, hex3, hex2, "mult 7x0");
        comprobar_resultado(0, hex1, hex0, "mult 7x0");

        reset_placa(key, clk);
        aplicar_sw(2, 0, sw);
        pulsar(0, key, clk);
        aplicar_sw(2, 5, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "mult 0x5");
        comprobar_leds(2, 3, '1', '0', '0', '1', ledr, "mult 0x5");
        comprobar_ab(0, 5, hex5, hex4, hex3, hex2, "mult 0x5");
        comprobar_resultado(0, hex1, hex0, "mult 0x5");

        ------------------------------------------------------------------
        -- 7. Fibonacci F(0), F(1), F(7), F(13)
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(3, 0, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "fibonacci 0");
        comprobar_leds(3, 3, '1', '0', '0', '1', ledr, "fibonacci 0");
        comprobar_ab(0, 0, hex5, hex4, hex3, hex2, "fibonacci 0");
        comprobar_resultado(0, hex1, hex0, "fibonacci 0");

        reset_placa(key, clk);
        aplicar_sw(3, 1, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "fibonacci 1");
        comprobar_resultado(1, hex1, hex0, "fibonacci 1");
        comprobar_ab(1, 0, hex5, hex4, hex3, hex2, "fibonacci 1");

        reset_placa(key, clk);
        aplicar_sw(3, 7, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "fibonacci 7");
        comprobar_resultado(13, hex1, hex0, "fibonacci 7");
        comprobar_ab(7, 0, hex5, hex4, hex3, hex2, "fibonacci 7");

        reset_placa(key, clk);
        aplicar_sw(3, 13, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "fibonacci 13");
        comprobar_resultado(233, hex1, hex0, "fibonacci 13");
        comprobar_ab(13, 0, hex5, hex4, hex3, hex2, "fibonacci 13");

        ------------------------------------------------------------------
        -- 8. Resultado latcheado: cambiar SW en FIN no lo modifica
        ------------------------------------------------------------------
        aplicar_sw(0, 5, sw);
        wait for 1 ns;
        comprobar_leds(3, 3, '0', '0', '0', '1', ledr, "resultado latcheado");
        comprobar_ab(13, 0, hex5, hex4, hex3, hex2, "resultado latcheado");
        comprobar_resultado(233, hex1, hex0, "resultado latcheado");

        ------------------------------------------------------------------
        -- 9. Una pulsacion = una ejecucion: mantener KEY0 no repite
        ------------------------------------------------------------------
        key(0) <= '0';
        ciclos(2, clk);
        esperar_fin(ledr, clk, "pulsacion mantenida (primera ejecucion)");
        comprobar_leds(0, 3, '0', '0', '0', '1', ledr, "pulsacion mantenida");
        comprobar_resultado(15, hex1, hex0, "pulsacion mantenida");

        ciclos(20, clk);
        comprobar_leds(0, 3, '0', '0', '0', '1', ledr, "KEY0 mantenido");
        comprobar_resultado(15, hex1, hex0, "KEY0 mantenido");

        key(0) <= '1';
        ciclos(3, clk);

        ------------------------------------------------------------------
        -- 10. Cambiar modo y operandos durante la ejecucion no afecta
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(0, 5, sw);
        pulsar(0, key, clk);
        aplicar_sw(1, 3, sw);
        esperar_fin(ledr, clk, "cambio de SW en ejecucion");
        comprobar_leds(0, 3, '0', '0', '0', '1', ledr, "cambio de SW en ejecucion");
        comprobar_ab(5, 0, hex5, hex4, hex3, hex2, "cambio de SW en ejecucion");
        comprobar_resultado(15, hex1, hex0, "cambio de SW en ejecucion");

        ------------------------------------------------------------------
        -- 11. Reset en mitad de una ejecucion
        ------------------------------------------------------------------
        reset_placa(key, clk);
        aplicar_sw(3, 13, sw);
        pulsar(0, key, clk);
        ciclos(5, clk);
        reset_placa(key, clk);
        wait for 1 ns;

        comprobar_leds(3, 0, '0', '0', '0', '0', ledr, "reset en ejecucion");
        comprobar_ab(13, 0, hex5, hex4, hex3, hex2, "reset en ejecucion");
        comprobar_resultado(0, hex1, hex0, "reset en ejecucion");

        aplicar_sw(0, 1, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "operacion tras reset en ejecucion");
        comprobar_resultado(1, hex1, hex0, "operacion tras reset en ejecucion");

        ------------------------------------------------------------------
        -- 12. KEY0 pulsado al salir del reset no dispara una ejecucion
        ------------------------------------------------------------------
        key(0) <= '0';
        reset_placa(key, clk);
        ciclos(5, clk);
        comprobar_leds(0, 0, '0', '0', '0', '0', ledr, "KEY0 en reset");
        comprobar_resultado(0, hex1, hex0, "KEY0 en reset");

        key(0) <= '1';
        ciclos(3, clk);
        comprobar_leds(0, 0, '0', '0', '0', '0', ledr, "KEY0 tras reset");

        aplicar_sw(0, 1, sw);
        pulsar(0, key, clk);
        esperar_fin(ledr, clk, "operacion tras KEY0 en reset");
        comprobar_resultado(1, hex1, hex0, "operacion tras KEY0 en reset");

        ------------------------------------------------------------------
        -- Fin
        ------------------------------------------------------------------
        report "tb_top_placa: todas las comprobaciones OK"
            severity note;
        wait;
    end process;
end architecture;
