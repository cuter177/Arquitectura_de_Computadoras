-- ============================================================
-- Detector de cero del Datapath 3
-- Añadido con justificación (no aparece en el diagrama): sin
-- una condición de "contador = 0" ningún algoritmo iterativo
-- puede terminar. Observa la salida del shifter (el valor que
-- se escribirá en el acumulador en el mismo flanco), de modo
-- que el salto condicional de la unidad de control puede ir en
-- la misma microinstrucción que produce el resultado.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity detector_cero is
    port (
        d    : in  std_logic_vector(7 downto 0);
        cero : out std_logic
    );
end entity;

architecture comportamental of detector_cero is
begin
    cero <= '1' when unsigned(d) = 0 else '0';
end architecture;
