----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:43:33 01/22/2014 
-- Design Name: 
-- Module Name:    square_accumulate - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package local_types is
type in_vec_type is array (0 to 15) of std_logic_vector(2 downto 0);
type out_vec_type is array (0 to 15) of std_logic_vector(2 downto 0);
type l1_type is array (0 to 7) of std_logic_vector(3 downto 0);
type l2_type is array (0 to 3) of std_logic_vector(4 downto 0);
type l3_type is array (0 to 1) of std_logic_vector(5 downto 0);
end;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
use work.local_types.all;

entity square_accumulate is
port(
clk: in std_logic;
in_vec: in std_logic_vector(3*16-1 downto 0);
power : out std_logic_vector(30 downto 0);
sum : out std_logic_vector(30 downto 0);
new_power_flag : out std_logic;
acc_cnt_debug : out std_logic_vector(23 downto 0)
);
end square_accumulate;

architecture Behavioral of square_accumulate is
signal in_vec_arr:  in_vec_type;
signal out_vec:  out_vec_type;
signal l1:  l1_type;
signal l2:  l2_type;
signal l3:  l3_type;
signal l1_sum:  l1_type;
signal l2_sum:  l2_type;
signal l3_sum:  l3_type;
signal sum16 :  std_logic_vector(6 downto 0);
signal sum16_sum :  std_logic_vector(6 downto 0);

signal power_acc :  std_logic_vector(30 downto 0);
signal sum_acc :  std_logic_vector(30 downto 0);
signal acc_cnt :  std_logic_vector(23 downto 0);

constant TERM_ACC_CNT : integer := 16250000;
 
component square_simple 
port(
clk: in std_logic;
op_in: in std_logic_vector(2 downto 0);
op_out: out std_logic_vector(2 downto 0)
);
end component;
begin


process(in_vec)
begin
for i in 0 to 15 loop
	in_vec_arr(i)<=in_vec(3*i+2 downto 3*i);
end loop;
end process;

g_i: for i in 0 to 15 generate
	square_simple_i: square_simple port map(clk=>clk, op_in=>in_vec_arr(i), op_out=>out_vec(i));
end generate;

process(clk)
begin
if rising_edge(clk) then
	for i in 0 to 7 loop
		l1(i)<=('0' & out_vec(2*i)) + out_vec(2*i+1);
		l1_sum(i)<=('0' & in_vec_arr(2*i)) + in_vec_arr(2*i+1);
	end loop;
	for i in 0 to 3 loop
		l2(i)<=('0' & l1(2*i)) + l1(2*i+1);
		l2_sum(i)<=('0' & l1_sum(2*i)) + l1_sum(2*i+1);
	end loop;
	for i in 0 to 1 loop
		l3(i)<=('0' & l2(2*i)) + l2(2*i+1);
		l3_sum(i)<=('0' & l2_sum(2*i)) + l2_sum(2*i+1);
	end loop;	
		sum16<=('0' & l3(0))+l3(1)+72; --should be correct in 2's complement!
		sum16_sum<=('0' & l3_sum(0))+l3_sum(1);
end if;
end process;

--power<="000" & X"00000" & sum16 & '0';



process(clk)
begin
if rising_edge(clk) then
	if acc_cnt = TERM_ACC_CNT then
		sum_acc<=(others =>'0');
		power_acc<=(others =>'0');
		acc_cnt<=(others =>'0');
		power <=power_acc;
		sum <=sum_acc;
		acc_cnt_debug<=acc_cnt;
		new_power_flag <= '1';
	else
		power_acc<=power_acc+sum16;
		sum_acc<=sum_acc+sum16_sum;
		acc_cnt<=acc_cnt+1;
		new_power_flag <= '0';
	end if;
end if;
end process;


end Behavioral;

