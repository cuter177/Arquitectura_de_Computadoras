-- ============================================================
-- banco_registros.vhd — Banco (register file) de 8 registros x 8 bits
--
-- Un único puerto de dirección (addr): en cada microciclo se lee
-- y, si wr = '1', se escribe el MISMO registro.
--   lectura:  dout <= regs(addr)      (combinacional)
--   escritura: regs(addr) <= din      (en el flanco, si wr = '1')
-- 'rst' asíncrono pone a cero todos los registros.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity banco_registros is
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    addr : in  unsigned(2 downto 0);   -- dirección de 3 bits (8 registros)
    din  : in  unsigned(7 downto 0);   -- dato a escribir (bus del acumulador)
    wr   : in  std_logic;              -- escribe regs(addr) <- din
    dout : out unsigned(7 downto 0)    -- lectura combinacional de regs(addr)
  );
end entity;

architecture rtl of banco_registros is
  type regs_t is array (0 to 7) of unsigned(7 downto 0);
  signal regs : regs_t := (others => (others => '0'));
begin
  dout <= regs(to_integer(addr));

  process(clk, rst)
  begin
    if rst = '1' then
      regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wr = '1' then
        regs(to_integer(addr)) <= din;
      end if;
    end if;
  end process;
end architecture;
