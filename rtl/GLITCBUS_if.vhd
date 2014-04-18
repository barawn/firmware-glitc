----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:59:56 04/03/2014 
-- Design Name: 
-- Module Name:    GLITCBUS_if - Behavioral 
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

--GLITCBUS interface - from the MASTER side
--Clock 1: GSEL_x goes low
--Clock 2: A[15:8] on bus / GRDWR_B is valid
--Clock 3: A[7:0] on bus
--Clock 4: Wait state.
--Clock 5: D[31:24] on bus
--Clock 6: D[23:16] on bus
--Clock 7: D[15:8] on bus
--Clock 8: D[7:0] on bus
--Clock 9: GSEL_x goes high
entity GLITCBUS_if is
port(
-- Clock from TISC FPGA
GCLK   : in std_logic;
-- GLITCBUS signals
GRDWR_B : in std_logic;
GSEL_B : in std_logic; -- should we have one per GLITC implementation? Check back
GAD_IN :in std_logic_vector(7 downto 0);
GAD_OUT :out std_logic_vector(7 downto 0);
GAD_DIR: out std_logic; -- tristate out control for GAD, normally in, out only for 4 clock cycles.
VALID_DATA : out std_logic; -- remains '1' after a write, until a new GSEL is issued. Should make clock sync trivial.
DATA_IN : in std_logic_vector(31 downto 0);
DATA_OUT : out std_logic_vector(31 downto 0);
ADD : out std_logic_vector(15 downto 0)
);
end GLITCBUS_if;

architecture Behavioral of GLITCBUS_if is

type state_t is (IDLE, ADDRESS_HIGH, ADDRESS_LOW, WAIT_S, DATA_3, DATA_2, DATA_1, DATA_0, WAIT_FOR_GSEL);
signal state : state_t;
signal GAD_OE : std_logic := '0';
signal WR_B : std_logic;
signal DATA_IN_latch : std_logic_vector(31 downto 0);

begin

GAD_DIR <= not GAD_OE after 5 ns;

process(GCLK)
begin
if rising_edge(GCLK) then
	GAD_OE<='0';
	case state is
		when IDLE => VALID_DATA <= '0'; if GSEL_B = '0' then state <= ADDRESS_HIGH;end if;
		when ADDRESS_HIGH => ADD(15 downto 8) <= GAD_IN; WR_B<= GRDWR_B; state<=ADDRESS_LOW; 
		when ADDRESS_LOW => ADD(7 downto 0) <= GAD_IN; state<=WAIT_S;
		when WAIT_S =>  if WR_B = '1' then
								GAD_OE <='1';
								GAD_OUT <= DATA_IN(31 downto 24) after 5 ns;
							 end if;
							 state<=DATA_3;
		when DATA_3 =>  if WR_B = '0' then 
								DATA_OUT(31 downto 24) <=GAD_IN ; 
							 else
								GAD_OE<='1';
								GAD_OUT <= DATA_IN(23 downto 16) after 5 ns;
							 end if;
							 state<=DATA_2;
		when DATA_2 =>  if WR_B = '0' then 
								DATA_OUT(23 downto 16) <= GAD_IN ; 
							 else
								GAD_OE<='1';
								GAD_OUT <= DATA_IN(15 downto 8) after 5 ns;
							 end if;
							 state<=DATA_1;
		when DATA_1 =>  if WR_B = '0' then 
								DATA_OUT(15 downto 8) <= GAD_IN ; 
							 else
								GAD_OE<='1';
								GAD_OUT <= DATA_IN(7 downto 0) after 5 ns;
							 end if;
							 state<=DATA_0;
		when DATA_0 =>  if WR_B = '1' then 
								GAD_OE<='0';
							 else
								DATA_OUT(7 downto 0) <= GAD_IN ;
								VALID_DATA <= '1';
							 end if;
							state<=WAIT_FOR_GSEL;							 
		when WAIT_FOR_GSEL =>  VALID_DATA <= '0'; if GSEL_B = '1' then state <= IDLE; end if;
		when others => state <= IDLE;
	end case;
end if;
end process;



end Behavioral;

