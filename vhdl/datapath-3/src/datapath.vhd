-- ============================================================
-- Datapath 3: integración estructural del diagrama completo
-- mux superior → acumulador → (banco de registros | ALU) →
-- mux inferior → shifter → realimentación al mux superior,
-- más el detector de cero y el buffer de salida.
--
-- Se usa instanciación por componentes para que el análisis
-- sea independiente del orden de los ficheros (scripts/vhdl-analizar).
--
-- Señales de entrada: las de control generadas por control.vhd.
-- Salidas observables: cero (flag), dato_out (puerto externo),
-- acc_q y rf_dout (para testbenches y capturas de ondas).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity datapath is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        ext_data : in  std_logic_vector(7 downto 0);  -- EXT1
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
end entity;

architecture estructural of datapath is
    component mux_superior is
        port (
            sel_sup : in  std_logic_vector(1 downto 0);
            ext1    : in  std_logic_vector(7 downto 0);
            ext2    : in  std_logic_vector(7 downto 0);
            rf      : in  std_logic_vector(7 downto 0);
            sh      : in  std_logic_vector(7 downto 0);
            y       : out std_logic_vector(7 downto 0)
        );
    end component;

    component acumulador is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            wr    : in  std_logic;
            clear : in  std_logic;
            d_in  : in  std_logic_vector(7 downto 0);
            q     : out std_logic_vector(7 downto 0)
        );
    end component;

    component banco_registros is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            addr  : in  std_logic_vector(2 downto 0);
            wr    : in  std_logic;
            d_in  : in  std_logic_vector(7 downto 0);
            d_out : out std_logic_vector(7 downto 0)
        );
    end component;

    component alu is
        port (
            a  : in  std_logic_vector(7 downto 0);
            b  : in  std_logic_vector(7 downto 0);
            op : in  std_logic_vector(2 downto 0);
            f  : out std_logic_vector(7 downto 0)
        );
    end component;

    component mux_inferior is
        port (
            sel_inf : in  std_logic;
            alu_f   : in  std_logic_vector(7 downto 0);
            acc     : in  std_logic_vector(7 downto 0);
            y       : out std_logic_vector(7 downto 0)
        );
    end component;

    component shifter is
        port (
            d_in  : in  std_logic_vector(7 downto 0);
            sh    : in  std_logic_vector(1 downto 0);
            d_out : out std_logic_vector(7 downto 0)
        );
    end component;

    component detector_cero is
        port (
            d    : in  std_logic_vector(7 downto 0);
            cero : out std_logic
        );
    end component;

    component buffer_salida is
        port (
            d_in : in  std_logic_vector(7 downto 0);
            en   : in  std_logic;
            y    : out std_logic_vector(7 downto 0)
        );
    end component;

    -- buses internos (replica del diagrama)
    signal ext2_nulo : std_logic_vector(7 downto 0) := (others => '0');
    signal mux_sup_y : std_logic_vector(7 downto 0);  -- hacia la entrada del acumulador
    signal bus_acc   : std_logic_vector(7 downto 0);  -- salida del acumulador (el "bus")
    signal rf_out    : std_logic_vector(7 downto 0);
    signal alu_f     : std_logic_vector(7 downto 0);
    signal mux_inf_y : std_logic_vector(7 downto 0);
    signal sh_out    : std_logic_vector(7 downto 0);
begin
    u_mux_sup : mux_superior port map (
        sel_sup => sel_sup,
        ext1    => ext_data,
        ext2    => ext2_nulo,
        rf      => rf_out,
        sh      => sh_out,
        y       => mux_sup_y
    );

    u_acumulador : acumulador port map (
        clk   => clk,
        rst   => rst,
        wr    => wr_acc,
        clear => clr_acc,
        d_in  => mux_sup_y,
        q     => bus_acc
    );

    u_banco : banco_registros port map (
        clk   => clk,
        rst   => rst,
        addr  => addr,
        wr    => wr_rf,
        d_in  => bus_acc,
        d_out => rf_out
    );

    u_alu : alu port map (
        a  => bus_acc,
        b  => rf_out,
        op => op_alu,
        f  => alu_f
    );

    u_mux_inf : mux_inferior port map (
        sel_inf => sel_inf,
        alu_f   => alu_f,
        acc     => bus_acc,
        y       => mux_inf_y
    );

    u_shifter : shifter port map (
        d_in  => mux_inf_y,
        sh    => sh,
        d_out => sh_out
    );

    u_detector : detector_cero port map (
        d    => sh_out,
        cero => cero
    );

    u_buffer : buffer_salida port map (
        d_in => bus_acc,
        en   => out_en,
        y    => dato_out
    );

    -- salidas de observación (testbenches y capturas)
    acc_q   <= bus_acc;
    rf_dout <= rf_out;
end architecture;
