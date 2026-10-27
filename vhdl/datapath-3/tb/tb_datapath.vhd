-- ============================================================
-- Testbench del datapath integrado: ejecuta a mano los pasos
-- de la tabla de microoperaciones del Experimento 1 (suma de
-- 1..n con n = 5) con señales de control dirigidas por el tb,
-- comprobando los caminos: EXT→Acc, Acc→RF, RF→Acc,
-- ALU+shifter→mux superior→Acc, detector de cero y buffer.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_datapath is
end entity;

architecture tb of tb_datapath is
    component datapath is
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
    signal addr     : std_logic_vector(2 downto 0) := (others => '0');
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
    dut : datapath port map (
        clk => clk, rst => rst, ext_data => ext_data,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
        cero => cero, dato_out => dato_out,
        acc_q => acc_q, rf_dout => rf_dout
    );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure comprobar_acc(constant esp : in natural; constant msg : in string) is
        begin
            assert acc_q = std_logic_vector(to_unsigned(esp, 8))
                report "tb_datapath: " & msg &
                       " (acc = " & integer'image(to_integer(unsigned(acc_q))) &
                       ", esperaba " & integer'image(esp) & ")"
                severity failure;
        end procedure;
    begin
        -- reset
        rst <= '1';
        tick;
        tick;
        rst <= '0';
        comprobar_acc(0, "rst no limpia el acumulador");

        -- paso 0: Acc ← 0 (clear)
        clr_acc <= '1';
        tick;
        clr_acc <= '0';
        comprobar_acc(0, "paso 0: clear");

        -- paso 1: Acc ← EXT1 (n = 5)  [camino EXT→mux→Acc]
        ext_data <= std_logic_vector(to_unsigned(5, 8));
        sel_sup  <= "00";
        wr_acc   <= '1';
        tick;
        wr_acc   <= '0';
        comprobar_acc(5, "paso 1: carga desde EXT1");

        -- paso 2: R1 ← Acc  [camino Acc→banco]
        wr_rf <= '1';
        addr  <= "001";
        tick;
        wr_rf <= '0';

        -- paso 3: Acc ← 0 (clear)
        clr_acc <= '1';
        tick;
        clr_acc <= '0';
        comprobar_acc(0, "paso 3: clear");

        -- paso 4: Acc ← R2 (aún 0)  [camino RF→mux superior→Acc]
        sel_sup <= "10";
        wr_acc  <= '1';
        addr    <= "010";
        tick;
        wr_acc  <= '0';
        comprobar_acc(0, "paso 4: lectura de R2");

        -- paso 5: Acc ← Acc + R1 = 0 + 5  [ALU→mux inferior→shifter→mux superior→Acc]
        sel_sup <= "11";
        op_alu  <= "001";
        sel_inf <= '0';
        sh      <= "00";
        addr    <= "001";
        wr_acc  <= '1';
        tick;
        wr_acc  <= '0';
        comprobar_acc(5, "paso 5: suma por realimentación");

        -- paso 6: R2 ← Acc (s = 5)
        wr_rf <= '1';
        addr  <= "010";
        tick;
        wr_rf <= '0';

        -- paso 7: Acc ← R1 = 5
        sel_sup <= "10";
        wr_acc  <= '1';
        addr    <= "001";
        tick;
        wr_acc  <= '0';
        comprobar_acc(5, "paso 7: lectura de R1");

        -- paso 8: Acc ← Acc − 1 = 4 (sin cero)
        sel_sup <= "11";
        op_alu  <= "100";
        wr_acc  <= '1';
        tick;
        wr_acc  <= '0';
        comprobar_acc(4, "paso 8: decremento");
        assert cero = '0'
            report "tb_datapath: el detector de cero se activó con 4" severity failure;

        -- paso 8b: probar el detector de cero. El flag es combinacional
        -- sobre la salida de la ALU: es válido DURANTE el ciclo (lo muestrea
        -- la control en el flanco). Con Acc = 1 la ALU ya ve 1-1 = 0.
        op_alu <= "100";
        wr_acc <= '1';
        tick;  -- 3
        tick;  -- 2
        tick;  -- 1
        wait for 1 ns;
        assert cero = '1'
            report "tb_datapath: el detector de cero no marca el 0 pendiente"
            severity failure;
        tick;  -- 0 (en este flanco la unidad de control saltaría)
        wr_acc <= '0';
        comprobar_acc(0, "paso 8b: llegada a cero");

        -- paso 9: R1 ← Acc (0) y comprobar banca leída antes
        wr_rf <= '1';
        addr  <= "001";
        tick;
        wr_rf <= '0';

        -- paso 10: Acc ← R2 = 5 + habilitar buffer de salida
        sel_sup <= "10";
        wr_acc  <= '1';
        addr    <= "010";
        out_en  <= '1';
        tick;
        wr_acc  <= '0';
        comprobar_acc(5, "paso 10: resultado en Acc");
        wait for 1 ns;
        assert dato_out = std_logic_vector(to_unsigned(5, 8))
            report "tb_datapath: el buffer de salida no refleja Acc" severity failure;

        -- deshabilitar buffer: alta impedancia
        out_en <= '0';
        wait for 10 ns;
        assert dato_out = "ZZZZZZZZ"
            report "tb_datapath: el buffer no se deshabilita" severity failure;

        report "tb_datapath: OK" severity note;
        wait;
    end process;
end architecture;
