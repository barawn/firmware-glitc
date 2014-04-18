----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:03:41 01/22/2014 
-- Design Name: 
-- Module Name:    square_simple - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity square_simple is
port(
clk: in std_logic;
op_in: in std_logic_vector(2 downto 0);
op_out: out std_logic_vector(2 downto 0)
);
end square_simple;

architecture Behavioral of square_simple is

begin

process(clk)
begin
if rising_edge(clk) then
	case op_in is
		when "000" => op_out<="110";
		when "001" => op_out<="011";
		when "010" => op_out<="001";
		when "011" => op_out<="000";
		when "100" => op_out<="000";
		when "101" => op_out<="001";
		when "110" => op_out<="011";
		when "111" => op_out<="110";
		when others =>  op_out<="111";
	end case;
end if;
end process;




end Behavioral;

