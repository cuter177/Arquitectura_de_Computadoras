-- ============================================================
-- Unidad de control genérica del proyecto final.
--
-- Mismo esquema que el control de datapath-3: un registro "paso"
-- direcciona una ROM de microinstrucciones; en cada flanco se
-- ejecuta la palabra activa y se decide el siguiente paso
-- (secuencial, salto incondicional o salto si el flag "cero").
--
-- La diferencia está en la generidad: la ROM se pasa como
-- parámetro genérico (PROGRAMA), de modo que el mismo motor
-- puede gobernar el datapath 3 o el motor paso a paso con solo
-- cambiar la tabla. La palabra incluye campos genéricos g_*.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.microcodigo_pkg.all;

entity control_gen is
    generic (
        PROGRAMA : rom_t := ROM
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;  -- habilitación (tick); '0' = mantener paso
        cero     : in  std_logic;  -- flag del hardware activo
        modo     : in  std_logic_vector(1 downto 0);

        -- Campos de control del datapath 3
        sel_sup : out std_logic_vector(1 downto 0);
        wr_acc  : out std_logic;
        clr_acc : out std_logic;
        addr    : out std_logic_vector(2 downto 0);
        wr_rf   : out std_logic;
        op_alu  : out std_logic_vector(2 downto 0);
        sel_inf : out std_logic;
        sh      : out std_logic_vector(1 downto 0);
        out_en  : out std_logic;

        -- Campos genéricos para el periférico activo
        g_dato : out std_logic_vector(ANCHO_DATO - 1 downto 0);
        g_wr   : out std_logic;
        g_en   : out std_logic;

        -- Estado observable
        fin    : out std_logic;
        paso   : out std_logic_vector(ANCHO_PASO - 1 downto 0);
        ciclos : out std_logic_vector(15 downto 0)
    );
end entity;

architecture fsm of control_gen is
    signal paso_reg   : unsigned(ANCHO_PASO - 1 downto 0) := (others => '0');
    signal ciclos_reg : unsigned(15 downto 0) := (others => '0');
    signal palabra    : micro_inst_t;
begin
    palabra <= PROGRAMA(to_integer(paso_reg));

    -- Salidas combinacionales a partir de la palabra activa
    sel_sup <= palabra.sel_sup;
    wr_acc  <= palabra.wr_acc;
    clr_acc <= palabra.clr_acc;
    addr    <= palabra.addr;
    wr_rf   <= palabra.wr_rf;
    op_alu  <= palabra.op_alu;
    sel_inf <= palabra.sel_inf;
    sh      <= palabra.sh;
    out_en  <= palabra.out_en;
    g_dato  <= palabra.g_dato;
    g_wr    <= palabra.g_wr;
    g_en    <= palabra.g_en;
    fin     <= palabra.fin;
    paso    <= std_logic_vector(paso_reg);
    ciclos  <= std_logic_vector(ciclos_reg);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- base = modo * 32 (los tres programas no se solapan)
                paso_reg   <= unsigned(modo & "00000");
                ciclos_reg <= (others => '0');
            elsif enable = '1' and palabra.fin = '0' then
                if palabra.salto_si_cero = '1' and cero = '1' then
                    paso_reg <= to_unsigned(palabra.dir_cero, ANCHO_PASO);
                elsif palabra.salta = '1' then
                    paso_reg <= to_unsigned(palabra.dir, ANCHO_PASO);
                else
                    paso_reg <= paso_reg + 1;
                end if;
                ciclos_reg <= ciclos_reg + 1;
            end if;
        end if;
    end process;
end architecture;
