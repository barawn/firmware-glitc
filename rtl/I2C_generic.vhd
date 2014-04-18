----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:44:17 04/08/2014 
-- Design Name: 
-- Module Name:    I2C_generic - Behavioral 
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
library UNISIM;
use UNISIM.VComponents.all;

entity I2C_generic is
port(
CLK : in std_logic;
address : in std_logic_vector(7 downto 0);
command : in std_logic_vector(7 downto 0);
byte1 : in std_logic_vector(7 downto 0);
byte2 : in std_logic_vector(7 downto 0);
length_flag : in std_logic; -- only 2 commands - with one or 2 value bytes
transmit : in std_logic;
ready : out  std_logic;
SCL :out std_logic;
SDA : inout std_logic
);
end I2C_generic;

architecture Behavioral of I2C_generic is
signal t_cnt : std_logic;
signal counter : std_logic_vector(15 downto 0) := (others => '0');
constant COUNT_VAL : std_logic_vector(15 downto 0) := x"0400"; -- divide by 1024 - each t_cnt pulse is 1/4 of period so frequency = 162.5MHz/4096 ~= 40 KHz
type state_t is (IDLE, ALIGN_TRANSMIT, START, ADDR, COMM, BT1, BT2, STOP);
signal state : state_t;

signal force_SDA_L :  std_logic;
signal force_SDA_H :  std_logic;

signal SDA_in :  std_logic;

signal address_latched : std_logic_vector(7 downto 0);
signal command_latched : std_logic_vector(7 downto 0);
signal byte1_latched : std_logic_vector(7 downto 0);
signal byte2_latched : std_logic_vector(7 downto 0);
signal length_flag_latched : std_logic; -- only 2 comm
signal n_bit : std_logic_vector(7 downto 0);
signal phase : std_logic_vector(1 downto 0);

begin

--IOBUF #(
----  .DRIVE(6),               // Specify the output drive strength
----  .IOSTANDARD("LVCMOS33"), // Specify the I/O standard
--  .SLEW("SLOW") )          // Specify the output slew rate
I2Cpin: IOBUF  port map(
  O =>SDA_in,    -- output of FPGA pin input buffer, connects to fabric
  IO => SDA,   -- Buffer inout port (connect directly to top-level port, FPGA pin)
  I => '0',      -- output buffer input, driven from FPGA fabric.
  T =>force_SDA_H ); -- output buffer enable, high=input (hi-Z output), low=active drive


force_SDA_H<= not force_SDA_L;


process(CLK)
begin
if rising_edge(CLK) then
 t_cnt<='0';
 counter<=counter-1;
 if counter = x"0000" then
	counter<= COUNT_VAL;
	t_cnt<='1';
 end if;
end if;
end process;

process(CLK)
begin
if rising_edge(CLK) then
	force_SDA_L <= '0';
	SCL<='1';
	ready<='0';
	case state is
		when IDLE => if transmit = '1' then
								state <= ALIGN_TRANSMIT;
								address_latched <= address;
								command_latched <= command;
								byte1_latched <= byte1;
								byte2_latched <= byte2;
								length_flag_latched <= length_flag;
					     end if;
						  ready<='1';
		when ALIGN_TRANSMIT => if t_cnt = '1' then
											state <= START;
											phase<= (others =>'0');
									  end if;
		when START => 	if t_cnt = '1' then
											phase <=phase +1;
											if phase = "01" then 
												phase<= (others =>'0');		
												n_bit<= (others =>'0');
												state <= ADDR;
											end if;
							end if;					
							force_SDA_L<='1';
							SCL<='1';
							case phase is
								when "00" => 	force_SDA_L<='1';
								when "01" => 	force_SDA_L<='1';
													SCL<='0';
								when others => force_SDA_L<='1';
							end case;
		when ADDR => 	if t_cnt = '1' then
								phase <=phase +1;
								if phase = "11" then 
									n_bit<=n_bit + 1;
										if n_bit = 8 then
											phase<= (others =>'0');		
											n_bit<= (others =>'0');
											state <= COMM;
										end if;
								end if;
							end if;					
							force_SDA_L<='1';
							SCL<='1';
							if n_bit < 8 then force_SDA_L<=not address(7-conv_integer(n_bit));
													else force_SDA_L <='0';
													end if;
							case phase is
								when "00" => 	
													SCL<='0';
								when "01" => 
													SCL<='1';
								when "10" => 	
													SCL<='1';																	
								when "11" => 	
													SCL<='0';
								when others => force_SDA_L<='1';
							end case;
		when COMM => if t_cnt = '1' then
								phase <=phase +1;
								if phase = "11" then 
									n_bit<=n_bit + 1;
										if n_bit = 8 then
											phase<= (others =>'0');		
											n_bit<= (others =>'0');
											state <= BT1;
										end if;
								end if;
							end if;		
							force_SDA_L<='1';
							SCL<='1';
							if n_bit < 8 then force_SDA_L<=not command_latched(7-conv_integer(n_bit));
							else force_SDA_L <='0';
							end if;
							case phase is
								when "00" => 	
													SCL<='0';
								when "01" => 	
													SCL<='1';
								when "10" => 
													SCL<='1';																	
								when "11" => 
													SCL<='0';
								when others => force_SDA_L<='1';
							end case;
		when BT1 => 	if t_cnt = '1' then
								phase <=phase +1;
								if phase = "11" then 
									n_bit<=n_bit + 1;
										if n_bit = 8 then
											phase<= (others =>'0');		
											n_bit<= (others =>'0');
											if length_flag_latched = '1' then 
												state <= BT2;
											else
												state <= STOP;
											end if;
										end if;
								end if;
							end if;	
							force_SDA_L<='1';
							SCL<='1';
							if n_bit < 8 then force_SDA_L<=not byte1_latched(7-conv_integer(n_bit));
							else force_SDA_L <='0';
							end if;
							case phase is
								when "00" => 	
													SCL<='0';
								when "01" => 	
													SCL<='1';
								when "10" => 	
													SCL<='1';																	
								when "11" => 	
													SCL<='0';
								when others => force_SDA_L<='1';
							end case;
		when BT2 => 	if t_cnt = '1' then
								phase <=phase +1;
								if phase = "11" then 
									n_bit<=n_bit + 1;
										if n_bit = 8 then
											phase<= (others =>'0');		
											n_bit<= (others =>'0');
											state <= STOP;
										end if;
								end if;
							end if;	
							force_SDA_L<='1';
							SCL<='1';
							if n_bit < 8 then force_SDA_L<=not byte2_latched(7-conv_integer(n_bit));
							else force_SDA_L <='0';
							end if;
							case phase is
								when "00" => 	
													SCL<='0';
								when "01" => 	
													SCL<='1';
								when "10" => 	
													SCL<='1';																	
								when "11" => 	
													SCL<='0';
								when others => force_SDA_L<='1';
							end case;
		when STOP => 	if t_cnt = '1' then
								phase <=phase +1;
								if phase = "10" then 
											phase<= (others =>'0');		
											n_bit<= (others =>'0');
											state <= IDLE;
								end if;
							end if;	
							force_SDA_L<='1';
							SCL<='1';
							case phase is
								when "00" => 	force_SDA_L<='1';
													SCL<='0';
								when "01" => 	force_SDA_L<='1';
													SCL<='1';
								when "10" => 	force_SDA_L<='0';
													SCL<='1';																	
								when others => force_SDA_L<='1';
							end case;
		end case;
end if;
end process;
end Behavioral;

