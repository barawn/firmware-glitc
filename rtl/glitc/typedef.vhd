--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


library IEEE;
use IEEE.STD_LOGIC_1164.all;

package typedef is
type gen_arr is array (integer range <>) of STD_LOGIC_VECTOR (2 downto 0);
-- this is mistakenly called arr_52, it's actually only 48 wide (LCM(12,16))
subtype arr_52 is gen_arr (-11 to 36);
-- actually 84
subtype arr_88 is gen_arr (-11 to 72);
-- actually 96
subtype arr_100 is gen_arr (-11 to 84);
subtype arr_32 is gen_arr (0 to 31); 
subtype arr_74 is gen_arr (-42 to 31); 
subtype arr_89 is gen_arr (-42 to 46); 
subtype arr_101 is gen_arr (-42 to 58); 
type arr_32_5 is array (0 to 31) of STD_LOGIC_VECTOR (4 downto 0);
type arr_32_7 is array (0 to 31) of STD_LOGIC_VECTOR (6 downto 0);
type arr_32_10 is array (0 to 31) of STD_LOGIC_VECTOR (9 downto 0);
type arr_16_8 is array (0 to 15) of STD_LOGIC_VECTOR (7 downto 0);
type arr_16_11 is array (0 to 15) of STD_LOGIC_VECTOR (10 downto 0);
type arr_8_12 is array (0 to 7) of STD_LOGIC_VECTOR (11 downto 0);
type arr_8_9 is array (0 to 7) of STD_LOGIC_VECTOR (8 downto 0);
type arr_4_13 is array (0 to 3) of STD_LOGIC_VECTOR (12 downto 0);
type arr_4_10 is array (0 to 3) of STD_LOGIC_VECTOR (9 downto 0);
type arr_2_11 is array (0 to 2) of STD_LOGIC_VECTOR (10 downto 0);
type arr_2_14 is array (0 to 2) of STD_LOGIC_VECTOR (13 downto 0);
type arr_80 is array (0 to 79) of STD_LOGIC_VECTOR (15 downto 0);
type arr_values_58c is array (0 to 57) of STD_LOGIC_VECTOR (11 downto 0);
type arr_values_29c is array (0 to 28) of STD_LOGIC_VECTOR (11 downto 0);
type arr_values_15c is array (0 to 14) of STD_LOGIC_VECTOR (11 downto 0);
type arr_values_8c is array (0 to 7) of STD_LOGIC_VECTOR (11 downto 0);
type arr_values_4c is array (0 to 3) of STD_LOGIC_VECTOR (11 downto 0);
type arr_values_2c is array (0 to 1) of STD_LOGIC_VECTOR (11 downto 0);
end typedef;


