-- ============================================================
-- Testbench de la ALU del Datapath 1
-- Comprueba: operaciones normales (n+x, 2n+x, n+1), operandos
-- cero, límites de 8 bits, truncamiento por desbordamiento
-- (módulo 256), códigos reservados (F = 0) y el genérico
-- ANCHO con una instancia de 4 bits.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_alu is
end entity;

architecture tb of tb_alu is
    component alu is
        generic (
            ANCHO : natural := 8
        );
        port (
            a : in  std_logic_vector(ANCHO - 1 downto 0);
            b : in  std_logic_vector(ANCHO - 1 downto 0);
            c : in  std_logic_vector(2 downto 0);
            f : out std_logic_vector(ANCHO - 1 downto 0)
        );
    end component;

    signal a8, b8, f8 : std_logic_vector(7 downto 0) := (others => '0');
    signal c          : std_logic_vector(2 downto 0) := "000";

    signal a4, b4, f4 : std_logic_vector(3 downto 0) := (others => '0');
begin
    dut8 : alu
        generic map (ANCHO => 8)
        port map (a => a8, b => b8, c => c, f => f8);

    dut4 : alu
        generic map (ANCHO => 4)
        port map (a => a4, b => b4, c => c, f => f4);

    stim : process
        procedure probar (
            cc  : in std_logic_vector(2 downto 0);
            aa  : in std_logic_vector(7 downto 0);
            bb  : in std_logic_vector(7 downto 0);
            esp : in std_logic_vector(7 downto 0);
            msg : in string
        ) is
        begin
            c  <= cc;
            a8 <= aa;
            b8 <= bb;
            wait for 10 ns;
            assert f8 = esp
                report "tb_alu: " & msg severity failure;
        end procedure;
    begin
        -- ---- C=000: F = A+B = n+x (con x) / n (con A=0) ----
        probar("000", x"0A", x"05", x"0F", "n+x mal (5+10=15)");
        probar("000", x"00", x"07", x"07", "n con A=0 mal (0+7=7)");
        probar("000", x"3C", x"00", x"3C", "carga de x con n=0 mal");
        probar("000", x"00", x"00", x"00", "cero + cero mal");

        -- ---- C=001: F = (B<<1)+A = 2n+x ----
        probar("001", x"0A", x"05", x"14", "2n+x mal (2*5+10=20)");
        probar("001", x"00", x"05", x"0A", "2n con A=0 mal (2*5=10)");
        probar("001", x"00", x"00", x"00", "doble de cero mal");

        -- ---- C=010: F = B+1 = n+1 (ignora A) ----
        probar("010", x"00", x"05", x"06", "n+1 mal (5+1=6)");
        probar("010", x"A5", x"05", x"06", "n+1 debe ignorar A");
        probar("010", x"00", x"00", x"01", "0+1 mal");

        -- ---- Límites de 8 bits y truncamiento por desbordamiento ----
        probar("000", x"01", x"FF", x"00", "255+1 debe envolver a 0");
        probar("000", x"64", x"C8", x"2C", "200+100=300 -> 44 mal");
        probar("000", x"FF", x"FF", x"FE", "255+255=510 -> 254 mal");
        probar("001", x"00", x"C8", x"90", "doble de 200 (400 -> 144) mal");
        probar("001", x"00", x"7F", x"FE", "doble de 127 (254) mal");
        probar("001", x"00", x"80", x"00", "doble de 128 (256 -> 0) mal");
        probar("010", x"00", x"FF", x"00", "255+1 con C=010 debe envolver a 0");

        -- ---- Códigos reservados: F = 0 (provisional) ----
        probar("011", x"5A", x"A5", x"00", "011 reservado debe dar 0");
        probar("100", x"5A", x"A5", x"00", "100 reservado debe dar 0");
        probar("101", x"5A", x"A5", x"00", "101 reservado debe dar 0");
        probar("110", x"5A", x"A5", x"00", "110 reservado debe dar 0");
        probar("111", x"5A", x"A5", x"00", "111 reservado debe dar 0");

        -- ---- Genérico ANCHO = 4 ----
        c  <= "000";
        a4 <= "0011";                     -- 3
        b4 <= "0001";                     -- 1
        wait for 10 ns;
        assert f4 = "0100"
            report "tb_alu (ANCHO=4): 3+1 mal" severity failure;

        c  <= "001";
        a4 <= "0000";
        b4 <= "1001";                     -- 9 << 1 = 18 mod 16 = 2
        wait for 10 ns;
        assert f4 = "0010"
            report "tb_alu (ANCHO=4): doble de 9 truncado mal" severity failure;

        c  <= "010";
        a4 <= "0000";
        b4 <= "1111";                     -- 15 + 1 = 0
        wait for 10 ns;
        assert f4 = "0000"
            report "tb_alu (ANCHO=4): 15+1 debe envolver a 0" severity failure;

        report "tb_alu: OK" severity note;
        wait;
    end process;
end architecture;
