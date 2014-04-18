----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:00:03 04/10/2014 
-- Design Name: 
-- Module Name:    trigger_module - Behavioral 
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
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity trigger_module is 
port(
CLK : in std_logic;
sum_low : in std_logic_vector(11 downto 0);
sum_center : in std_logic_vector(11 downto 0);
sum_high : in std_logic_vector(11 downto 0);
threshold : in std_logic_vector(11 downto 0);
trigger : out std_logic);
end trigger_module;

architecture Behavioral of trigger_module is

begin

process(CLK)
begin
if rising_edge(CLK) then
	trigger <= '0';
	if (sum_low + sum_center + sum_high) > threshold then
		trigger <= '1';
	end if;
end if;

end process;

end Behavioral;

