-- ============================================================
-- datapath.vhd — Datapath 2 integrado (estructural)
--
-- Integra los ocho módulos del datapath: mux superior, acumulador,
-- banco de registros, ALU, mux inferior, shifter, detector de cero
-- y buffer de salida. El camino de datos es:
--
--   ext1/ext2/rf_out/sh_out --> [mux_superior] --> [acumulador] --> bus_acc
--   bus_acc --> ALU.A ; rf_out --> ALU.B ; ALU --> [mux_inferior] --> [shifter]
--   shifter --> sh_out (realimentación al mux superior y al detector de cero)
--   bus_acc --> banco (entrada de datos) y buffer de salida --> dato_out
--
-- El acumulador actúa como bus de datos: alimenta la entrada del
-- banco, el mux inferior y el buffer de salida.
-- 'cero' se calcula sobre la salida del shifter (el valor que se
-- escribirá en el acumulador). 'acc_q' y 'rf_dout' se exponen para
-- las ondas.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity datapath is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    ext1    : in  unsigned(7 downto 0);   -- dato externo 1 (n, A, B, constantes)
    -- señales de control
    sel_sup : in  unsigned(1 downto 0);
    wr_acc  : in  std_logic;
    clr_acc : in  std_logic;
    addr    : in  unsigned(2 downto 0);
    wr_rf   : in  std_logic;
    op_alu  : in  unsigned(2 downto 0);
    sel_inf : in  std_logic;
    sh      : in  unsigned(1 downto 0);
    out_en  : in  std_logic;
    -- salidas de datos y de estado
    dato_out : out unsigned(7 downto 0);
    cero     : out std_logic;              -- salida del shifter == 0
    acc_q    : out unsigned(7 downto 0);   -- valor del acumulador (ondas)
    rf_dout  : out unsigned(7 downto 0)    -- lectura del banco (ondas)
  );
end entity;

architecture estructural of datapath is
  signal bus_acc  : unsigned(7 downto 0);  -- salida del acumulador
  signal rf_out   : unsigned(7 downto 0);  -- lectura del banco
  signal alu_out  : unsigned(7 downto 0);  -- salida de la ALU
  signal mux_inf  : unsigned(7 downto 0);  -- salida del mux inferior
  signal sh_out   : unsigned(7 downto 0);  -- salida del shifter
  signal mux_sup  : unsigned(7 downto 0);  -- salida del mux superior
begin
  acc_q   <= bus_acc;
  rf_dout <= rf_out;

  u_mux_sup : entity work.mux_superior
    port map (
      ext1    => ext1,
      ext2    => (others => '0'),   -- EXT2 reservado, atado a 0
      rf_out  => rf_out,
      sh_out  => sh_out,
      sel_sup => sel_sup,
      dout    => mux_sup
    );

  u_acc : entity work.acumulador
    port map (
      clk   => clk,
      rst   => rst,
      d     => mux_sup,
      wr    => wr_acc,
      clear => clr_acc,
      q     => bus_acc
    );

  u_rf : entity work.banco_registros
    port map (
      clk  => clk,
      rst  => rst,
      addr => addr,
      din  => bus_acc,
      wr   => wr_rf,
      dout => rf_out
    );

  u_alu : entity work.alu
    port map (
      a      => bus_acc,
      b      => rf_out,
      op_alu => op_alu,
      f      => alu_out
    );

  u_mux_inf : entity work.mux_inferior
    port map (
      alu_out => alu_out,
      acc_out => bus_acc,
      sel_inf => sel_inf,
      dout    => mux_inf
    );

  u_shifter : entity work.shifter
    port map (
      d    => mux_inf,
      sh   => sh,
      dout => sh_out
    );

  u_cero : entity work.detector_cero
    port map (
      d    => sh_out,
      cero => cero
    );

  u_out : entity work.buffer_salida
    port map (
      d        => bus_acc,
      en       => out_en,
      dato_out => dato_out
    );
end architecture;
