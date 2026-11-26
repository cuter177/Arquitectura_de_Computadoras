-- ============================================================
-- Paquete de microcódigo del proyecto final.
--
-- Define el formato de la palabra de control (microinstrucción)
-- y las tablas de los tres programas que ejecuta el motor genérico:
--   modo 00 (base 0)   -> multiplicación shift-add
--   modo 01 (base 32)  -> popcount (conteo de unos de un byte)
--   modo 10 (base 64)  -> motor paso a paso NEMA 17
--
-- El mismo tipo de microinstrucción alimenta hardware distinto:
-- los campos "g_*" son genéricos y los interpreta el periférico
-- activo (en este caso, motor_pasos).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

package microcodigo_pkg is
    constant ANCHO_DATO      : natural := 8;
    constant ANCHO_PASO      : natural := 7;
    constant PROFUNDIDAD_ROM : natural := 128;

    type micro_inst_t is record
        -- Campos del datapath 3
        sel_sup : std_logic_vector(1 downto 0);
        wr_acc  : std_logic;
        clr_acc : std_logic;
        addr    : std_logic_vector(2 downto 0);
        wr_rf   : std_logic;
        op_alu  : std_logic_vector(2 downto 0);
        sel_inf : std_logic;
        sh      : std_logic_vector(1 downto 0);
        out_en  : std_logic;
        -- Campos genéricos (periférico activo)
        g_dato  : std_logic_vector(ANCHO_DATO - 1 downto 0);
        g_wr    : std_logic;
        g_en    : std_logic;
        -- Control de flujo
        salta         : std_logic;
        salto_si_cero : std_logic;
        dir           : natural range 0 to PROFUNDIDAD_ROM - 1;
        dir_cero      : natural range 0 to PROFUNDIDAD_ROM - 1;
        fin           : std_logic;
    end record;

    type rom_t is array (0 to PROFUNDIDAD_ROM - 1) of micro_inst_t;

    -- Constructor con valores por defecto: "no hacer nada, seguir al
    -- siguiente paso". Permite escribir cada palabra indicando solo
    -- los campos que importan en ese microciclo.
    function mk(
        sel_sup       : std_logic_vector(1 downto 0) := "00";
        wr_acc        : std_logic := '0';
        clr_acc       : std_logic := '0';
        addr          : std_logic_vector(2 downto 0) := "000";
        wr_rf         : std_logic := '0';
        op_alu        : std_logic_vector(2 downto 0) := "000";
        sel_inf       : std_logic := '0';
        sh            : std_logic_vector(1 downto 0) := "00";
        out_en        : std_logic := '0';
        g_dato        : std_logic_vector(ANCHO_DATO - 1 downto 0) := (others => '0');
        g_wr          : std_logic := '0';
        g_en          : std_logic := '0';
        salta         : std_logic := '0';
        salto_si_cero : std_logic := '0';
        dir           : natural := 0;
        dir_cero      : natural := 0;
        fin           : std_logic := '0'
    ) return micro_inst_t;

    -- Constante diferida: se define en el body, después de mk, para
    -- que GHDL no avise de llamada antes de elaborar el cuerpo.
    constant ROM : rom_t;

end package microcodigo_pkg;

