-- ============================================================
-- Testbench del Datapath 1 completo
-- Secuencias de varios ciclos con palabras de control,
-- comprobando en cada ciclo F_ALU, Q y SALIDA.
-- Caso clave: con L = 0 la salida NO cambia aunque F_ALU sí
-- cambie (la salida sale del registro, no de la ALU).
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_datapath is
end entity;

architecture tb of tb_datapath is
    component datapath is
        generic (
            ANCHO : natural := 8
        );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            dato_ext : in  std_logic_vector(ANCHO - 1 downto 0);
            cw       : in  std_logic_vector(5 downto 0);
            salida   : out std_logic_vector(ANCHO - 1 downto 0);
            f_alu    : out std_logic_vector(ANCHO - 1 downto 0);
            q_reg    : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal dato_ext : std_logic_vector(7 downto 0) := x"05";  -- x = 5
    signal cw       : std_logic_vector(5 downto 0) := "100000";
    signal salida   : std_logic_vector(7 downto 0);
    signal f_alu    : std_logic_vector(7 downto 0);
    signal q_reg    : std_logic_vector(7 downto 0);
begin
    dut : datapath
        generic map (ANCHO => 8)
        port map (
            clk      => clk,
            rst      => rst,
            dato_ext => dato_ext,
            cw       => cw,
            salida   => salida,
            f_alu    => f_alu,
            q_reg    => q_reg
        );

    stim : process
        procedure tick is
        begin
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end procedure;
    begin
        -- ==================================================
        -- 1) reset (CW=100000: OE=1 para observar Q)
        -- ==================================================
        rst <= '1';
        cw  <= "100000";
        tick;
        assert q_reg = x"00" and salida = x"00"
            report "datapath: rst no deja Q=0 con OE=1" severity failure;
        rst <= '0';

        -- ==================================================
        -- 2) Ciclo 1: CW=111000 => n+x, guardar y mostrar
        -- ==================================================
        cw <= "111000";                       -- O.E=1, L=1, M=1, C=000
        wait for 10 ns;
        assert f_alu = x"05"
            report "ciclo1: F_ALU debe ser 0+5=5 antes del flanco"
            severity failure;
        assert q_reg = x"00" and salida = x"00"
            report "ciclo1: antes del flanco Q y SALIDA deben seguir en 0"
            severity failure;
        tick;
        assert q_reg = x"05" and salida = x"05"
            report "ciclo1: tras el flanco Q y SALIDA deben ser 5"
            severity failure;

        -- ==================================================
        -- 3) Ciclo 2: CW=111001 => 2n+x, guardar y mostrar
        -- ==================================================
        cw <= "111001";                       -- O.E=1, L=1, M=1, C=001
        wait for 10 ns;
        assert f_alu = x"0F"
            report "ciclo2: F_ALU debe ser (5<<1)+5=15" severity failure;
        assert q_reg = x"05" and salida = x"05"
            report "ciclo2: antes del flanco Q y SALIDA deben seguir en 5"
            severity failure;
        tick;
        assert q_reg = x"0F" and salida = x"0F"
            report "ciclo2: tras el flanco Q y SALIDA deben ser 15"
            severity failure;

        -- ==================================================
        -- 4) CLAVE: CW=100010 (L=0, C=010): F_ALU cambia
        --    (15+1=16) pero Q y SALIDA no cambian (15)
        -- ==================================================
        cw <= "100010";                       -- O.E=1, L=0, M=0, C=010
        wait for 10 ns;
        assert f_alu = x"10"
            report "clave: F_ALU debe ser 15+1=16" severity failure;
        assert q_reg = x"0F" and salida = x"0F"
            report "clave: con L=0 la SALIDA no debe mostrar el nuevo F_ALU"
            severity failure;
        tick;
        assert f_alu = x"10"
            report "clave: F_ALU sigue en 16 tras el flanco" severity failure;
        assert q_reg = x"0F" and salida = x"0F"
            report "clave: con L=0 el flanco no debe cambiar Q ni SALIDA"
            severity failure;

        -- ==================================================
        -- 5) CW=100000: conservar y mostrar el valor actual
        -- ==================================================
        cw <= "100010";
        wait for 10 ns;
        assert f_alu = x"10" and salida = x"0F"
            report "conservar: F=16 y salida=15 incoherentes" severity failure;
        cw <= "100000";                       -- O.E=1, L=0, M=0, C=000
        wait for 10 ns;
        assert f_alu = x"0F" and salida = x"0F"
            report "conservar: F_ALU=15 y salida=15 mal" severity failure;
        tick;
        assert q_reg = x"0F" and salida = x"0F"
            report "conservar: Q y salida deben seguir en 15" severity failure;

        -- ==================================================
        -- 6) CW=011000: cargar x=0x3C con n=0 sin habilitar
        --    la salida (salida = 'Z'); después se lee con OE=1
        -- ==================================================
        rst <= '1';
        cw  <= "100000";
        tick;
        assert q_reg = x"00"
            report "carga: rst no dejó Q=0" severity failure;
        rst     <= '0';
        dato_ext <= x"3C";
        cw      <= "011000";                  -- O.E=0, L=1, M=1, C=000
        wait for 10 ns;
        assert f_alu = x"3C"
            report "carga: F_ALU debe ser 0x3C+0=0x3C" severity failure;
        assert salida = "ZZZZZZZZ"
            report "carga: con O.E=0 la salida debe ser alta impedancia"
            severity failure;
        tick;
        assert q_reg = x"3C"
            report "carga: Q debe ser 0x3C tras el flanco" severity failure;
        assert salida = "ZZZZZZZZ"
            report "carga: la salida sigue deshabilitada tras el flanco"
            severity failure;
        cw <= "100000";                       -- OE=1, L=0: solo leer Q
        wait for 10 ns;
        assert salida = x"3C"
            report "carga: al habilitar O.E debe verse Q=0x3C" severity failure;
        tick;
        assert q_reg = x"3C" and salida = x"3C"
            report "carga: con L=0 Q debe conservarse en 0x3C" severity failure;

        -- ==================================================
        -- 7) CW=110010 => n+1 guardado y mostrado tras flanco
        -- ==================================================
        cw <= "110010";                       -- O.E=1, L=1, M=0, C=010
        wait for 10 ns;
        assert f_alu = x"3D"
            report "n+1: F_ALU debe ser 0x3C+1=0x3D" severity failure;
        assert salida = x"3C"
            report "n+1: antes del flanco la salida sigue en 0x3C"
            severity failure;
        tick;
        assert q_reg = x"3D" and salida = x"3D"
            report "n+1: tras el flanco Q y salida deben ser 0x3D"
            severity failure;

        report "tb_datapath: OK" severity note;
        wait;
    end process;
end architecture;
