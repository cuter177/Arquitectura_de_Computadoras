-- ============================================================
-- Testbench del envoltorio FPGA de Datapath 1.
--
-- Comprueba, sin placa:
--   - reset y estado inicial (Q=0, M=1, OE=1);
--   - visualización en vivo de SW[7:0] y F_ALU;
--   - carga con A+B, 2n+x, n+1 y la operación reservada;
--   - efecto funcional de M=0 (operando A = 0) frente a M=1;
--   - OE: apaga HEX1:0 y LEDR9, pero LEDR[7:0] sigue mostrando Q;
--   - una pulsación mantenida = una sola acción (KEY0, KEY1 y KEY2);
--   - pulsación durante el reset ignorada (lógica armado);
--   - reset con Q distinto de cero.
--
-- El reloj se genera dentro del proceso para que la agenda de GHDL
-- pueda vaciarse y la simulación termine con std.env.finish.
-- Los displays se comparan contra los patrones reales de hex7seg
-- (ánodo común: 0 enciende).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_top_placa is
end entity;

architecture prueba of tb_top_placa is
    constant PERIODO : time := 10 ns;

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(3 downto 0) := (others => '1');
    signal sw   : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr : std_logic_vector(9 downto 0);

    signal hex0, hex1, hex2, hex3, hex4, hex5 :
        std_logic_vector(6 downto 0);

    -- Patrón de 7 segmentos de hex7seg (activo a nivel bajo).
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
        return TABLA(n mod 16);
    end function;

