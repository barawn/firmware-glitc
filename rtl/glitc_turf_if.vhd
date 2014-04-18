----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:19:01 04/03/2014 
-- Design Name: 
-- Module Name:    glitc_turf_if - Behavioral 
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
library UNISIM;
use UNISIM.VComponents.all;

entity glitc_turf_if is 
port(
SYSCLK : in std_logic; -- also using GCLK for TURF communication?
TA_OUT_P :out std_logic_vector(1 downto 0); -- single phi sector indicators
TA_OUT_N :out std_logic_vector(1 downto 0);
TA_IN_P :in std_logic; -- from TURF, PPS-like signal to synchronize GLITCs
TA_IN_N :in std_logic; 
PHI_A_in :in std_logic; -- Note: this might work only if the PHI signals are in SYSCLK=TURF_CLK domain clock
PHI_B_in :in std_logic;	-- if not, it requires some tweaking (generating a multiple of the TURFclock
								-- and use it to SERDES the stream of bits.
PPS_OUT: out std_logic
);
end glitc_turf_if;

architecture Behavioral of glitc_turf_if is



signal PHI_in_vec : std_logic_vector(1 downto 0);
signal PPS : std_logic;

begin

-- Input - now simply latched PPS after LVDS input
 ibufds_inst : IBUFDS
       generic map (
         DIFF_TERM  => FALSE,             -- Differential termination
         IOSTANDARD => "LVDS_25")
       port map (
         I          => TA_IN_P,
         IB         => TA_IN_N,
         O          => PPS);


    fdre_in_inst : FDRE
      port map
       (D             => PPS,
        C              => SYSCLK,
        CE            => '1',
        R             => '0',
        Q             => PPS_OUT);


OBUFDS_PHI_A : OBUFDS 
generic map (
IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
SLEW => "SLOW") -- Specify the output slew rate
port map (
O =>TA_OUT_P(0), -- Diff_p output (connect directly to top-level port)
OB => TA_OUT_N(0), -- Diff_n output (connect directly to top-level port)
I => PHI_A_in -- Buffer input
);

OBUFDS_PHI_B : OBUFDS
generic map (
IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
SLEW => "SLOW") -- Specify the output slew rate
port map (
O =>TA_OUT_P(1), -- Diff_p output (connect directly to top-level port)
OB => TA_OUT_N(1), -- Diff_n output (connect directly to top-level port)
I => PHI_B_in -- Buffer input
);


end Behavioral;

