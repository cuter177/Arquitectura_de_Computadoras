-- ============================================================
-- Testbench del envoltorio de placa de datapath-2
--
-- Verifica, sin placa, el cableado y la FSM del top_placa:
--   - suma S(5), S(1) y S(3);
--   - factorial 5! y 3!;
--   - multiplicación 4x3, 15x15, 7x0 y 0x5;
--   - visualización en vivo de A y B antes de capturar;
--   - resultado latcheado tras FIN;
--   - un pulso de KEY0 = una ejecución (aunque se mantenga pulsado);
--   - reset en marcha;
--   - modo 11 inválido: no arranca;
--   - cambio de modo durante la ejecución: se ignora;
--   - armado del pulsador tras el reset.
--
-- El reloj se genera dentro del proceso para que la agenda de GHDL
-- pueda vaciarse al terminar. Los displays se comparan contra los
-- patrones reales de hex7seg (activo a nivel bajo).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_top_placa is
end entity;

architecture tb of tb_top_placa is
    constant PERIODO : time := 10 ns;

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

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(3 downto 0) := "1111";
    signal sw   : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr : std_logic_vector(9 downto 0);
    signal hex0, hex1, hex2 : std_logic_vector(6 downto 0);
    signal hex3, hex4, hex5 : std_logic_vector(6 downto 0);

    -- Patrón de 7 segmentos (ánodo común: 0 enciende)
    function patron(constant n : natural) return std_logic_vector is
        type tabla_t is array (0 to 15) of std_logic_vector(6 downto 0);
        constant TABLA : tabla_t := (
            "1000000",  -- 0
            "1111001",  -- 1
            "0100100",  -- 2
            "0110000",  -- 3
            "0011001",  -- 4
            "0010010",  -- 5
            "0000010",  -- 6
            "1111000",  -- 7
            "0000000",  -- 8
            "0010000",  -- 9
            "0001000",  -- A
            "0000011",  -- b
            "1000110",  -- C
            "0100001",  -- d
            "0000110",  -- E
            "0001110"   -- F
        );
    begin
        return TABLA(n);
    end function;
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
        procedure ciclos(constant n : in natural) is
        begin
            for i in 1 to n loop
                clk <= '0';
                wait for PERIODO / 2;
                clk <= '1';
                wait for PERIODO / 2;
            end loop;
        end procedure;

        procedure comprobar_valor8(
            constant valor : in natural;
            constant hi    : in std_logic_vector(6 downto 0);
            constant lo    : in std_logic_vector(6 downto 0);
            constant msg   : in string
        ) is
        begin
            assert hi = patron(valor / 16)
                report "tb_top_placa: " & msg & " (nibble alto)"
                severity failure;
            assert lo = patron(valor mod 16)
                report "tb_top_placa: " & msg & " (nibble bajo)"
                severity failure;
        end procedure;

        procedure comprobar_ab(
            constant a   : in natural;
            constant b   : in natural;
            constant msg : in string
        ) is
        begin
            comprobar_valor8(a, hex5, hex4, msg & " A");
            comprobar_valor8(b, hex3, hex2, msg & " B");
        end procedure;

        procedure comprobar_resultado(
            constant r   : in natural;
            constant msg : in string
        ) is
        begin
            comprobar_valor8(r, hex1, hex0, msg & " resultado");
        end procedure;

        procedure comprobar_leds(
            constant modo   : in natural;
            constant estado : in natural;
            constant cero   : in std_logic;
            constant valido : in std_logic;
            constant msg    : in string
        ) is
        begin
            assert ledr(1 downto 0) = std_logic_vector(to_unsigned(modo, 2))
                report "tb_top_placa: " & msg & " (modo)"
                severity failure;
            assert ledr(3 downto 2) = std_logic_vector(to_unsigned(estado, 2))
                report "tb_top_placa: " & msg & " (estado)"
                severity failure;
            assert ledr(4) = cero
                report "tb_top_placa: " & msg & " (cero)"
                severity failure;
            assert ledr(5) = valido
                report "tb_top_placa: " & msg & " (válido)"
                severity failure;
        end procedure;

        procedure aplicar_sw(
            constant modo : in natural;
            constant dato : in natural
        ) is
        begin
            sw <= std_logic_vector(to_unsigned(modo, 2)) &
                  std_logic_vector(to_unsigned(dato, 8));
            wait for 1 ns;
        end procedure;

        procedure pulsar(constant tecla : in natural) is
        begin
            key(tecla) <= '0';
            ciclos(2);
            key(tecla) <= '1';
            ciclos(2);
        end procedure;

        procedure esperar_fin(constant timeout : in natural) is
        begin
            for i in 1 to timeout loop
                ciclos(1);
                exit when ledr(5) = '1';
            end loop;
            assert ledr(5) = '1'
                report "tb_top_placa: timeout esperando FIN"
                severity failure;
        end procedure;

        procedure reset_placa is
        begin
            key(3) <= '0';
            ciclos(3);
            key(3) <= '1';
            ciclos(2);
        end procedure;
    begin
        ----------------------------------------------------------------
        -- 1) Reset y estado inicial
        ----------------------------------------------------------------
        key <= "1111";
        sw  <= (others => '0');
        wait for 1 ns;
        reset_placa;
        comprobar_leds(0, 0, '0', '0', "tras reset");
        comprobar_valor8(0, hex5, hex4, "tras reset A");
        comprobar_valor8(0, hex3, hex2, "tras reset B");
        comprobar_valor8(0, hex1, hex0, "tras reset resultado");

        ----------------------------------------------------------------
        -- 2) Suma S(5) = 15
        ----------------------------------------------------------------
        aplicar_sw(0, 5);
        comprobar_valor8(5, hex5, hex4, "S(5): A en vivo");
        comprobar_valor8(0, hex3, hex2, "S(5): B en vivo");
        comprobar_leds(0, 0, '0', '0', "S(5): listo");
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(5, 0, "S(5)");
        comprobar_resultado(15, "S(5)");
        comprobar_leds(0, 3, '0', '1', "S(5)");

        ----------------------------------------------------------------
        -- 3) Suma S(1) = 1
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(0, 1);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(1, 0, "S(1)");
        comprobar_resultado(1, "S(1)");
        comprobar_leds(0, 3, '0', '1', "S(1)");

        ----------------------------------------------------------------
        -- 4) Suma S(3) = 6
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(0, 3);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(3, 0, "S(3)");
        comprobar_resultado(6, "S(3)");
        comprobar_leds(0, 3, '0', '1', "S(3)");

        ----------------------------------------------------------------
        -- 5) Factorial 5! = 120
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(1, 5);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(5, 0, "5!");
        comprobar_resultado(120, "5!");
        comprobar_leds(1, 3, '0', '1', "5!");

        ----------------------------------------------------------------
        -- 6) Factorial 3! = 6
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(1, 3);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(3, 0, "3!");
        comprobar_resultado(6, "3!");
        comprobar_leds(1, 3, '0', '1', "3!");

        ----------------------------------------------------------------
        -- 7) Multiplicación 4x3: primera pulsación captura A
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(2, 4);
        pulsar(0);
        assert ledr(3 downto 2) = "01"
            report "mult 4x3: tras la 1.ª pulsación debe esperar B"
            severity failure;
        assert ledr(7) = '1'
            report "mult 4x3: LEDR7 debe indicar ESPERA_B"
            severity failure;
        comprobar_valor8(4, hex5, hex4, "mult 4x3: A capturada");
        comprobar_valor8(4, hex3, hex2, "mult 4x3: B en vivo");
        comprobar_leds(2, 1, '0', '0', "mult 4x3: ESPERA_B");

        aplicar_sw(2, 3);
        comprobar_valor8(4, hex5, hex4, "mult 4x3: A sigue capturada");
        comprobar_valor8(3, hex3, hex2, "mult 4x3: B en vivo cambiada");

        -- 8) Segunda pulsación: ejecuta y publica 12
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(4, 3, "mult 4x3");
        comprobar_resultado(12, "mult 4x3");
        comprobar_leds(2, 3, '0', '1', "mult 4x3");

        ----------------------------------------------------------------
        -- 9) Multiplicación 15x15 = 225
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(2, 15);
        pulsar(0);
        aplicar_sw(2, 15);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(15, 15, "mult 15x15");
        comprobar_resultado(225, "mult 15x15");
        comprobar_leds(2, 3, '0', '1', "mult 15x15");

        ----------------------------------------------------------------
        -- 10) Multiplicación 7x0 = 0 (cero = 1)
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(2, 7);
        pulsar(0);
        aplicar_sw(2, 0);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(7, 0, "mult 7x0");
        comprobar_resultado(0, "mult 7x0");
        comprobar_leds(2, 3, '1', '1', "mult 7x0");

        ----------------------------------------------------------------
        -- 11) Multiplicación 0x5 = 0 (cero = 1)
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(2, 0);
        pulsar(0);
        aplicar_sw(2, 5);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(0, 5, "mult 0x5");
        comprobar_resultado(0, "mult 0x5");
        comprobar_leds(2, 3, '1', '1', "mult 0x5");

        ----------------------------------------------------------------
        -- 12) Resultado latcheado: cambiar SW no altera FIN
        ----------------------------------------------------------------
        -- Venimos del escenario 11 (FIN, modo 10, A=0, B=5, R=0)
        aplicar_sw(1, 3);
        wait for 2 ns;
        comprobar_ab(0, 5, "FIN: A/B latcheados");
        comprobar_resultado(0, "FIN: resultado latcheado");
        comprobar_leds(2, 3, '1', '1', "FIN: modo/estado latcheados");

        ----------------------------------------------------------------
        -- 13) Visualización en vivo en LISTO
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(0, 9);
        comprobar_valor8(9, hex5, hex4, "LISTO: A en vivo");
        comprobar_valor8(0, hex3, hex2, "LISTO: B en vivo");
        comprobar_leds(0, 0, '0', '0', "LISTO: modo en vivo 00");
        aplicar_sw(1, 9);
        comprobar_leds(1, 0, '0', '0', "LISTO: modo en vivo 01");

        ----------------------------------------------------------------
        -- 14) Un pulso = una ejecución: mantener KEY0 no relanza
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(0, 5);
        key(0) <= '0';                 -- pulsar y mantener
        esperar_fin(500);
        wait for 1 ns;
        comprobar_resultado(15, "hold: S(5)");
        comprobar_leds(0, 3, '0', '1', "hold: FIN");
        ciclos(20);
        comprobar_resultado(15, "hold: no se relanza");
        comprobar_leds(0, 3, '0', '1', "hold: sigue en FIN");
        key(0) <= '1';
        ciclos(2);

        ----------------------------------------------------------------
        -- 15) Reset en marcha
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(1, 5);
        pulsar(0);
        ciclos(5);                     -- a mitad de la ejecución
        key(3) <= '0';
        ciclos(2);
        key(3) <= '1';
        ciclos(2);
        comprobar_leds(1, 0, '0', '0', "reset en marcha");
        comprobar_valor8(5, hex5, hex4, "reset en marcha: A en vivo");
        comprobar_valor8(0, hex3, hex2, "reset en marcha: B");
        comprobar_valor8(0, hex1, hex0, "reset en marcha: resultado");

        ----------------------------------------------------------------
        -- 16) Modo 11 inválido: no arranca
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(3, 5);
        assert ledr(8) = '1'
            report "modo 11: LEDR8 debe avisar del modo inválido"
            severity failure;
        pulsar(0);
        ciclos(5);
        comprobar_leds(3, 0, '0', '0', "modo 11: no arranca");
        assert ledr(8) = '1'
            report "modo 11: LEDR8 debe seguir activo"
            severity failure;
        comprobar_valor8(0, hex1, hex0, "modo 11: resultado 0");

        ----------------------------------------------------------------
        -- 17) Cambio de modo durante la ejecución: se ignora
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(0, 5);
        pulsar(0);
        aplicar_sw(1, 5);              -- cambiar de modo mientras ejecuta
        esperar_fin(500);
        wait for 1 ns;
        comprobar_resultado(15, "modo cambiado: sigue siendo suma");
        comprobar_leds(0, 3, '0', '1', "modo cambiado: modo latcheado 00");

        ----------------------------------------------------------------
        -- 18) Armado tras reset: KEY0 pulsado durante el reset no arranca
        ----------------------------------------------------------------
        key <= "1111";
        sw  <= (others => '0');
        wait for 1 ns;
        aplicar_sw(0, 5);
        key(0) <= '0';                 -- mantener KEY0
        key(3) <= '0';                 -- reset
        ciclos(3);
        key(3) <= '1';                 -- soltar reset con KEY0 aún pulsado
        ciclos(5);
        comprobar_leds(0, 0, '0', '0', "armado: no arranca");
        comprobar_valor8(0, hex1, hex0, "armado: resultado 0");
        key(0) <= '1';                 -- soltar KEY0
        ciclos(3);
        key(0) <= '0';                 -- nueva pulsación válida
        ciclos(2);
        key(0) <= '1';
        esperar_fin(500);
        wait for 1 ns;
        comprobar_resultado(15, "armado: arranca tras soltar y pulsar");
        comprobar_leds(0, 3, '0', '1', "armado: FIN");

        ----------------------------------------------------------------
        -- 19) Re-ejecución desde FIN sin pulsar reset
        ----------------------------------------------------------------
        -- Primera operación: S(3) = 6, para llegar a FIN
        reset_placa;
        aplicar_sw(0, 3);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_resultado(6, "re-ejecución: S(3) inicial");
        comprobar_leds(0, 3, '0', '1', "re-ejecución: FIN inicial");

        -- Sin reset: factorial 4 desde FIN -> 24
        aplicar_sw(1, 4);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(4, 0, "re-ejecución: 4!");
        comprobar_resultado(24, "re-ejecución: 4!");
        comprobar_leds(1, 3, '0', '1', "re-ejecución: 4! desde FIN");

        -- Sin reset: multiplicación 5x3 desde FIN -> 15
        aplicar_sw(2, 5);
        pulsar(0);
        assert ledr(3 downto 2) = "01"
            report "re-ejecución: la 1.ª pulsación debe dejar ESPERA_B"
            severity failure;
        assert ledr(7) = '1'
            report "re-ejecución: LEDR7 debe indicar ESPERA_B"
            severity failure;
        aplicar_sw(2, 3);
        pulsar(0);
        esperar_fin(500);
        wait for 1 ns;
        comprobar_ab(5, 3, "re-ejecución: 5x3");
        comprobar_resultado(15, "re-ejecución: 5x3");
        comprobar_leds(2, 3, '0', '1', "re-ejecución: 5x3 desde FIN");

        report "tb_top_placa: OK" severity note;
        finish;
    end process;
end architecture;
