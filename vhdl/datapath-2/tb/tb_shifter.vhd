-- ============================================================
-- tb_shifter.vhd — Banco de prueba del shifter
--
-- Comprueba los 4 códigos. En los experimentos del datapath-2 solo
-- se usa el modo pasar (00), imprescindible para la realimentación;
-- los códigos 01/10/11 se verifican como provisionales.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_shifter is
end entity;

architecture tb of tb_shifter is
  signal d    : unsigned(7 downto 0) := (others => '0');
  signal sh   : unsigned(1 downto 0) := "00";
  signal dout : unsigned(7 downto 0);
begin
  dut : entity work.shifter
    port map (d => d, sh => sh, dout => dout);

  process
    procedure probar(constant val : in unsigned(7 downto 0);
                     constant cod : in unsigned(1 downto 0);
                     constant esp : in unsigned(7 downto 0)) is
    begin
      d  <= val;
      sh <= cod;
      wait for 1 ns;
      assert dout = esp
        report "shifter cod=" & integer'image(to_integer(cod)) &
               " con d=" & integer'image(to_integer(val)) &
               ": se esperaba " & integer'image(to_integer(esp)) &
               " y se obtuvo " & integer'image(to_integer(dout))
        severity failure;
    end procedure;
  begin
    -- Pasar: identidad (modo usado siempre)
    probar(to_unsigned(150, 8), "00", to_unsigned(150, 8));
    probar(to_unsigned(1, 8),   "00", to_unsigned(1, 8));

    -- Desplazamientos (provisionales)
    probar(to_unsigned(5, 8),   "01", to_unsigned(10, 8));   -- izq lógica
    probar(to_unsigned(10, 8),  "10", to_unsigned(5, 8));    -- der lógica
    probar(to_unsigned(128, 8), "11", to_unsigned(192, 8));  -- der aritmética
    probar(to_unsigned(4, 8),   "11", to_unsigned(2, 8));

    report "tb_shifter: OK - 4 códigos verificados (00 = pasar)";
    finish;
  end process;
end architecture;
