-- ============================================================
-- Unidad de control del Datapath 3 (FSM secuencial)
-- Genera las señales de control del datapath a partir de una
-- ROM de microinstrucciones: la tabla de microoperaciones del
-- plan (docs/plan-datapath-3.md, §8) es literalmente el
-- contenido de la ROM.
--
--   * paso (7 bits) = dirección de microcódigo activa;
--     base = modo * 32  (00=exp1, 01=exp2, 10=exp3, 11=exp4)
--   * un microciclo por flanco de subida;
--   * salto incondicional (salta) o condicional (salto_si_cero
--     con el flag "cero" del datapath);
--   * fin = última palabra del algoritmo; el contador se detiene;
--   * ciclos = microciclos ejecutados hasta alcanzar "fin".
--
-- "modo" debe mantenerse estable durante la ejecución.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        cero       : in  std_logic;
        modo       : in  std_logic_vector(1 downto 0);
        sel_sup    : out std_logic_vector(1 downto 0);
        wr_acc     : out std_logic;
        clr_acc    : out std_logic;
        addr       : out std_logic_vector(2 downto 0);
        wr_rf      : out std_logic;
        op_alu     : out std_logic_vector(2 downto 0);
        sel_inf    : out std_logic;
        sh         : out std_logic_vector(1 downto 0);
        out_en     : out std_logic;
        fin        : out std_logic;
        paso       : out std_logic_vector(6 downto 0);
        ciclos     : out std_logic_vector(15 downto 0)
    );
end entity;