begin

    uut : entity work.top_placa
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

    estimulos : process
        procedure ciclos(constant n : in natural) is
        begin
            for i in 1 to n loop
                clk <= '0';
                wait for PERIODO / 2;
                clk <= '1';
                wait for PERIODO / 2;
            end loop;
        end procedure;

        procedure comprobar_nibble(
            constant v   : in natural;
            constant seg : in std_logic_vector(6 downto 0);
            constant msg : in string
        ) is
        begin
            assert seg = patron(v mod 16)
                report "tb_top_placa: " & msg
                severity failure;
        end procedure;

        procedure comprobar_byte(
            constant v   : in natural;
            constant hi  : in std_logic_vector(6 downto 0);
            constant lo  : in std_logic_vector(6 downto 0);
            constant msg : in string
        ) is
        begin
            comprobar_nibble(v / 16, hi, msg & " (nibble alto)");
            comprobar_nibble(v mod 16, lo, msg & " (nibble bajo)");
        end procedure;

        procedure comprobar_leds(
            constant q   : in natural;
            constant m   : in std_logic;
            constant oe  : in std_logic;
            constant msg : in string
        ) is
        begin
            assert ledr(7 downto 0) = std_logic_vector(to_unsigned(q, 8))
                report "tb_top_placa: " & msg & " (Q en LEDR)"
                severity failure;
            assert ledr(8) = m
                report "tb_top_placa: " & msg & " (M en LEDR8)"
                severity failure;
            assert ledr(9) = oe
                report "tb_top_placa: " & msg & " (OE en LEDR9)"
                severity failure;
        end procedure;

        procedure comprobar_hex_apagados(constant msg : in string) is
        begin
            assert hex1 = "1111111" and hex0 = "1111111"
                report "tb_top_placa: " & msg & " (HEX1:0 deben estar apagados)"
                severity failure;
        end procedure;

        procedure aplicar_sw(
            constant dato : in natural;
            constant op   : in natural
        ) is
        begin
            sw <= std_logic_vector(to_unsigned(op, 2)) &
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

        comprobar_leds(0, '1', '1', "tras reset");
        comprobar_byte(0, hex5, hex4, "tras reset dato externo");
        comprobar_byte(0, hex3, hex2, "tras reset F_ALU");
        comprobar_byte(0, hex1, hex0, "tras reset Q");

        ----------------------------------------------------------------
        -- 2) Visualización en vivo: dato y F_ALU con Q=0
        ----------------------------------------------------------------
        aplicar_sw(90, 0);          -- 0x5A
        comprobar_byte(90, hex5, hex4, "en vivo dato externo");
        comprobar_byte(90, hex3, hex2, "en vivo F_ALU");
        comprobar_byte(0, hex1, hex0, "en vivo Q");
        comprobar_leds(0, '1', '1', "en vivo");

        ----------------------------------------------------------------
        -- 3) Carga con A+B (C=000, M=1): Q = 0 + 5
        ----------------------------------------------------------------
        aplicar_sw(5, 0);
        pulsar(0);

        comprobar_leds(5, '1', '1', "carga A+B");
        comprobar_byte(5, hex5, hex4, "carga A+B dato externo");
        comprobar_byte(10, hex3, hex2, "carga A+B F_ALU posterior");
        comprobar_byte(5, hex1, hex0, "carga A+B Q");

        ----------------------------------------------------------------
        -- 4) 2n+x (C=001, M=1): Q = 2*5 + 5 = 15
        ----------------------------------------------------------------
        aplicar_sw(5, 1);
        comprobar_byte(15, hex3, hex2, "2n+x F_ALU antes de cargar");
        pulsar(0);

        comprobar_leds(15, '1', '1', "2n+x");
        comprobar_byte(5, hex5, hex4, "2n+x dato externo");
        comprobar_byte(35, hex3, hex2, "2n+x F_ALU posterior");
        comprobar_byte(15, hex1, hex0, "2n+x Q");

        ----------------------------------------------------------------
        -- 5) n+1 (C=010): Q = 15 + 1 = 16 (ignora A)
        ----------------------------------------------------------------
        aplicar_sw(5, 2);
        comprobar_byte(16, hex3, hex2, "n+1 F_ALU antes de cargar");
        pulsar(0);

        comprobar_leds(16, '1', '1', "n+1");
        comprobar_byte(17, hex3, hex2, "n+1 F_ALU posterior");
        comprobar_byte(16, hex1, hex0, "n+1 Q");

        ----------------------------------------------------------------
        -- 6) Operación reservada (C=011): F = 0
        ----------------------------------------------------------------
        aplicar_sw(5, 3);
        comprobar_byte(0, hex3, hex2, "reservada F_ALU antes de cargar");
        pulsar(0);

        comprobar_leds(0, '1', '1', "reservada");
        comprobar_byte(0, hex3, hex2, "reservada F_ALU posterior");
        comprobar_byte(0, hex1, hex0, "reservada Q");

        ----------------------------------------------------------------
        -- 7) Efecto funcional de M: M=0 usa A=0; M=1 usa SW[7:0]
        ----------------------------------------------------------------
        -- Preparar Q=5 con M=1 y A+B.
        aplicar_sw(5, 0);
        pulsar(0);
        comprobar_leds(5, '1', '1', "M: preparación Q=5");

        -- M=0: con C=001 y SW=7, F = 2*5 + 0 = 10 (no 17).
        pulsar(2);
        comprobar_leds(5, '0', '1', "M=0 tras KEY2");
        aplicar_sw(7, 1);
        comprobar_byte(10, hex3, hex2, "M=0 F_ALU antes de cargar");
        pulsar(0);
        comprobar_leds(10, '0', '1', "M=0 carga");
        comprobar_byte(20, hex3, hex2, "M=0 F_ALU posterior");
        comprobar_byte(10, hex1, hex0, "M=0 Q");

        -- M=1: con C=001 y SW=7, F = 2*10 + 7 = 27.
        pulsar(2);
        comprobar_leds(10, '1', '1', "M=1 tras KEY2");
        aplicar_sw(7, 1);
        comprobar_byte(27, hex3, hex2, "M=1 F_ALU antes de cargar");
        pulsar(0);
        comprobar_leds(27, '1', '1', "M=1 carga");
        comprobar_byte(61, hex3, hex2, "M=1 F_ALU posterior");
        comprobar_byte(27, hex1, hex0, "M=1 Q");

        ----------------------------------------------------------------
        -- 8) OE: apaga HEX1:0 y LEDR9; LEDR[7:0] sigue mostrando Q
        ----------------------------------------------------------------
        pulsar(1);
        comprobar_leds(27, '1', '0', "OE=0");
        comprobar_hex_apagados("OE=0");
        comprobar_byte(61, hex3, hex2, "OE=0 F_ALU sigue visible");

        pulsar(1);
        comprobar_leds(27, '1', '1', "OE=1");
        comprobar_byte(27, hex1, hex0, "OE=1 Q restaurado");

        ----------------------------------------------------------------
        -- 9) KEY1 mantenido: OE alterna una sola vez
        ----------------------------------------------------------------
        key(1) <= '0';
        ciclos(5);
        comprobar_leds(27, '1', '0', "KEY1 mantenido alterna una vez");

        key(1) <= '1';
        ciclos(3);
        comprobar_leds(27, '1', '0', "KEY1 mantenido no alterna de nuevo");

        pulsar(1);
        comprobar_leds(27, '1', '1', "OE restaurado tras KEY1 mantenido");

        ----------------------------------------------------------------
        -- 10) KEY2 mantenido: M alterna una sola vez
        ----------------------------------------------------------------
        key(2) <= '0';
        ciclos(5);
        comprobar_leds(27, '0', '1', "KEY2 mantenido alterna una vez");

        key(2) <= '1';
        ciclos(3);
        comprobar_leds(27, '0', '1', "KEY2 mantenido no alterna de nuevo");

        pulsar(2);
        comprobar_leds(27, '1', '1', "M restaurado tras KEY2 mantenido");

        ----------------------------------------------------------------
        -- 11) KEY0 mantenido: una sola carga
        ----------------------------------------------------------------
        aplicar_sw(5, 0);           -- Q=27, A=5, C=000 => F=32
        key(0) <= '0';
        ciclos(3);
        comprobar_leds(32, '1', '1', "KEY0 mantenido primera carga");
        comprobar_byte(37, hex3, hex2, "KEY0 mantenido F_ALU posterior");

        sw(7 downto 0) <= x"0A";    -- si recargara, Q pasaría a 32+10
        wait for 1 ns;
        ciclos(5);
        comprobar_leds(32, '1', '1', "KEY0 mantenido no recarga");

        key(0) <= '1';
        ciclos(3);

        ----------------------------------------------------------------
        -- 12) Pulsación durante el reset: se ignora hasta soltar y pulsar
        ----------------------------------------------------------------
        reset_placa;
        aplicar_sw(5, 0);

        key(0) <= '0';              -- mantener KEY0
        key(3) <= '0';              -- reset
        ciclos(3);
        key(3) <= '1';              -- soltar reset con KEY0 aún pulsado
        ciclos(5);
        comprobar_leds(0, '1', '1', "pulsación durante reset ignorada");

        key(0) <= '1';              -- soltar KEY0
        ciclos(3);
        pulsar(0);                  -- nueva pulsación válida
        comprobar_leds(5, '1', '1', "carga tras soltar y pulsar");

        ----------------------------------------------------------------
        -- 13) Reset con Q distinto de cero
        ----------------------------------------------------------------
        aplicar_sw(5, 1);           -- Q=5, C=001 => F=15 antes del reset
        reset_placa;

        comprobar_leds(0, '1', '1', "reset con Q distinto de cero");
        comprobar_byte(5, hex5, hex4, "reset: dato externo");
        comprobar_byte(5, hex3, hex2, "reset: F_ALU con Q=0");
        comprobar_byte(0, hex1, hex0, "reset: Q");

        report "tb_top_placa: todas las pruebas OK" severity note;
        finish;
    end process;

end architecture;
