-- ============================================================
-- control.vhd — Unidad de control del datapath-2 (FSM + microcódigo)
--
-- FSM secuencial que ejecuta uno de los tres algoritmos según 'modo':
--   modo = 00 : sumatoria  S(n) = 1 + 2 + ... + n
--   modo = 01 : factorial  n!
--   modo = 10 : multiplicación  A x B
--
-- 'paso' es la dirección absoluta de la ROM de microinstrucciones:
--   paso = modo * 32 + micropaso   (paso: 7 bits)
-- y elige 'modo' desde el arranque; debe mantenerse estable durante
-- la ejecución. Cada microinstrucción es una palabra de control que
-- fija sel_sup, wr_acc, clr_acc, addr, wr_rf, op_alu, sel_inf, sh y
-- out_en, más el control de secuencia (salta / salto_si_cero / dir /
-- fin). En cada flanco de subida: si fin = 0, paso <- dir (si salta,
-- o si salto_si_cero y cero = 1) o paso <- paso + 1; 'ciclos' cuenta
-- los microciclos ejecutados; con fin = 1 la FSM se detiene.
--
-- Las tablas de microoperaciones de docs/plan-datapath-3.md (§8.1-8.3)
-- son literalmente el contenido de esta ROM.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    modo  : in  unsigned(1 downto 0);   -- 00=suma, 01=factorial, 10=mult
    cero  : in  std_logic;              -- salida del shifter == 0
    -- palabra de control hacia el datapath
    sel_sup : out unsigned(1 downto 0);
    wr_acc  : out std_logic;
    clr_acc : out std_logic;
    addr    : out unsigned(2 downto 0);
    wr_rf   : out std_logic;
    op_alu  : out unsigned(2 downto 0);
    sel_inf : out std_logic;
    sh      : out unsigned(1 downto 0);
    out_en  : out std_logic;
    -- estado observable
    paso    : out unsigned(6 downto 0);
    ciclos  : out unsigned(15 downto 0);
    fin     : out std_logic
  );
end entity;

