-- ============================================================
-- Testbench del datapath 3 descrito a nivel RTL.
-- Comprueba microoperaciones individuales: carga del acumulador,
-- escritura/lectura del banco, las operaciones de la ALU, el
-- desplazador, el flag de cero y el buffer de salida.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_datapath3_rtl is
end entity;

architecture tb of tb_datapath3_rtl is
    component datapath3_rtl is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ext_data : in  std_logic_vector(7 downto 0);
            sel_sup  : in  std_logic_vector(1 downto 0);
            wr_acc   : in  std_logic;
            clr_acc  : in  std_logic;
            addr     : in  std_logic_vector(2 downto 0);
            wr_rf    : in  std_logic;
            op_alu   : in  std_logic_vector(2 downto 0);
            sel_inf  : in  std_logic;
            sh       : in  std_logic_vector(1 downto 0);
            out_en   : in  std_logic;
            cero     : out std_logic;
            dato_out : out std_logic_vector(7 downto 0);
            acc_q    : out std_logic_vector(7 downto 0);
            rf_dout  : out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal ext_data : std_logic_vector(7 downto 0) := (others => '0');
    signal sel_sup  : std_logic_vector(1 downto 0) := "00";
    signal wr_acc   : std_logic := '0';
    signal clr_acc  : std_logic := '0';
    signal addr     : std_logic_vector(2 downto 0) := "000";
    signal wr_rf    : std_logic := '0';
    signal op_alu   : std_logic_vector(2 downto 0) := "000";
    signal sel_inf  : std_logic := '0';
    signal sh       : std_logic_vector(1 downto 0) := "00";
    signal out_en   : std_logic := '0';
    signal cero     : std_logic;
    signal dato_out : std_logic_vector(7 downto 0);
    signal acc_q    : std_logic_vector(7 downto 0);
    signal rf_dout  : std_logic_vector(7 downto 0);
begin
    dut : datapath3_rtl port map (
        clk => clk, rst => rst, ext_data => ext_data,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
        cero => cero, dato_out => dato_out, acc_q => acc_q, rf_dout => rf_dout
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure comprobar(constant nombre : in string;
                            constant valor  : in std_logic_vector(7 downto 0);
                            constant esperado : in std_logic_vector(7 downto 0)) is
        begin
            assert valor = esperado
                report "tb_datapath3_rtl: " & nombre & " = " &
                       integer'image(to_integer(unsigned(valor))) &
                       ", esperaba " & integer'image(to_integer(unsigned(esperado)))
                severity failure;
        end procedure;
    begin
        -- Reset: acumulador y banco a cero, flag de cero activo
        rst <= '1';
        tick;
        comprobar("acc tras reset", acc_q, x"00");
        comprobar("rf tras reset", rf_dout, x"00");
        assert cero = '1' report "tb_datapath3_rtl: cero tras reset" severity failure;

        rst <= '0';

        -- Cargar 5 desde EXT1
        ext_data <= x"05";
        sel_sup  <= "00";
        wr_acc   <= '1';
        tick;
        comprobar("carga EXT1", acc_q, x"05");
        wr_acc <= '0';

        -- Escribir R1 <- acumulador y leerlo
        addr  <= "001";
        wr_rf <= '1';
        tick;
        wr_rf <= '0';
        comprobar("lectura R1", rf_dout, x"05");

        -- ALU: 5 + R1(5) = 10, realimentado por el shifter
        sel_sup <= "11";
        sel_inf <= '0';
        op_alu  <= "001";
        wr_acc  <= '1';
        tick;
        comprobar("suma 5+5", acc_q, x"0A");

        -- Shifter << 1: 10 -> 20
        op_alu <= "000";
        sh     <= "01";
        tick;
        comprobar("desplazamiento izquierda", acc_q, x"14");

        -- Shifter >> 1: 20 -> 10
        sh <= "10";
        tick;
        comprobar("desplazamiento derecha", acc_q, x"0A");
        sh <= "00";

        -- NOT A: NOT 10 = 245
        op_alu <= "111";
        tick;
        comprobar("NOT A", acc_q, x"F5");

        -- Decremento: 245 -> 244
        op_alu <= "100";
        tick;
        comprobar("decremento", acc_q, x"F4");
        wr_acc <= '0';

        -- Flag de cero con acumulador a 0 (ALU en "pasar A", sin desplazar)
        op_alu  <= "000";
        sel_inf <= '0';
        sh      <= "00";
        clr_acc <= '1';
        tick;
        comprobar("clear", acc_q, x"00");
        assert cero = '1' report "tb_datapath3_rtl: cero con acc=0" severity failure;
        clr_acc <= '0';

        -- Buffer de salida: habilitado muestra el acumulador; si no, 'Z'
        ext_data <= x"7A";
        sel_sup  <= "00";
        wr_acc   <= '1';
        out_en   <= '1';
        tick;
        comprobar("dato_out habilitado", dato_out, x"7A");
        out_en <= '0';
        wait for 1 ns;
        assert dato_out = (dato_out'range => 'Z')
            report "tb_datapath3_rtl: dato_out no quedó en alta impedancia"
            severity failure;

        report "tb_datapath3_rtl: OK" severity note;
        wait;
    end process;
end architecture;
