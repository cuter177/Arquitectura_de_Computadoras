-- ============================================================
-- banco_registros.vhd — Banco (register file) de 8 registros x 8 bits
--
-- Doble lectura combinacional y una única escritura síncrona:
--   lectura A:  dout_a <= regs(addr_a)   (combinacional)
--   lectura B:  dout_b <= regs(addr_b)   (combinacional)
--   escritura:  regs(addr_a) <= din      (en el flanco, si wr = '1')
-- 'addr_a' es además la dirección destino de la escritura; 'rst'
-- asíncrono pone a cero todos los registros.
--
-- El banco es el único almacenamiento del datapath: guarda los
-- operandos y los resultados intermedios de los algoritmos. Las dos
-- lecturas permiten que la ALU reciba sus dos operandos en el mismo
-- microciclo.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity banco_registros is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    addr_a : in  unsigned(2 downto 0);   -- lectura A / dirección destino
    addr_b : in  unsigned(2 downto 0);   -- lectura B (segundo operando)
    din    : in  unsigned(7 downto 0);   -- dato a escribir (salida del shifter)
    wr     : in  std_logic;              -- escribe regs(addr_a) <- din
    dout_a : out unsigned(7 downto 0);   -- lectura combinacional A
    dout_b : out unsigned(7 downto 0)    -- lectura combinacional B
  );
end entity;

architecture rtl of banco_registros is
  type regs_t is array (0 to 7) of unsigned(7 downto 0);
  signal regs : regs_t := (others => (others => '0'));
begin
  dout_a <= regs(to_integer(addr_a));
  dout_b <= regs(to_integer(addr_b));

  process(clk, rst)
  begin
    if rst = '1' then
      regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wr = '1' then
        regs(to_integer(addr_a)) <= din;
      end if;
    end if;
  end process;
end architecture;
