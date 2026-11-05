-- ============================================================
-- detector_cero.vhd — Detector de cero sobre la salida del shifter
--
-- Emite '1' cuando su entrada es 0 y '0' en caso contrario.
-- Es el flag de condición que permite terminar los bucles de los
-- tres experimentos (suma, factorial y multiplicación). No aparece
-- en el diagrama oficial; se añade con justificación (ver
-- docs/plan-datapath-3.md, §4.4) sobre el valor que se va a escribir
-- en el acumulador, de modo que el salto condicional puede ir en la
-- misma microinstrucción que produce el resultado.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity detector_cero is
  port (
    d    : in  unsigned(7 downto 0);
    cero : out std_logic
  );
end entity;

architecture combinacional of detector_cero is
begin
  cero <= '1' when d = 0 else '0';
end architecture;
