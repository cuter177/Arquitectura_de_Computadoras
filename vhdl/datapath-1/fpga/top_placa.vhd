-- ============================================================
-- Envoltorio FPGA del Datapath 1 para la DE10-Standard.
--
-- SW[7:0]  : dato externo (operando A de la ALU)
-- SW[9:8]  : operacion ALU (C1:C0; C2 se fija a 0)
-- KEY0     : cargar F_ALU en Q (un flanco = una carga)
-- KEY1     : alternar OE
-- KEY2     : alternar M
-- KEY3     : reset
--
-- LEDR[7:0] : Q (siempre, aunque OE=0)
-- LEDR[8]   : M
-- LEDR[9]   : OE
-- HEX5:4    : dato externo
-- HEX3:2    : F_ALU
-- HEX1:0    : Q (apagado si OE=0)
--
-- OE no apaga LEDR[7:0]: el buffer tri-estado original (`salida`) no
-- se conecta a la placa; OE solo oculta HEX1:0 y se refleja en LEDR9.
--
-- Operaciones provisionales (C = '0' & SW[9:8]):
-- 00 = A+B
-- 01 = (B desplazado a la izquierda)+A
-- 10 = B+1
-- 11 = reservado
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;

entity top_placa is
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
end entity;

architecture estructural of top_placa is

    component datapath is
        generic (
            ANCHO : natural := 8
        );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            dato_ext : in  std_logic_vector(ANCHO - 1 downto 0);
            cw       : in  std_logic_vector(5 downto 0);
            salida   : out std_logic_vector(ANCHO - 1 downto 0);
            f_alu    : out std_logic_vector(ANCHO - 1 downto 0);
            q_reg    : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    component pulsador is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            entrada : in  std_logic;
            pulso   : out std_logic
        );
    end component;

    component hex7seg is
        port (
            valor  : in  std_logic_vector(3 downto 0);
            salida : out std_logic_vector(6 downto 0)
        );
    end component;

    signal rst_global : std_logic;

    signal pulso_cargar : std_logic;
    signal pulso_oe     : std_logic;
    signal pulso_m      : std_logic;

    signal armado_cargar : std_logic := '0';
    signal armado_oe     : std_logic := '0';
    signal armado_m      : std_logic := '0';

    signal oe_reg : std_logic := '1';
    signal m_reg  : std_logic := '1';

    signal cw       : std_logic_vector(5 downto 0);
    signal c        : std_logic_vector(2 downto 0);
    signal f_alu    : std_logic_vector(7 downto 0);
    signal q_reg    : std_logic_vector(7 downto 0);

    signal hex_q_hi : std_logic_vector(6 downto 0);
    signal hex_q_lo : std_logic_vector(6 downto 0);

begin

    -- KEY3 es activo bajo; el reset interno es activo alto.
    rst_global <= not key(3);

    -- Convertir las pulsaciones en eventos de un ciclo.
    u_cargar : pulsador
        port map (
            clk => clk,
            rst => rst_global,
            entrada => not key(0),
            pulso => pulso_cargar
        );

    u_oe : pulsador
        port map (
            clk => clk,
            rst => rst_global,
            entrada => not key(1),
            pulso => pulso_oe
        );

    u_m : pulsador
        port map (
            clk => clk,
            rst => rst_global,
            entrada => not key(2),
            pulso => pulso_m
        );

    -- Evitar aceptar pulsaciones que se mantengan durante el reset.
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                armado_cargar <= '0';
                armado_oe     <= '0';
                armado_m      <= '0';
                oe_reg        <= '1';
                m_reg         <= '1';
            else
                if pulso_cargar = '0' then
                    armado_cargar <= '1';
                end if;

                if pulso_oe = '0' then
                    armado_oe <= '1';
                end if;

                if pulso_m = '0' then
                    armado_m <= '1';
                end if;

                if pulso_oe = '1' and armado_oe = '1' then
                    oe_reg <= not oe_reg;
                end if;

                if pulso_m = '1' and armado_m = '1' then
                    m_reg <= not m_reg;
                end if;
            end if;
        end if;
    end process;

    -- SW[9:8] selecciona C1:C0; C2 se fija a 0.
    c <= '0' & sw(9 downto 8);

    -- CW = [OE, L, M, C2, C1, C0].
    cw <= oe_reg & (pulso_cargar and armado_cargar)
          & m_reg & c;

    -- Datapath original. No se modifica su implementación.
    -- `salida` se deja abierta: el buffer tri-estado no puede gobernar
    -- LEDs ni displays. Q se observa por q_reg y OE se representa en
    -- HEX1:0 y LEDR9.
    u_datapath : datapath
        generic map (
            ANCHO => 8
        )
        port map (
            clk      => clk,
            rst      => rst_global,
            dato_ext => sw(7 downto 0),
            cw       => cw,
            salida   => open,
            f_alu    => f_alu,
            q_reg    => q_reg
        );

    -- LEDs.
    ledr(7 downto 0) <= q_reg;
    ledr(8) <= m_reg;
    ledr(9) <= oe_reg;

    -- HEX5:HEX4 = dato externo.
    u_hex5 : hex7seg
        port map (
            valor => sw(7 downto 4),
            salida => hex5
        );

    u_hex4 : hex7seg
        port map (
            valor => sw(3 downto 0),
            salida => hex4
        );

    -- HEX3:HEX2 = resultado combinacional de la ALU.
    u_hex3 : hex7seg
        port map (
            valor => f_alu(7 downto 4),
            salida => hex3
        );

    u_hex2 : hex7seg
        port map (
            valor => f_alu(3 downto 0),
            salida => hex2
        );

    -- HEX1:HEX0 = Q. Se apagan cuando OE está deshabilitado;
    -- LEDR[7:0] sigue mostrando Q.
    u_hex1 : hex7seg
        port map (
            valor => q_reg(7 downto 4),
            salida => hex_q_hi
        );

    u_hex0 : hex7seg
        port map (
            valor => q_reg(3 downto 0),
            salida => hex_q_lo
        );

    hex1 <= hex_q_hi when oe_reg = '1' else (others => '1');
    hex0 <= hex_q_lo when oe_reg = '1' else (others => '1');

end architecture;
