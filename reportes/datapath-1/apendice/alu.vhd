-- =======================================================
-- ALU del Datapath 1
-- Especificación de implementación propuesta por el
-- equipo; los códigos NO están confirmados como
-- provenientes del material oficial del curso.
-- Operaciones provisionales acordadas:
--   C=000: F = A+B        (n+x con M=1; n con M=0)
--   C=001: F = (B<<1)+A (2n+x; desplazamiento interno,
--                       sin shifter)
--   C=010: F = B+1        (n+1, ignora A)
--   C=011..111: reservado, F = 0 (provisional,
--                       pendiente de evidencia)
-- Combinacional, sin signo, módulo 2^ANCHO. Sin
-- banderas: los desbordamientos son silenciosos
-- (limitación documentada).
-- =======================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    generic (
        ANCHO : natural := 8
    );
    port (
        a : in  std_logic_vector(ANCHO - 1 downto 0);
        b : in  std_logic_vector(ANCHO - 1 downto 0);
        c : in  std_logic_vector(2 downto 0);
        f : out std_logic_vector(ANCHO - 1 downto 0)
    );
end entity;

architecture comportamental of alu is
begin
    process (a, b, c)
    begin
        case c is
            when "000" =>
                -- suma: n+x (A=x) o n (A=0);
                -- con B=0 y A=x sirve para cargar
                f <= std_logic_vector(
                         unsigned(a) + unsigned(b));
            when "001" =>
                -- desplazamiento lógico de B a la
                -- izquierda y suma: 2n+x
                f <= std_logic_vector(
                    shift_left(unsigned(b), 1)
                        + unsigned(a));
            when "010" =>
                -- incremento de B: n+1 (A no participa)
                f <= std_logic_vector(unsigned(b) + 1);
            when others =>
                -- reservado (011..111): F = 0 provisional
                f <= (others => '0');
        end case;
    end process;
end architecture;
