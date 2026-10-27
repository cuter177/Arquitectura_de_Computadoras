-- =======================================================
-- Datapath 1: integración estructural del diagrama
-- MUX de entrada -> ALU -> Registro -> Buffer de salida,
-- con Q realimentada al operando B de la ALU.
-- Sin FSM y sin shifter externo (el desplazamiento de
-- 2n+x vive dentro de la ALU).
--
-- CW = [O.E, L, M, C2, C1, C0]:
--   cw(5) = O.E: habilita la salida
--          (desde Q, nunca desde F)
--   cw(4) = L:   carga F_ALU en el registro
--          en el flanco de clk
--   cw(3) = M:   '1' => dato_ext, '0' => constante cero
--   cw(2..0) = C: operación de la ALU
-- Especificación de implementación propuesta por el
-- equipo; los códigos NO están confirmados como
-- provenientes del profesor.
--
-- Se usa instanciación por componentes para que el
-- análisis sea independiente del orden
-- de los ficheros (scripts/vhdl-analizar).
--
-- f_alu y q_reg son salidas de observación para
-- testbenches y capturas de ondas.
-- =======================================================
library ieee;
use ieee.std_logic_1164.all;

entity datapath is
    generic (
        ANCHO : natural := 8
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        dato_ext : in std_logic_vector(ANCHO - 1 downto 0);
        cw     : in  std_logic_vector(5 downto 0);
        salida : out std_logic_vector(ANCHO - 1 downto 0);
        f_alu  : out std_logic_vector(ANCHO - 1 downto 0);
        q_reg  : out std_logic_vector(ANCHO - 1 downto 0)
    );
end entity;

architecture estructural of datapath is
    component mux_entrada is
        generic (
            ANCHO : natural := 8
        );
        port (
            dato_ext : in std_logic_vector(ANCHO - 1
                downto 0);
            sel : in  std_logic;
            y   : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    component alu is
        generic (
            ANCHO : natural := 8
        );
        port (
            a : in  std_logic_vector(ANCHO - 1 downto 0);
            b : in  std_logic_vector(ANCHO - 1 downto 0);
            c : in  std_logic_vector(2 downto 0);
            f : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    component registro is
        generic (
            ANCHO : natural := 8
        );
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            l   : in  std_logic;
            d   : in  std_logic_vector(ANCHO - 1 downto 0);
            q   : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    component buffer_salida is
        generic (
            ANCHO : natural := 8
        );
        port (
            d_in : in  std_logic_vector(ANCHO - 1 downto 0);
            oe   : in  std_logic;
            y    : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    -- desempaquetado de la palabra de control
    signal oe : std_logic;
    signal l  : std_logic;
    signal m  : std_logic;
    signal c  : std_logic_vector(2 downto 0);

    -- buses internos (replica del diagrama):
    --   a_bus = MUX -> ALU
    --   b_bus = Q -> ALU
    --   f_bus = ALU -> D del registro
    --   q_bus = salida del registro
    signal a_bus : std_logic_vector(ANCHO - 1 downto 0);
    signal b_bus : std_logic_vector(ANCHO - 1 downto 0);
    signal f_bus : std_logic_vector(ANCHO - 1 downto 0);
    signal q_bus : std_logic_vector(ANCHO - 1 downto 0);
begin
    oe <= cw(5);
    l  <= cw(4);
    m  <= cw(3);
    c  <= cw(2 downto 0);

    -- realimentación: Q es el operando B (n)
    b_bus <= q_bus;

    u_mux : mux_entrada
        generic map (ANCHO => ANCHO)
        port map (
            dato_ext => dato_ext,
            sel      => m,
            y        => a_bus
        );

    u_alu : alu
        generic map (ANCHO => ANCHO)
        port map (
            a => a_bus,
            b => b_bus,
            c => c,
            f => f_bus
        );

    u_registro : registro
        generic map (ANCHO => ANCHO)
        port map (
            clk => clk,
            rst => rst,
            l   => l,
            d   => f_bus,
            q   => q_bus
        );

    u_buffer : buffer_salida
        generic map (ANCHO => ANCHO)
        port map (
            -- la salida sale del REGISTRO, no de la ALU
            d_in => q_bus,
            oe   => oe,
            y    => salida
        );

    -- salidas de observación (testbenches y capturas)
    f_alu <= f_bus;
    q_reg <= q_bus;
end architecture;
