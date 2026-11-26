-- ============================================================
-- Datapath 3 a nivel RTL / comportamental.
--
-- Descripción de alto nivel del mismo camino de datos que el
-- datapath estructural de la unidad datapath-3: mux superior,
-- acumulador, banco de registros (8x8), ALU de 8 operaciones,
-- mux inferior, shifter, detector de cero y buffer de salida.
--
-- Toda la lógica combinacional se calcula en un único bloque y
-- los registros se actualizan en un solo proceso síncrono. La
-- interfaz es idéntica a la del datapath original, así que el
-- mismo motor de microcódigo puede gobernar cualquiera de los dos.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity datapath3_rtl is
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
end entity;

architecture rtl of datapath3_rtl is
    type banco_t is array (0 to 7) of std_logic_vector(7 downto 0);

    signal acc     : std_logic_vector(7 downto 0) := (others => '0');
    signal regs    : banco_t := (others => (others => '0'));
    signal rf_out  : std_logic_vector(7 downto 0);
    signal alu_f   : std_logic_vector(7 downto 0);
    signal mux_inf : std_logic_vector(7 downto 0);
    signal sh_out  : std_logic_vector(7 downto 0);
    signal mux_sup : std_logic_vector(7 downto 0);
begin
    -- Lectura combinacional del banco (un solo puerto de dirección)
    rf_out <= regs(to_integer(unsigned(addr)));

    -- ALU: 8 operaciones sobre bytes sin signo, módulo 256
    process (acc, rf_out, op_alu)
    begin
        case op_alu is
            when "000" => alu_f <= acc;                                       -- pasar A
            when "001" => alu_f <= std_logic_vector(unsigned(acc) + unsigned(rf_out)); -- suma
            when "010" => alu_f <= std_logic_vector(unsigned(acc) - unsigned(rf_out)); -- resta
            when "011" => alu_f <= std_logic_vector(unsigned(acc) + 1);        -- incremento
            when "100" => alu_f <= std_logic_vector(unsigned(acc) - 1);        -- decremento
            when "101" => alu_f <= acc or rf_out;                              -- OR
            when "110" => alu_f <= acc and rf_out;                             -- AND
            when others => alu_f <= not acc;                                   -- NOT A
        end case;
    end process;

    -- Mux inferior: resultado de la ALU o propio acumulador
    mux_inf <= alu_f when sel_inf = '0' else acc;

    -- Shifter: paso, desplazamiento izquierda, derecha lógico y aritmético
    with sh select sh_out <=
        mux_inf                            when "00",
        mux_inf(6 downto 0) & '0'          when "01",
        '0' & mux_inf(7 downto 1)          when "10",
        mux_inf(7) & mux_inf(7 downto 1)   when others;

    -- Flag de cero sobre el dato que se va a escribir en el acumulador
    cero <= '1' when sh_out = x"00" else '0';

    -- Mux superior: dato externo, EXT2 (reservado a 0), banco o shifter
    with sel_sup select mux_sup <=
        ext_data     when "00",
        x"00"        when "01",
        rf_out       when "10",
        sh_out       when others;

    -- Buffer de salida (tri-estado cuando no está habilitado)
    dato_out <= acc when out_en = '1' else (others => 'Z');

    -- Salidas de observación para testbenches y capturas
    acc_q   <= acc;
    rf_dout <= rf_out;

    -- Registros: el acumulador y el banco capturan en el mismo flanco
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc  <= (others => '0');
                regs <= (others => (others => '0'));
            else
                if clr_acc = '1' then
                    acc <= (others => '0');
                elsif wr_acc = '1' then
                    acc <= mux_sup;
                end if;

                if wr_rf = '1' then
                    regs(to_integer(unsigned(addr))) <= acc;
                end if;
            end if;
        end if;
    end process;
end architecture;
