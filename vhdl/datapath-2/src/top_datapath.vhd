-- ============================================================
-- top_datapath.vhd — Datapath 2 integrado (estructural)
--
-- Integra los siete módulos del datapath: mux superior, banco de
-- registros de doble lectura, ALU, mux inferior, shifter, detector
-- de cero y buffer de salida. El banco de registros es el único
-- elemento de almacenamiento (operandos y resultados intermedios).
-- El camino de datos es:
--
--   ext1/ext2/rf_a/rf_b --> [mux_superior] --> fuente --> ALU.A
--   rf_b --> ALU.B ; ALU --> [mux_inferior] --> [shifter] --> sh_out
--   fuente --> [mux_inferior] (sel_inf = 1: bypass, sin pasar por la ALU)
--   sh_out --> banco (din, escritura en addr_a) y detector de cero
--   rf_a --> [buffer de salida] --> dato_out (habilitado por out_en)
--
-- Cada microciclo se leen los operandos en el banco (addr_a/addr_b),
-- la ALU los combina y el resultado se escribe en el mismo flanco:
-- no existe realimentación combinacional. 'cero' se calcula sobre
-- la salida del shifter (el valor que se va a escribir en el banco).
-- 'rf_dout' (lectura A) se expone para las ondas.
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
    addr    : in  unsigned(2 downto 0);   -- lectura A / dirección destino
    addr_b  : in  unsigned(2 downto 0);   -- lectura B (segundo operando)
    wr_rf   : in  std_logic;
    op_alu  : in  unsigned(2 downto 0);
    sel_inf : in  std_logic;
    sh      : in  unsigned(1 downto 0);
    out_en  : in  std_logic;
    -- salidas de datos y de estado
    dato_out : out unsigned(7 downto 0);
    cero     : out std_logic;              -- salida del shifter == 0
    rf_dout  : out unsigned(7 downto 0)    -- lectura A del banco (ondas)
  );
end entity;

architecture estructural of datapath is
  signal rf_a    : unsigned(7 downto 0);  -- lectura A del banco
  signal rf_b    : unsigned(7 downto 0);  -- lectura B del banco
  signal fuente  : unsigned(7 downto 0);  -- salida del mux superior
  signal alu_out : unsigned(7 downto 0);  -- salida de la ALU
  signal mux_inf : unsigned(7 downto 0);  -- salida del mux inferior
  signal sh_out  : unsigned(7 downto 0);  -- salida del shifter
begin
  rf_dout <= rf_a;

  u_mux_sup : entity work.mux_superior
    port map (
      ext1    => ext1,
      ext2    => (others => '0'),   -- EXT2 reservado, atado a 0
      rf_a    => rf_a,
      rf_b    => rf_b,
      sel_sup => sel_sup,
      dout    => fuente
    );

  u_rf : entity work.banco_registros
    port map (
      clk    => clk,
      rst    => rst,
      addr_a => addr,
      addr_b => addr_b,
      din    => sh_out,
      wr     => wr_rf,
      dout_a => rf_a,
      dout_b => rf_b
    );

  u_alu : entity work.alu
    port map (
      a      => fuente,
      b      => rf_b,
      op_alu => op_alu,
      f      => alu_out
    );

  u_mux_inf : entity work.mux_inferior
    port map (
      alu_out => alu_out,
      fuente  => fuente,
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
      d        => rf_a,
      en       => out_en,
      dato_out => dato_out
    );
end architecture;
