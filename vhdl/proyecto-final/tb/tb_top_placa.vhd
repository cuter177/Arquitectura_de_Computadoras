-- ============================================================
-- Testbench del envoltorio de placa.
-- Comprueba los tres programas a través de los controles reales
-- (KEY0/KEY1/SW) y observa los displays, los LEDs y las salidas
-- STEP/DIR. El tick del motor se acelera con un genérico para que
-- la simulación termine en microsegundos.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_placa is
end entity;

architecture tb of tb_top_placa is
    component top_placa is
        generic (FREC_MOTOR_HZ : natural := 100);
        port (
            clk : in std_logic;
            key : in std_logic_vector(3 downto 0);
            sw  : in std_logic_vector(9 downto 0);
            ledr : out std_logic_vector(9 downto 0);
            hex0 : out std_logic_vector(6 downto 0);
            hex1 : out std_logic_vector(6 downto 0);
            hex2 : out std_logic_vector(6 downto 0);
            hex3 : out std_logic_vector(6 downto 0);
            hex4 : out std_logic_vector(6 downto 0);
            hex5 : out std_logic_vector(6 downto 0);
            step_out : out std_logic;
            dir_out  : out std_logic;
            en_out   : out std_logic;
            ms_out   : out std_logic_vector(2 downto 0)
        );
    end component;

    signal clk      : std_logic := '0';
    signal key      : std_logic_vector(3 downto 0) := "1111";
    signal sw       : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr     : std_logic_vector(9 downto 0);
    signal hex0     : std_logic_vector(6 downto 0);
    signal hex1     : std_logic_vector(6 downto 0);
    signal hex2     : std_logic_vector(6 downto 0);
    signal hex3     : std_logic_vector(6 downto 0);
    signal hex4     : std_logic_vector(6 downto 0);
    signal hex5     : std_logic_vector(6 downto 0);
    signal step_out : std_logic;
    signal dir_out  : std_logic;
    signal en_out   : std_logic;
    signal ms_out   : std_logic_vector(2 downto 0);
begin
    dut : top_placa
        generic map (FREC_MOTOR_HZ => 10_000_000)
        port map (
            clk => clk, key => key, sw => sw, ledr => ledr,
            hex0 => hex0, hex1 => hex1, hex2 => hex2,
            hex3 => hex3, hex4 => hex4, hex5 => hex5,
            step_out => step_out, dir_out => dir_out,
            en_out => en_out, ms_out => ms_out
        );

    stim : process
        variable n_motor     : natural := 0;
        variable contados    : natural := 0;
        variable anterior    : std_logic := '0';

        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure resetear is
        begin
            key(3) <= '0';
            tick;
            key(3) <= '1';
            tick;
        end procedure;

        procedure pulsar_key0 is
        begin
            key(0) <= '1';
            tick;
            key(0) <= '0';
            tick;
            key(0) <= '1';
            tick;
        end procedure;

        procedure pulsar_key1 is
        begin
            key(1) <= '1';
            tick;
            key(1) <= '0';
            tick;
            key(1) <= '1';
            tick;
        end procedure;

        procedure esperar_fin is
            variable n : natural := 0;
        begin
            while ledr(5) = '0' and n < 20000 loop
                tick;
                n := n + 1;
            end loop;
            assert ledr(5) = '1'
                report "tb_top_placa: no llegó a FIN"
                severity failure;
        end procedure;

        procedure comprobar_display(constant h1 : in std_logic_vector(6 downto 0);
                                    constant h0 : in std_logic_vector(6 downto 0)) is
        begin
            assert hex1 = h1 and hex0 = h0
                report "tb_top_placa: display resultado incorrecto"
                severity failure;
        end procedure;
    begin
        ------------------------------------------------------------------
        -- Shift-add 4 x 3 = 12 (0x0C)
        ------------------------------------------------------------------
        resetear;
        sw <= "00" & x"04";          -- A = 4
        pulsar_key0;                  -- captura A -> ESPERA_B
        sw <= "00" & x"03";          -- B = 3
        pulsar_key0;                  -- captura B -> ejecuta
        esperar_fin;
        comprobar_display("1000000", "1000110");   -- 0, C
        report "tb_top_placa: shift-add en la placa, 4x3=12" severity note;

        ------------------------------------------------------------------
        -- Popcount 0xA5 = 4
        ------------------------------------------------------------------
        resetear;
        sw <= "01" & x"A5";
        pulsar_key0;
        esperar_fin;
        comprobar_display("1000000", "0011001");   -- 0, 4
        report "tb_top_placa: popcount en la placa, A5->4" severity note;

        ------------------------------------------------------------------
        -- Motor NEMA 17: 4 pasos en sentido inverso
        ------------------------------------------------------------------
        resetear;
        sw <= "10" & x"04";          -- 4 pasos
        pulsar_key1;                  -- invertir sentido
        pulsar_key0;                  -- arrancar
        assert dir_out = '1'
            report "tb_top_placa: DIR no refleja el sentido elegido"
            severity failure;
        assert en_out = '0'
            report "tb_top_placa: ENABLE debe estar a nivel bajo"
            severity failure;
        assert ms_out = "000"
            report "tb_top_placa: se esperaba paso completo (MS=000)"
            severity failure;

        while ledr(5) = '0' and n_motor < 20000 loop
            anterior := step_out;
            tick;
            if step_out = '1' and anterior = '0' then
                contados := contados + 1;
            end if;
            n_motor := n_motor + 1;
        end loop;
        assert ledr(5) = '1'
            report "tb_top_placa: el motor no terminó"
            severity failure;
        assert contados = 4
            report "tb_top_placa: " & integer'image(contados) &
                   " pulsos STEP, esperaba 4"
            severity failure;
        report "tb_top_placa: motor, 4 pasos y DIR=" &
               std_logic'image(dir_out) severity note;

        report "tb_top_placa: OK" severity note;
        wait;
    end process;
end architecture;