package body microcodigo_pkg is
    function mk(
        sel_sup       : std_logic_vector(1 downto 0) := "00";
        wr_acc        : std_logic := '0';
        clr_acc       : std_logic := '0';
        addr          : std_logic_vector(2 downto 0) := "000";
        wr_rf         : std_logic := '0';
        op_alu        : std_logic_vector(2 downto 0) := "000";
        sel_inf       : std_logic := '0';
        sh            : std_logic_vector(1 downto 0) := "00";
        out_en        : std_logic := '0';
        g_dato        : std_logic_vector(ANCHO_DATO - 1 downto 0) := (others => '0');
        g_wr          : std_logic := '0';
        g_en          : std_logic := '0';
        salta         : std_logic := '0';
        salto_si_cero : std_logic := '0';
        dir           : natural := 0;
        dir_cero      : natural := 0;
        fin           : std_logic := '0'
    ) return micro_inst_t is
        variable p : micro_inst_t;
    begin
        p.sel_sup       := sel_sup;
        p.wr_acc        := wr_acc;
        p.clr_acc       := clr_acc;
        p.addr          := addr;
        p.wr_rf         := wr_rf;
        p.op_alu        := op_alu;
        p.sel_inf       := sel_inf;
        p.sh            := sh;
        p.out_en        := out_en;
        p.g_dato        := g_dato;
        p.g_wr          := g_wr;
        p.g_en          := g_en;
        p.salta         := salta;
        p.salto_si_cero := salto_si_cero;
        p.dir           := dir;
        p.dir_cero      := dir_cero;
        p.fin           := fin;
        return p;
    end function mk;

    constant ROM : rom_t := (
        ------------------------------------------------------------------
        -- Programa 0 (modo 00): multiplicación shift-add, pasos 0..20
        -- R0 = 1 (constante para la ALU), R1 = A, R2 = B, R3 = producto.
        -- EXT1: paso 1 -> 1, paso 3 -> A, paso 5 -> B.
        ------------------------------------------------------------------
        0  => mk(clr_acc => '1'),                                    -- Acc <- 0
        1  => mk(wr_acc => '1'),                                     -- Acc <- 1 (EXT1)
        2  => mk(wr_rf => '1', addr => "000"),                       -- R0 <- 1
        3  => mk(wr_acc => '1'),                                     -- Acc <- A (EXT1)
        4  => mk(wr_rf => '1', addr => "001"),                       -- R1 <- A
        5  => mk(wr_acc => '1'),                                     -- Acc <- B (EXT1)
        6  => mk(wr_rf => '1', addr => "010"),                       -- R2 <- B
        7  => mk(clr_acc => '1'),                                    -- Acc <- 0
        8  => mk(wr_rf => '1', addr => "011"),                       -- R3 <- P = 0
        9  => mk(wr_acc => '1', sel_sup => "10", addr => "010"),     -- Acc <- B
        10 => mk(wr_acc => '1', sel_sup => "11", op_alu => "110",
                 addr => "000", salto_si_cero => '1', dir_cero => 14),-- B & 1; si 0 -> 14
        11 => mk(wr_acc => '1', sel_sup => "10", addr => "011"),     -- Acc <- P
        12 => mk(wr_acc => '1', sel_sup => "11", op_alu => "001",
                 addr => "001"),                                     -- Acc <- P + A
        13 => mk(wr_rf => '1', addr => "011"),                       -- R3 <- P
        14 => mk(wr_acc => '1', sel_sup => "10", addr => "001"),     -- Acc <- A
        15 => mk(wr_acc => '1', sel_sup => "11", op_alu => "000",
                 sh => "01"),                                        -- Acc <- A << 1
        16 => mk(wr_rf => '1', addr => "001"),                       -- R1 <- A'
        17 => mk(wr_acc => '1', sel_sup => "10", addr => "010"),     -- Acc <- B
        18 => mk(wr_acc => '1', sel_sup => "11", op_alu => "000",
                 sh => "10", salto_si_cero => '1', dir_cero => 20),  -- B >> 1; si 0 -> fin
        19 => mk(wr_rf => '1', addr => "010", salta => '1', dir => 9),-- R2 <- B', ir a 9
        20 => mk(wr_acc => '1', sel_sup => "10", addr => "011",
                 out_en => '1', fin => '1'),                         -- Acc <- P (fin)
        ------------------------------------------------------------------
        -- Programa 1 (modo 01): popcount, pasos 32..48
        -- R0 = 1, R1 = x, R3 = conteo. EXT1: paso 33 -> 1, paso 35 -> x.
        ------------------------------------------------------------------
        32 => mk(clr_acc => '1'),
        33 => mk(wr_acc => '1'),                                     -- Acc <- 1 (EXT1)
        34 => mk(wr_rf => '1', addr => "000"),                       -- R0 <- 1
        35 => mk(wr_acc => '1'),                                     -- Acc <- x (EXT1)
        36 => mk(wr_rf => '1', addr => "001"),                       -- R1 <- x
        37 => mk(clr_acc => '1'),
        38 => mk(wr_rf => '1', addr => "011"),                       -- R3 <- conteo = 0
        39 => mk(wr_acc => '1', sel_sup => "10", addr => "001"),     -- Acc <- x
        40 => mk(wr_acc => '1', sel_sup => "11", op_alu => "110",
                 addr => "000", salto_si_cero => '1', dir_cero => 44),-- x & 1; si 0 -> 44
        41 => mk(wr_acc => '1', sel_sup => "10", addr => "011"),     -- Acc <- conteo
        42 => mk(wr_acc => '1', sel_sup => "11", op_alu => "011"),   -- Acc <- conteo + 1
        43 => mk(wr_rf => '1', addr => "011"),                       -- R3 <- conteo
        44 => mk(wr_acc => '1', sel_sup => "10", addr => "001"),     -- Acc <- x
        45 => mk(wr_acc => '1', sel_sup => "11", op_alu => "000",
                 sh => "10", salto_si_cero => '1', dir_cero => 48),  -- x >> 1; si 0 -> fin
        46 => mk(wr_rf => '1', addr => "001", salta => '1', dir => 39),
        47 => mk(salta => '1', dir => 39),                           -- (no alcanzado)
        48 => mk(wr_acc => '1', sel_sup => "10", addr => "011",
                 out_en => '1', fin => '1'),                         -- Acc <- conteo (fin)
        ------------------------------------------------------------------
        -- Programa 2 (modo 10): motor NEMA 17, pasos 64..69
        -- g_wr carga el número de pasos; cada g_en avanza una fase.
        -- El flag "cero" del motor detiene la secuencia al agotar los pasos.
        ------------------------------------------------------------------
        64 => mk(g_wr => '1'),                                       -- cargar pasos
        65 => mk(g_dato => x"00", g_en => '1',
                 salto_si_cero => '1', dir_cero => 69),              -- fase 0
        66 => mk(g_dato => x"01", g_en => '1',
                 salto_si_cero => '1', dir_cero => 69),              -- fase 1
        67 => mk(g_dato => x"02", g_en => '1',
                 salto_si_cero => '1', dir_cero => 69),              -- fase 2
        68 => mk(g_dato => x"03", g_en => '1', salta => '1', dir => 65),-- fase 3
        69 => mk(out_en => '1', fin => '1'),                         -- fin
        -- Cualquier otra dirección: palabra de fin (falla pronto y se ve)
        others => mk(fin => '1')
    );

end package body microcodigo_pkg;
