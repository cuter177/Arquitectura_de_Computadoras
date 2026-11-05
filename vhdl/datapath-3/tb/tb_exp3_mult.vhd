-- ============================================================
-- Testbench del Experimento 3: multiplicación P = A x B por
-- sumas repetidas (A, B <= 15 por desbordamiento de 8 bits).
-- Instancia datapath + control (modo = "10"); EXT1 presenta
-- A (paso 65) y B (paso 67).
-- Casos: 4x3 = 12, 5x5 = 25, 15x15 = 225.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_exp3_mult is
end entity;

architecture tb of tb_exp3_mult is
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

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal modo     : std_logic_vector(1 downto 0) := "10";
    signal cero     : std_logic;
    signal fin      : std_logic;
    signal sel_sup  : std_logic_vector(1 downto 0);
    signal wr_acc   : std_logic;
    signal clr_acc  : std_logic;
    signal addr     : std_logic_vector(2 downto 0);
    signal wr_rf    : std_logic;
    signal op_alu   : std_logic_vector(2 downto 0);
    signal sel_inf  : std_logic;
    signal sh       : std_logic_vector(1 downto 0);
    signal out_en   : std_logic;
    signal paso     : std_logic_vector(6 downto 0);
    signal ciclos   : std_logic_vector(15 downto 0);
    signal ext_data : std_logic_vector(7 downto 0);
    signal dato_out : std_logic_vector(7 downto 0);
    signal acc_q    : std_logic_vector(7 downto 0);
    signal rf_dout  : std_logic_vector(7 downto 0);

    signal a_val : natural := 4;
    signal b_val : natural := 3;
begin
    dp : datapath port map (
        clk => clk, rst => rst, ext_data => ext_data,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
        cero => cero, dato_out => dato_out,
        acc_q => acc_q, rf_dout => rf_dout
    );

    ct : control port map (
        clk => clk, rst => rst, cero => cero, modo => modo,
        sel_sup => sel_sup, wr_acc => wr_acc, clr_acc => clr_acc,
        addr => addr, wr_rf => wr_rf, op_alu => op_alu,
        sel_inf => sel_inf, sh => sh, out_en => out_en,
        fin => fin, paso => paso, ciclos => ciclos
    );

    -- EXT1: paso 65 = A, paso 67 = B (plan §8.5)
    ext_data <= std_logic_vector(to_unsigned(a_val, 8))
                when paso = "1000001" else
                std_logic_vector(to_unsigned(b_val, 8))
                when paso = "1000011" else (others => '0');

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;

        procedure caso(constant av : in natural; constant bv : in natural;
                       constant esperado : in natural) is
        begin
            a_val <= av;
            b_val <= bv;
            rst   <= '1';
            tick;
            tick;
            rst <= '0';
            for i in 1 to 1000 loop
                tick;
                exit when fin = '1';
            end loop;
            assert fin = '1'
                report "exp3: no terminó para " & integer'image(av) &
                       " x " & integer'image(bv)
                severity failure;
            tick;  -- ejecuta la palabra FIN
            assert acc_q = std_logic_vector(to_unsigned(esperado, 8))
                report "exp3: " & integer'image(av) & " x " &
                       integer'image(bv) & " = " &
                       integer'image(to_integer(unsigned(acc_q))) &
                       ", esperaba " & integer'image(esperado)
                severity failure;
            report "exp3: " & integer'image(av) & " x " &
                   integer'image(bv) & " = " & integer'image(esperado) &
                   " OK en " &
                   integer'image(to_integer(unsigned(ciclos))) & " microciclos"
                severity note;
        end procedure;
    begin
        caso(4, 3, 12);
        caso(5, 5, 25);
        caso(15, 15, 225);
        report "tb_exp3_mult: OK" severity note;
        wait;
    end process;
end architecture;