architecture fsm of control is
    type palabra_t is record
        sel_sup       : std_logic_vector(1 downto 0);
        wr_acc        : std_logic;
        clr_acc       : std_logic;
        addr          : std_logic_vector(2 downto 0);
        wr_rf         : std_logic;
        op_alu        : std_logic_vector(2 downto 0);
        sel_inf       : std_logic;
        sh            : std_logic_vector(1 downto 0);
        out_en        : std_logic;
        salta         : std_logic;
        salto_si_cero : std_logic;
        dir           : natural range 0 to 127;
        fin           : std_logic;
    end record;

    type rom_t is array (0 to 127) of palabra_t;

    -- constructor de palabras: los campos no indicados toman su
    -- valor por defecto (sin escritura, sin salto, op = pasar)
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
        salta         : std_logic := '0';
        salto_si_cero : std_logic := '0';
        dir           : natural := 0;
        fin           : std_logic := '0'
    ) return palabra_t is
        variable p : palabra_t;
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
        p.salta         := salta;
        p.salto_si_cero := salto_si_cero;
        p.dir           := dir;
        p.fin           := fin;
        return p;
    end function;

    -- ROM de microinstrucciones (tabla §8 del plan)
    constant ROM : rom_t := (
        ----------------------------------------------------------------
        -- Exp 1: suma de 1..n (pasos 0..10) — plan §8.1
        ----------------------------------------------------------------
        0  => mk(clr_acc => '1'),
        1  => mk(wr_acc => '1'),                                  -- Acc ← n (EXT1)
        2  => mk(wr_rf => '1', addr => "001"),                    -- R1 ← Acc
        3  => mk(clr_acc => '1'),                                 -- s = 0
        4  => mk(wr_acc => '1', sel_sup => "10", addr => "010"),  -- Acc ← s
        5  => mk(wr_acc => '1', sel_sup => "11", op_alu => "001",
                 addr => "001"),                                  -- Acc ← s + i
        6  => mk(wr_rf => '1', addr => "010"),                    -- R2 ← Acc
        7  => mk(wr_acc => '1', sel_sup => "10", addr => "001"),  -- Acc ← i
        8  => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                 salto_si_cero => '1', dir => 10),                -- Acc ← i-1
        9  => mk(wr_rf => '1', addr => "001", salta => '1', dir => 4),
        10 => mk(wr_acc => '1', sel_sup => "10", addr => "010",
                 out_en => '1', fin => '1'),                      -- Acc ← s (fin)
        ----------------------------------------------------------------
        -- Exp 2: factorial de n (pasos 32..63) — plan §8.2
        ----------------------------------------------------------------
        32 => mk(clr_acc => '1'),
        33 => mk(wr_acc => '1'),                                  -- Acc ← 1 (EXT1)
        34 => mk(wr_rf => '1', addr => "010"),                    -- fact = 1
        35 => mk(wr_acc => '1'),                                  -- Acc ← n (EXT1)
        36 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100"),-- Acc ← n-1
        37 => mk(wr_rf => '1', addr => "101"),                    -- veces = n-1
        38 => mk(wr_acc => '1'),                                  -- Acc ← 2 (EXT1)
        39 => mk(wr_rf => '1', addr => "001"),                    -- i = 2
        40 => mk(clr_acc => '1'),
        41 => mk(wr_acc => '1', sel_sup => "11", op_alu => "010",
                 addr => "101", salto_si_cero => '1', dir => 63), -- ¿n = 1?
        42 => mk(wr_acc => '1', sel_sup => "10", addr => "010"),  -- X = fact
        43 => mk(wr_rf => '1', addr => "011"),
        44 => mk(wr_acc => '1', sel_sup => "10", addr => "001"),  -- Y = i
        45 => mk(wr_rf => '1', addr => "100"),
        46 => mk(clr_acc => '1'),
        47 => mk(wr_rf => '1', addr => "110"),                    -- P = 0
        48 => mk(wr_acc => '1', sel_sup => "10", addr => "110"),  -- P (bucle)
        49 => mk(wr_acc => '1', sel_sup => "11", op_alu => "001",
                 addr => "011"),                                  -- P + X
        50 => mk(wr_rf => '1', addr => "110"),
        51 => mk(wr_acc => '1', sel_sup => "10", addr => "100"),  -- Y
        52 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                 salto_si_cero => '1', dir => 55),                -- Y-1
        53 => mk(wr_rf => '1', addr => "100", salta => '1', dir => 48),
        54 => mk(salta => '1', dir => 48),                        -- (no alcanzado)
        55 => mk(wr_acc => '1', sel_sup => "10", addr => "110"),  -- producto
        56 => mk(wr_rf => '1', addr => "010"),                    -- fact ← P
        57 => mk(wr_acc => '1', sel_sup => "10", addr => "001"),  -- i
        58 => mk(wr_acc => '1', sel_sup => "11", op_alu => "011"),-- i+1
        59 => mk(wr_rf => '1', addr => "001"),
        60 => mk(wr_acc => '1', sel_sup => "10", addr => "101"),  -- veces
        61 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                 salto_si_cero => '1', dir => 63),                -- veces-1
        62 => mk(wr_rf => '1', addr => "101", salta => '1', dir => 42),
        63 => mk(wr_acc => '1', sel_sup => "10", addr => "010",
                 out_en => '1', fin => '1'),                      -- n! (fin)
        ----------------------------------------------------------------
        -- Exp 3: multiplicación A x B (pasos 64..78) — plan §8.3
        ----------------------------------------------------------------
        64 => mk(clr_acc => '1'),
        65 => mk(wr_acc => '1'),                                  -- Acc ← A (EXT1)
        66 => mk(wr_rf => '1', addr => "011"),
        67 => mk(wr_acc => '1'),                                  -- Acc ← B (EXT1)
        68 => mk(wr_rf => '1', addr => "100"),
        69 => mk(clr_acc => '1'),
        70 => mk(wr_rf => '1', addr => "110"),                    -- P = 0
        71 => mk(wr_acc => '1', sel_sup => "11", op_alu => "010",
                 addr => "100", salto_si_cero => '1', dir => 78), -- ¿B = 0?
        72 => mk(wr_acc => '1', sel_sup => "10", addr => "110"),  -- P (bucle)
        73 => mk(wr_acc => '1', sel_sup => "11", op_alu => "001",
                 addr => "011"),                                  -- P + A
        74 => mk(wr_rf => '1', addr => "110"),
        75 => mk(wr_acc => '1', sel_sup => "10", addr => "100"),  -- B'
        76 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                 salto_si_cero => '1', dir => 78),                -- B'-1
        77 => mk(wr_rf => '1', addr => "100", salta => '1', dir => 72),
        78 => mk(wr_acc => '1', sel_sup => "10", addr => "110",
                 out_en => '1', fin => '1'),                      -- A x B (fin)
        ----------------------------------------------------------------
        -- Exp 4: Fibonacci F(n) (pasos 96..118) — plan §8.4
        -- Con a=0, b=1, k iteraciones dejan b = F(k+1); por eso el
        -- bucle se ejecuta n-1 veces (y n = 0 / n = 1 salen antes).
        ----------------------------------------------------------------
        96  => mk(clr_acc => '1'),
        97  => mk(wr_rf => '1', addr => "010"),                   -- a = 0
        98  => mk(wr_acc => '1'),                                 -- Acc ← 1 (EXT1)
        99  => mk(wr_rf => '1', addr => "011"),                   -- b = 1
        100 => mk(wr_acc => '1'),                                 -- Acc ← n (EXT1)
        101 => mk(wr_rf => '1', addr => "001"),
        102 => mk(clr_acc => '1'),
        103 => mk(wr_acc => '1', sel_sup => "11", op_alu => "010",
                  addr => "001", salto_si_cero => '1', dir => 117), -- ¿n = 0?
        104 => mk(wr_acc => '1', sel_sup => "10", addr => "001"), -- Acc ← n
        105 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                  salto_si_cero => '1', dir => 118),              -- ¿n = 1?
        106 => mk(wr_rf => '1', addr => "001"),                   -- R1 = n-1
        107 => mk(wr_acc => '1', sel_sup => "10", addr => "010"), -- a
        108 => mk(wr_acc => '1', sel_sup => "11", op_alu => "001",
                  addr => "011"),                                 -- next = a+b
        109 => mk(wr_rf => '1', addr => "100"),
        110 => mk(wr_acc => '1', sel_sup => "10", addr => "011"), -- b
        111 => mk(wr_rf => '1', addr => "010"),                   -- a' = b
        112 => mk(wr_acc => '1', sel_sup => "10", addr => "100"), -- next
        113 => mk(wr_rf => '1', addr => "011"),                   -- b' = next
        114 => mk(wr_acc => '1', sel_sup => "10", addr => "001"), -- R1
        115 => mk(wr_acc => '1', sel_sup => "11", op_alu => "100",
                  salto_si_cero => '1', dir => 118),              -- R1-1
        116 => mk(wr_rf => '1', addr => "001", salta => '1', dir => 107),
        117 => mk(wr_acc => '1', sel_sup => "10", addr => "010",
                  out_en => '1', fin => '1'),                     -- F(0) (fin)
        118 => mk(wr_acc => '1', sel_sup => "10", addr => "011",
                  out_en => '1', fin => '1'),                     -- F(n) (fin)
        -- cualquier otra dirección: palabra fin (falla pronto y se ve)
        others => mk(fin => '1')
    );

    signal paso_reg   : unsigned(6 downto 0) := (others => '0');
    signal ciclos_reg : unsigned(15 downto 0) := (others => '0');
    signal palabra    : palabra_t;
begin
    palabra <= ROM(to_integer(paso_reg));

    sel_sup <= palabra.sel_sup;
    wr_acc  <= palabra.wr_acc;
    clr_acc <= palabra.clr_acc;
    addr    <= palabra.addr;
    wr_rf   <= palabra.wr_rf;
    op_alu  <= palabra.op_alu;
    sel_inf <= palabra.sel_inf;
    sh      <= palabra.sh;
    out_en  <= palabra.out_en;
    fin     <= palabra.fin;
    paso    <= std_logic_vector(paso_reg);
    ciclos  <= std_logic_vector(ciclos_reg);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                paso_reg   <= unsigned(modo & "00000");  -- base = modo * 32
                ciclos_reg <= (others => '0');
            elsif palabra.fin = '0' then
                if palabra.salto_si_cero = '1' and cero = '1' then
                    paso_reg <= to_unsigned(palabra.dir, 7);
                elsif palabra.salta = '1' then
                    paso_reg <= to_unsigned(palabra.dir, 7);
                else
                    paso_reg <= paso_reg + 1;
                end if;
                ciclos_reg <= ciclos_reg + 1;
            end if;
        end if;
    end process;
end architecture;