architecture fsm of control is
  -- Tipo de una microinstrucción (palabra de control + secuencia)
  type microinstr_t is record
    sel_sup        : unsigned(1 downto 0);
    wr_acc         : std_logic;
    clr_acc        : std_logic;
    addr           : unsigned(2 downto 0);
    wr_rf          : std_logic;
    op_alu         : unsigned(2 downto 0);
    sel_inf        : std_logic;
    sh             : unsigned(1 downto 0);
    out_en         : std_logic;
    salta          : std_logic;             -- salto incondicional
    salto_si_cero  : std_logic;             -- salto si cero = 1
    dir            : unsigned(6 downto 0);  -- destino del salto
    fin            : std_logic;             -- detiene la FSM
  end record;

  -- ROM de 128 microinstrucciones (paso de 7 bits)
  type rom_t is array (0 to 127) of microinstr_t;

  -- Palabra de control "en blanco" (no toca nada; sólo avanza)
  constant NOP : microinstr_t := (
    sel_sup => "00", wr_acc => '0', clr_acc => '0', addr => "000",
    wr_rf => '0', op_alu => "000", sel_inf => '0', sh => "00",
    out_en => '0', salta => '0', salto_si_cero => '0',
    dir => (others => '0'), fin => '0');

  -- Código de la ALU (tabla oficial §5)
  constant OP_PASAR : unsigned(2 downto 0) := "000";
  constant OP_SUMA  : unsigned(2 downto 0) := "001";
  constant OP_RESTA : unsigned(2 downto 0) := "010";
  constant OP_INC   : unsigned(2 downto 0) := "011";
  constant OP_DEC   : unsigned(2 downto 0) := "100";

  -- ROM construida con una función pura (VHDL-2008 conservador)
  function construir_rom return rom_t is
    variable r : rom_t := (others => NOP);

    -- ayudante para dejar una microinstrucción lista
    procedure pon(
      variable rr      : inout rom_t;
      constant p       : in    natural;
      constant v_sel_sup : in  unsigned(1 downto 0);
      constant v_wr_acc  : in  std_logic;
      constant v_clr_acc : in  std_logic;
      constant v_addr    : in  unsigned(2 downto 0);
      constant v_wr_rf   : in  std_logic;
      constant v_op_alu  : in  unsigned(2 downto 0);
      constant v_sel_inf : in  std_logic;
      constant v_out_en  : in  std_logic;
      constant v_salta   : in  std_logic;
      constant v_sic     : in  std_logic;
      constant v_dir     : in  unsigned(6 downto 0);
      constant v_fin     : in  std_logic) is
    begin
      rr(p) := (sel_sup => v_sel_sup, wr_acc => v_wr_acc, clr_acc => v_clr_acc,
                addr => v_addr, wr_rf => v_wr_rf, op_alu => v_op_alu,
                sel_inf => v_sel_inf, sh => "00", out_en => v_out_en,
                salta => v_salta, salto_si_cero => v_sic, dir => v_dir, fin => v_fin);
    end procedure;
  begin
    ----------------------------------------------------------------
    -- Modo 00 — Sumatoria S(n), ROM 0..10  (§8.1)
    ----------------------------------------------------------------
    -- 0: Acc <- 0
    pon(r, 0,  "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 1: Acc <- n (EXT1)
    pon(r, 1,  "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 2: R1 <- Acc  (i = n)
    pon(r, 2,  "00", '0', '0', "001", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 3: Acc <- 0
    pon(r, 3,  "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 4: Acc <- s (R2)
    pon(r, 4,  "10", '1', '0', "010", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 5: Acc <- s + i (R1 via ALU)
    pon(r, 5,  "11", '1', '0', "001", '0', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 6: R2 <- Acc (s nuevo)
    pon(r, 6,  "00", '0', '0', "010", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 7: Acc <- i (R1)
    pon(r, 7,  "10", '1', '0', "001", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 8: Acc <- i - 1 ; si cero -> paso 10
    pon(r, 8,  "11", '1', '0', "000", '0', OP_DEC,   '0', '0', '0', '1', "0001010", '0');
    -- 9: R1 <- Acc ; salta -> 4
    pon(r, 9,  "00", '0', '0', "001", '1', OP_PASAR, '0', '0', '1', '0', "0000100", '0');
    -- 10: Acc <- s (R2) ; out_en ; fin
    pon(r, 10, "10", '1', '0', "010", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

    ----------------------------------------------------------------
    -- Modo 01 — Factorial n!, ROM 32..63  (§8.2)
    ----------------------------------------------------------------
    -- 32: Acc <- 0
    pon(r, 32, "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 33: Acc <- 1 (EXT1)
    pon(r, 33, "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 34: R2 <- Acc (fact = 1)
    pon(r, 34, "00", '0', '0', "010", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 35: Acc <- n (EXT1)
    pon(r, 35, "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 36: Acc <- n - 1
    pon(r, 36, "11", '1', '0', "000", '0', OP_DEC,   '0', '0', '0', '0', "0000000", '0');
    -- 37: R5 <- Acc (veces = n - 1)
    pon(r, 37, "00", '0', '0', "101", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 38: Acc <- 2 (EXT1)
    pon(r, 38, "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 39: R1 <- Acc (i = 2)
    pon(r, 39, "00", '0', '0', "001", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 40: Acc <- 0
    pon(r, 40, "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 41: Acc <- 0 - R5 ; si cero -> 63
    pon(r, 41, "11", '1', '0', "101", '0', OP_RESTA, '0', '0', '0', '1', "0111111", '0');
    -- 42: Acc <- R2 (X = fact)
    pon(r, 42, "10", '1', '0', "010", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 43: R3 <- Acc (X)
    pon(r, 43, "00", '0', '0', "011", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 44: Acc <- R1 (Y = i)
    pon(r, 44, "10", '1', '0', "001", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 45: R4 <- Acc (Y)
    pon(r, 45, "00", '0', '0', "100", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 46: Acc <- 0
    pon(r, 46, "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 47: R6 <- Acc (P = 0)
    pon(r, 47, "00", '0', '0', "110", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 48: Acc <- P (R6)
    pon(r, 48, "10", '1', '0', "110", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 49: Acc <- P + X (R3)
    pon(r, 49, "11", '1', '0', "011", '0', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 50: R6 <- Acc (P nuevo)
    pon(r, 50, "00", '0', '0', "110", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 51: Acc <- Y (R4)
    pon(r, 51, "10", '1', '0', "100", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 52: Acc <- Y - 1 ; si cero -> 55
    pon(r, 52, "11", '1', '0', "000", '0', OP_DEC,   '0', '0', '0', '1', "0110111", '0');
    -- 53: R4 <- Acc (Y nuevo) ; salta -> 48
    pon(r, 53, "00", '0', '0', "100", '1', OP_PASAR, '0', '0', '1', '0', "0110000", '0');
    -- 54: salto -> 48 (bucle multiplicación)
    pon(r, 54, "00", '0', '0', "000", '0', OP_PASAR, '0', '0', '1', '0', "0110000", '0');
    -- 55: Acc <- P (R6)
    pon(r, 55, "10", '1', '0', "110", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 56: R2 <- Acc (fact = P)
    pon(r, 56, "00", '0', '0', "010", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 57: Acc <- i (R1)
    pon(r, 57, "10", '1', '0', "001", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 58: Acc <- i + 1
    pon(r, 58, "11", '1', '0', "000", '0', OP_INC,   '0', '0', '0', '0', "0000000", '0');
    -- 59: R1 <- Acc (i nuevo)
    pon(r, 59, "00", '0', '0', "001", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 60: Acc <- veces (R5)
    pon(r, 60, "10", '1', '0', "101", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 61: Acc <- veces - 1 ; si cero -> 63
    pon(r, 61, "11", '1', '0', "000", '0', OP_DEC,   '0', '0', '0', '1', "0111111", '0');
    -- 62: R5 <- Acc (veces nueva) ; salta -> 42
    pon(r, 62, "00", '0', '0', "101", '1', OP_PASAR, '0', '0', '1', '0', "0101010", '0');
    -- 63: Acc <- fact (R2) ; out_en ; fin
    pon(r, 63, "10", '1', '0', "010", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

    ----------------------------------------------------------------
    -- Modo 10 — Multiplicación A x B, ROM 64..78  (§8.3)
    ----------------------------------------------------------------
    -- 64: Acc <- 0
    pon(r, 64, "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 65: Acc <- A (EXT1)
    pon(r, 65, "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 66: R3 <- Acc (A)
    pon(r, 66, "00", '0', '0', "011", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 67: Acc <- B (EXT1)
    pon(r, 67, "00", '1', '0', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 68: R4 <- Acc (B)
    pon(r, 68, "00", '0', '0', "100", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 69: Acc <- 0
    pon(r, 69, "00", '0', '1', "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 70: R6 <- Acc (P = 0)
    pon(r, 70, "00", '0', '0', "110", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 71: Acc <- 0 - R4 ; si cero -> 78
    pon(r, 71, "11", '1', '0', "100", '0', OP_RESTA, '0', '0', '0', '1', "1001110", '0');
    -- 72: Acc <- P (R6)
    pon(r, 72, "10", '1', '0', "110", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 73: Acc <- P + A (R3)
    pon(r, 73, "11", '1', '0', "011", '0', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 74: R6 <- Acc (P nuevo)
    pon(r, 74, "00", '0', '0', "110", '1', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 75: Acc <- B' (R4)
    pon(r, 75, "10", '1', '0', "100", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 76: Acc <- B' - 1 ; si cero -> 78
    pon(r, 76, "11", '1', '0', "000", '0', OP_DEC,   '0', '0', '0', '1', "1001110", '0');
    -- 77: R4 <- Acc (B' nuevo) ; salta -> 72
    pon(r, 77, "00", '0', '0', "100", '1', OP_PASAR, '0', '0', '1', '0', "1001000", '0');
    -- 78: Acc <- P (R6) ; out_en ; fin
    pon(r, 78, "10", '1', '0', "110", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

    return r;
  end function;

  constant ROM : rom_t := construir_rom;

  signal paso_r  : unsigned(6 downto 0) := (others => '0');
  signal ciclos_r : unsigned(15 downto 0) := (others => '0');
  signal fin_r   : std_logic := '0';

  signal mi : microinstr_t;
begin
  -- Microinstrucción activa (combinacional)
  mi <= ROM(to_integer(paso_r));

  -- Salidas de control (combinacionales a partir de 'paso')
  sel_sup <= mi.sel_sup;
  wr_acc  <= mi.wr_acc;
  clr_acc <= mi.clr_acc;
  addr    <= mi.addr;
  wr_rf   <= mi.wr_rf;
  op_alu  <= mi.op_alu;
  sel_inf <= mi.sel_inf;
  sh      <= mi.sh;
  out_en  <= mi.out_en;
  paso    <= paso_r;
  ciclos  <= ciclos_r;
  fin     <= fin_r;

  -- Secuenciamiento: un microciclo por flanco de subida
  process(clk, rst)
    variable base : unsigned(6 downto 0);
  begin
    if rst = '1' then
      paso_r   <= (others => '0');
      ciclos_r <= (others => '0');
      fin_r    <= '0';
    elsif rising_edge(clk) then
      if fin_r = '0' then
        -- Arranque del algoritmo: fija la base según 'modo'
        if paso_r = 0 and ciclos_r = 0 then
          base := modo & "00000";   -- modo * 32
          paso_r <= base;
          ciclos_r <= to_unsigned(1, 16);
        else
          if mi.fin = '1' then
            -- Último microciclo: se detiene la FSM y 'paso' se
            -- mantiene para que las salidas de control (out_en) sigan
            -- válidas y la salida final quede estable.
            fin_r <= '1';
          elsif mi.salta = '1' or (mi.salto_si_cero = '1' and cero = '1') then
            paso_r <= mi.dir;
          else
            paso_r <= paso_r + 1;
          end if;
          ciclos_r <= ciclos_r + 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
