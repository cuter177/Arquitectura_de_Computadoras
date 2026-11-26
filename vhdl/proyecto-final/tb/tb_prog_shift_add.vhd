-- ============================================================
-- Testbench de integración del programa de multiplicación
-- shift-add: control_gen + datapath3_rtl.
-- El banco de pruebas presenta EXT1 en los pasos 1 (constante 1),
-- 3 (operando A) y 5 (operando B), igual que hará la placa.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.microcodigo_pkg.all;

entity tb_prog_shift_add is
end entity;

architecture tb of tb_prog_shift_add is
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

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal enable   : std_logic := '1';
    signal modo     : std_logic_vector(1 downto 0) := "00";
    signal a_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal b_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal ext_data : std_logic_vector(7 downto 0);
    signal cero     : std_logic;
    signal sel_sup  : std_logic_vector(1 downto 0);
    signal wr_acc   : std_logic;
    signal clr_acc  : std_logic;
    signal addr     : std_logic_vector(2 downto 0);
    signal wr_rf    : std_logic;
    signal op_alu   : std_logic_vector(2 downto 0);
    signal sel_inf  : std_logic;
    signal sh       : std_logic_vector(1 downto 0);
    signal out_en   : std_logic;
    signal g_dato   : std_logic_vector(ANCHO_DATO - 1 downto 0);
    signal g_wr     : std_logic;
    signal g_en     : std_logic;
    signal fin      : std_logic;
    signal paso     : std_logic_vector(ANCHO_PASO - 1 downto 0);
    signal ciclos   : std_logic_vector(15 downto 0);
    signal acc_q    : std_logic_vector(7 downto 0);
    signal rf_dout  : std_logic_vector(7 downto 0);
    signal dato_out : std_logic_vector(7 downto 0);
begin
    u_control : control_gen port map (
        clk => clk, rst => rst, enable => enable, cero => cero, modo => modo,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf,
        sh => sh, out_en => out_en, g_dato => g_dato, g_wr => g_wr, g_en => g_en,
        fin => fin, paso => paso, ciclos => ciclos
    );

    u_datapath : datapath3_rtl port map (
        clk => clk, rst => rst, ext_data => ext_data,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu, sel_inf => sel_inf,
        sh => sh, out_en => out_en, cero => cero, dato_out => dato_out,
        acc_q => acc_q, rf_dout => rf_dout
    );

    -- EXT1 según el micropaso (idéntico al envoltorio de placa)
    process (paso, a_reg, b_reg)
    begin
        if is_x(paso) then
            ext_data <= (others => '0');           -- antes del primer reset
        else
            case to_integer(unsigned(paso)) is
                when 1  => ext_data <= x"01";      -- constante para la ALU
                when 3  => ext_data <= a_reg;      -- A
                when 5  => ext_data <= b_reg;      -- B
                when others => ext_data <= (others => '0');
            end case;
        end if;
    end process;

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure ejecutar(constant a : in std_logic_vector(7 downto 0);
                           constant b : in std_logic_vector(7 downto 0);
                           constant esperado : in std_logic_vector(7 downto 0)) is
            variable n : natural := 0;
        begin
            a_reg <= a;
            b_reg <= b;
            rst <= '1';
            tick;
            rst <= '0';
            while fin = '0' and n < 200 loop
                tick;
                n := n + 1;
            end loop;
            -- La última microinstrucción se ejecuta en el ciclo en que
            -- "fin" ya está activo: hay que darle un flanco para que el
            -- acumulador capture el resultado final.
            tick;
            assert fin = '1'
                report "tb_prog_shift_add: no terminó para " &
                       integer'image(to_integer(unsigned(a))) & "x" &
                       integer'image(to_integer(unsigned(b)))
                severity failure;
            assert acc_q = esperado
                report "tb_prog_shift_add: " &
                       integer'image(to_integer(unsigned(a))) & "x" &
                       integer'image(to_integer(unsigned(b))) & " = " &
                       integer'image(to_integer(unsigned(acc_q))) &
                       ", esperaba " & integer'image(to_integer(unsigned(esperado)))
                severity failure;
            assert out_en = '1'
                report "tb_prog_shift_add: salida no habilitada al fin"
                severity failure;
            report "tb_prog_shift_add: " &
                   integer'image(to_integer(unsigned(a))) & "x" &
                   integer'image(to_integer(unsigned(b))) & " = " &
                   integer'image(to_integer(unsigned(acc_q))) &
                   " en " & integer'image(n) & " microciclos"
                severity note;
        end procedure;
    begin
        enable <= '1';
        modo   <= "00";

        ejecutar(x"04", x"03", x"0C");   -- 12
        ejecutar(x"05", x"05", x"19");   -- 25
        ejecutar(x"0F", x"0F", x"E1");   -- 225
        ejecutar(x"00", x"07", x"00");   -- B = 0
        ejecutar(x"01", x"FF", x"FF");   -- 255

        report "tb_prog_shift_add: OK" severity note;
        wait;
    end process;
end architecture;
