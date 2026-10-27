-- ============================================================
-- ALU del Datapath 3
-- 8 operaciones aritmético-lógicas sobre bytes sin signo,
-- seleccionadas por A2 A1 A0 (tabla de la asignatura).
-- A = salida del acumulador, B = salida del banco de registros.
-- Combinacional. Sin flag de acarreo (limitación documentada:
-- los desbordamientos son silenciosos, módulo 256).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port (
        a  : in  std_logic_vector(7 downto 0);
        b  : in  std_logic_vector(7 downto 0);
        op : in  std_logic_vector(2 downto 0);  -- A2 A1 A0
        f  : out std_logic_vector(7 downto 0)
    );
end entity;

architecture comportamental of alu is
begin
    process (a, b, op)
    begin
        case op is
            when "000" =>
                f <= a;                                                    -- Pasar A
            when "001" =>
                f <= std_logic_vector(unsigned(a) + unsigned(b));          -- Suma
            when "010" =>
                f <= std_logic_vector(unsigned(a) - unsigned(b));          -- Resta
            when "011" =>
                f <= std_logic_vector(unsigned(a) + 1);                    -- Incremento
            when "100" =>
                f <= std_logic_vector(unsigned(a) - 1);                    -- Decremento
            when "101" =>
                f <= a or b;                                               -- OR
            when "110" =>
                f <= a and b;                                              -- AND
            when others =>
                f <= not a;                                                -- NOT A (111)
        end case;
    end process;
end architecture;
