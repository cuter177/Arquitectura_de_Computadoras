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
-- fija sel_sup, addr (lectura A / dirección destino), addr_b
-- (lectura B), wr_rf, op_alu, sel_inf, sh y out_en, más el control
-- de secuencia (salta / salto_si_cero / dir / fin).
--
-- El banco de registros de doble lectura es el único almacenamiento
-- del datapath: cada microciclo lee sus operandos (addr y addr_b),
-- la ALU los combina y el resultado se escribe en el mismo flanco
-- (wr_rf). No hay registros dedicados.
--
-- Modelo temporal: en cada flanco de subida, si fin = 0,
-- paso <- dir (si salta, o si salto_si_cero y cero = 1) o
-- paso <- paso + 1; 'ciclos' cuenta los microciclos ejecutados;
-- con fin = 1 la FSM se detiene y mantiene las salidas (addr,
-- out_en) para que la salida final quede estable.
--
-- Codificación de la palabra de control (ver datapath actualizado):
--   sel_sup : 00 = EXT1, 01 = EXT2 (reservado), 10 = lectura A,
--             11 = lectura B
--   sel_inf : 0 = salida de la ALU, 1 = fuente directa (sin ALU)
--   op_alu  : tabla oficial §5 (000 pasar, 001 suma, 010 resta,
--             011 inc, 100 dec, ...)
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
    addr    : out unsigned(2 downto 0);  -- lectura A / dirección destino
    addr_b  : out unsigned(2 downto 0);  -- lectura B (segundo operando)
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
    addr           : unsigned(2 downto 0);
    addr_b         : unsigned(2 downto 0);
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
    sel_sup => "00", addr => "000", addr_b => "000", wr_rf => '0',
    op_alu => "000", sel_inf => '0', sh => "00", out_en => '0',
    salta => '0', salto_si_cero => '0',
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
      variable rr       : inout rom_t;
      constant p        : in    natural;
      constant v_sel_sup : in  unsigned(1 downto 0);
      constant v_addr    : in  unsigned(2 downto 0);
      constant v_addr_b  : in  unsigned(2 downto 0);
      constant v_wr_rf   : in  std_logic;
      constant v_op_alu  : in  unsigned(2 downto 0);
      constant v_sel_inf : in  std_logic;
      constant v_out_en  : in  std_logic;
      constant v_salta   : in  std_logic;
      constant v_sic     : in  std_logic;
      constant v_dir     : in  unsigned(6 downto 0);
      constant v_fin     : in  std_logic) is
    begin
      rr(p) := (sel_sup => v_sel_sup, addr => v_addr, addr_b => v_addr_b,
                wr_rf => v_wr_rf, op_alu => v_op_alu, sel_inf => v_sel_inf,
                sh => "00", out_en => v_out_en,
                salta => v_salta, salto_si_cero => v_sic, dir => v_dir,
                fin => v_fin);
    end procedure;
  begin
    ----------------------------------------------------------------
    -- Modo 00 — Sumatoria S(n), ROM 0..6
    -- Registros: R1 = i (contador), R2 = s (suma parcial)
    ----------------------------------------------------------------
    -- 0: NOP (la FSM ejecuta este paso antes de fijar la base del modo)
    pon(r, 0,  "00", "000", "000", '0', OP_PASAR, '0', '0', '0', '0', "0000000", '0');
    -- 1: R1 <- n (EXT1)
    pon(r, 1,  "00", "001", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 2: R2 <- 0 (EXT1)
    pon(r, 2,  "00", "010", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 3: R2 <- R2 + R1  (lectura A = R2, lectura B = R1)
    pon(r, 3,  "10", "010", "001", '1', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 4: R1 <- R1 - 1 ; si cero -> paso 6
    pon(r, 4,  "10", "001", "000", '1', OP_DEC,   '0', '0', '0', '1', "0000110", '0');
    -- 5: salta -> 3 (bucle de acumulación)
    pon(r, 5,  "00", "000", "000", '0', OP_PASAR, '0', '0', '1', '0', "0000011", '0');
    -- 6: dato_out <- R2 (out_en) ; fin
    pon(r, 6,  "10", "010", "000", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

    ----------------------------------------------------------------
    -- Modo 01 — Factorial n!, ROM 32..46
    -- Registros: R1 = i, R2 = fact, R3 = X, R4 = Y, R5 = veces, R6 = P
    ----------------------------------------------------------------
    -- 32: R2 <- 1 (EXT1)   fact = 1
    pon(r, 32, "00", "010", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 33: R5 <- n - 1 (EXT1 por la ALU)   veces = n - 1
    pon(r, 33, "00", "101", "000", '1', OP_DEC,   '0', '0', '0', '0', "0000000", '0');
    -- 34: R1 <- 2 (EXT1)   i = 2
    pon(r, 34, "00", "001", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 35: test R5 == 0 (lectura A, sin escritura) ; si cero -> 46
    pon(r, 35, "10", "101", "000", '0', OP_PASAR, '0', '0', '0', '1', "0101110", '0');
    -- 36: R3 <- R2 (copia por bypass, lectura B = R2)   X = fact
    pon(r, 36, "11", "011", "010", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 37: R4 <- R1 (copia por bypass, lectura B = R1)   Y = i
    pon(r, 37, "11", "100", "001", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 38: R6 <- 0 (EXT1)   P = 0
    pon(r, 38, "00", "110", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 39: R6 <- R6 + R3  (cabeza del bucle interno de suma repetida)
    pon(r, 39, "10", "110", "011", '1', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 40: R4 <- R4 - 1 ; si cero -> 42 (fin del producto)
    pon(r, 40, "10", "100", "000", '1', OP_DEC,   '0', '0', '0', '1', "0101010", '0');
    -- 41: salta -> 39 (bucle interno)
    pon(r, 41, "00", "000", "000", '0', OP_PASAR, '0', '0', '1', '0', "0100111", '0');
    -- 42: R2 <- R6 (copia por bypass, lectura B = R6)   fact = P
    pon(r, 42, "11", "010", "110", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 43: R1 <- R1 + 1   i = i + 1
    pon(r, 43, "10", "001", "000", '1', OP_INC,   '0', '0', '0', '0', "0000000", '0');
    -- 44: R5 <- R5 - 1 ; si cero -> 46 (fin del bucle externo)
    pon(r, 44, "10", "101", "000", '1', OP_DEC,   '0', '0', '0', '1', "0101110", '0');
    -- 45: salta -> 36 (bucle externo)
    pon(r, 45, "00", "000", "000", '0', OP_PASAR, '0', '0', '1', '0', "0100100", '0');
    -- 46: dato_out <- R2 (out_en) ; fin
    pon(r, 46, "10", "010", "000", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

    ----------------------------------------------------------------
    -- Modo 10 — Multiplicación A x B, ROM 64..71
    -- Registros: R3 = A, R4 = B (contador), R6 = P
    ----------------------------------------------------------------
    -- 64: R3 <- A (EXT1)
    pon(r, 64, "00", "011", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 65: R4 <- B (EXT1)
    pon(r, 65, "00", "100", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 66: R6 <- 0 (EXT1)   P = 0
    pon(r, 66, "00", "110", "000", '1', OP_PASAR, '1', '0', '0', '0', "0000000", '0');
    -- 67: test R4 == 0 (lectura A, sin escritura) ; si cero -> 71
    pon(r, 67, "10", "100", "000", '0', OP_PASAR, '0', '0', '0', '1', "1000111", '0');
    -- 68: R6 <- R6 + R3  (cabeza del bucle de suma repetida)
    pon(r, 68, "10", "110", "011", '1', OP_SUMA,  '0', '0', '0', '0', "0000000", '0');
    -- 69: R4 <- R4 - 1 ; si cero -> 71 (fin del bucle)
    pon(r, 69, "10", "100", "000", '1', OP_DEC,   '0', '0', '0', '1', "1000111", '0');
    -- 70: salta -> 68 (bucle)
    pon(r, 70, "00", "000", "000", '0', OP_PASAR, '0', '0', '1', '0', "1000100", '0');
    -- 71: dato_out <- R6 (out_en) ; fin
    pon(r, 71, "10", "110", "000", '0', OP_PASAR, '0', '1', '0', '0', "0000000", '1');

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
  addr    <= mi.addr;
  addr_b  <= mi.addr_b;
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
            -- mantiene para que las salidas de control (out_en,
            -- addr) sigan válidas y la salida final quede estable.
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
