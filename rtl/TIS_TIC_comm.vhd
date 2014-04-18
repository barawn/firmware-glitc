----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:24:12 04/09/2014 
-- Design Name: 
-- Module Name:    TIS_TIC_comm - Behavioral 
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

entity TISC_TISC_comm is
port(
CLK :  in std_logic;
PARALLEL_CLK : in std_logic;
SERIAL_CLK : in std_logic;

phi_down_out : in  std_logic_vector(15 downto 0);
PHI_DOWN_OUT_CLK_P : out std_logic;
PHI_DOWN_OUT_CLK_N : out std_logic;
PHI_DOWN_OUT_P :out std_logic_vector(3 downto 0);
PHI_DOWN_OUT_N :out std_logic_vector(3 downto 0);

phi_up_out : in  std_logic_vector(15 downto 0);
PHI_UP_OUT_CLK_P : out std_logic;
PHI_UP_OUT_CLK_N : out std_logic;
PHI_UP_OUT_P :out std_logic_vector(3 downto 0);
PHI_UP_OUT_N :out std_logic_vector(3 downto 0);

phi_down_in : out  std_logic_vector(15 downto 0);
PHI_DOWN_IN_CLK_P : in std_logic;
PHI_DOWN_IN_CLK_N : in std_logic;
PHI_DOWN_IN_P :in std_logic_vector(3 downto 0);
PHI_DOWN_IN_N :in std_logic_vector(3 downto 0);

phi_up_in : out  std_logic_vector(15 downto 0);
PHI_UP_IN_CLK_P : in std_logic;
PHI_UP_IN_CLK_N : in std_logic;
PHI_UP_IN_P :in std_logic_vector(3 downto 0);
PHI_UP_IN_N :in std_logic_vector(3 downto 0)
);
end TISC_TISC_comm;

architecture Behavioral of TISC_TISC_comm is


signal PHI_DOWN_IN_single_ended :  std_logic_vector(3 downto 0);
signal PHI_UP_IN_single_ended :  std_logic_vector(3 downto 0);

component TISC_TISC_Iserdes
generic
 (-- width of the data for the system
  sys_w       : integer := 4;
  -- width of the data for the device
  dev_w       : integer := 16);
port
 (
  -- From the system into the device
  DATA_IN_FROM_PINS_P     : in    std_logic_vector(sys_w-1 downto 0);
  DATA_IN_FROM_PINS_N     : in    std_logic_vector(sys_w-1 downto 0);
  DATA_IN_TO_DEVICE       : out   std_logic_vector(dev_w-1 downto 0);

  BITSLIP                 : in    std_logic;                    -- Bitslip module is enabled in NETWORKING mode
                                                                -- User should tie it to '0' if not needed
 
-- Clock and reset signals
  CLK_IN_P                : in    std_logic;                    -- Differential fast clock from IOB
  CLK_IN_N                : in    std_logic;
  CLK_DIV_OUT             : out   std_logic;                    -- Slow clock output
  CLK_RESET               : in    std_logic;                    -- Reset signal for Clock circuit
  IO_RESET                : in    std_logic);                   -- Reset signal for IO circuit
end component;


signal   DATA_OUT_TO_PINS_P_UP      :    std_logic_vector(4 downto 0);
signal   DATA_OUT_TO_PINS_N_UP      :    std_logic_vector(4 downto 0);

signal   DATA_OUT_TO_PINS_P_DOWN      :    std_logic_vector(4 downto 0);
signal   DATA_OUT_TO_PINS_N_DOWN      :    std_logic_vector(4 downto 0);

signal   DATA_OUT_FROM_DEVICE_UP      :    std_logic_vector(15 downto 0);
signal   DATA_OUT_FROM_DEVICE_DOWN      :    std_logic_vector(15 downto 0);


component TISC_TISC_Oserdes
generic
 (-- width of the data for the system
  sys_w       : integer := 5; -- one is the clock
  -- width of the data for the device
  dev_w       : integer := 16);
port
 (
  -- From the device out to the system
  DATA_OUT_FROM_DEVICE    : in    std_logic_vector(dev_w-1 downto 0);
  DATA_OUT_TO_PINS_P      : out   std_logic_vector(sys_w-1 downto 0);
  DATA_OUT_TO_PINS_N      : out   std_logic_vector(sys_w-1 downto 0);

 
-- Clock and reset signals
  CLK_IN                  : in    std_logic;                    -- Fast clock from PLL/MMCM 
  CLK_DIV_IN              : in    std_logic;                    -- Slow clock from PLL/MMCM
  IO_RESET                : in    std_logic);                   -- Reset signal for IO circuit
end component;

begin
--- need to add ISERDES out to x4 the inputs... for now copy of Patrick's code in datapath for the input

--IS_phi_down_in: 	for j in 0 to 4 generate 
-- ibufds_inst_down : IBUFDS
--       generic map (
--         DIFF_TERM  => FALSE,             -- Differential termination
--         IOSTANDARD => "LVDS_25")
--       port map (
--         I          => PHI_DOWN_IN_P(j),
--         IB         => PHI_DOWN_IN_N(j),
--         O          => PHI_DOWN_IN_single_ended(j));
----IS_phi_down_in_flag_sync:	flag_sync 
----port map(
----clkA=> CLK,
----clkB=> PARALLEL_CLK,
----in_clkA => bitslip_flag_CLK(j),
----out_clkB => bitslip_flag_REFCLKDIV2(j));
--
--IS_phi_down_in_bit:	entity work.ISERDES_internal_loop 
--generic map(
--LOOP_DELAY => 11,
--IODELAY_GRP_NAME => "IODELAY_down_in")
--port map(
--CLK_BUFIO => SERIAL_CLK,
--CLK_BUFR => PARALLEL_CLK,
--D=>PHI_DOWN_IN_single_ended(j),
--RST=>'0',
--BITSLIP=>'0', -- no bitslip for now
--BYPASS=>open, 
--Q=>phi_down_in(4*j + 3 downto 4*j));
--end generate;
--
-- 
--IS_phi_up_in: 	for j in 0 to 4 generate 
--ibufds_inst_up : IBUFDS
--       generic map (
--         DIFF_TERM  => FALSE,             -- Differential termination
--         IOSTANDARD => "LVDS_25")
--       port map (
--         I          => PHI_UP_IN_P(j),
--         IB         => PHI_UP_IN_N(j),
--         O          => PHI_UP_IN_single_ended(j));
----IS_phi_down_in_flag_sync:	flag_sync 
----port map(
----clkA=> CLK,
----clkB=> PARALLEL_CLK,
----in_clkA => bitslip_flag_CLK(j),
----out_clkB => bitslip_flag_REFCLKDIV2(j));
--
--IS_phi_up_in_bit:	entity work.ISERDES_internal_loop 
--generic map(
--LOOP_DELAY => 11,
--IODELAY_GRP_NAME => "IODELAY_up_in")
--port map(
--CLK_BUFIO => SERIAL_CLK,
--CLK_BUFR => PARALLEL_CLK,
--D=>PHI_UP_IN_single_ended(j),
--RST=>'0',
--BITSLIP=>'0', -- no bitslip for now
--BYPASS=>open, 
--Q=>phi_up_in(4*j + 3 downto 4*j));
--end generate;

ISERDES_up : TISC_TISC_Iserdes
  port map
   (
  -- From the system into the device
  DATA_IN_FROM_PINS_P =>   PHI_UP_IN_P, --Input pins
  DATA_IN_FROM_PINS_N =>   PHI_UP_IN_N, --Input pins
  DATA_IN_TO_DEVICE =>   phi_up_in, --Output pins

  BITSLIP =>   '0',    --Input pin
 
  
-- Clock and reset signals
  CLK_IN_P =>   PHI_UP_IN_CLK_P,     -- Differential clock from IOB
  CLK_IN_N =>   PHI_UP_IN_CLK_N,     -- Differential clock from IOB
  CLK_DIV_OUT =>   open,     -- Slow clock output -- add sync later
  CLK_RESET =>   '0',         --clocking logic reset
  IO_RESET =>   '0');          --system reset

ISERDES_down : TISC_TISC_Iserdes
  port map
   (
  -- From the system into the device
  DATA_IN_FROM_PINS_P =>   PHI_DOWN_IN_P, --Input pins
  DATA_IN_FROM_PINS_N =>   PHI_DOWN_IN_N, --Input pins
  DATA_IN_TO_DEVICE =>   phi_down_in, --Output pins

  BITSLIP =>   '0',    --Input pin
 
  
-- Clock and reset signals
  CLK_IN_P =>   PHI_DOWN_IN_CLK_P,     -- Differential clock from IOB
  CLK_IN_N =>   PHI_DOWN_IN_CLK_N,     -- Differential clock from IOB
  CLK_DIV_OUT =>   open,     -- Slow clock output -- add sync later
  CLK_RESET =>   '0',         --clocking logic reset
  IO_RESET =>   '0');          --system reset


PHI_DOWN_OUT_CLK_P<= DATA_OUT_TO_PINS_P_DOWN(4);
PHI_DOWN_OUT_CLK_N<= DATA_OUT_TO_PINS_N_DOWN(4);
PHI_DOWN_OUT_P<= DATA_OUT_TO_PINS_P_DOWN(3 downto 0);
PHI_DOWN_OUT_N<= DATA_OUT_TO_PINS_N_DOWN(3 downto 0);

DATA_OUT_FROM_DEVICE_DOWN <= not( phi_down_out); -- inverted outputs!

OSERDES_down : TISC_TISC_Oserdes
  port map
   (
  -- From the device out to the system
  DATA_OUT_FROM_DEVICE =>   DATA_OUT_FROM_DEVICE_DOWN, --Input pins
  DATA_OUT_TO_PINS_P =>  DATA_OUT_TO_PINS_P_DOWN , --Output pins
  DATA_OUT_TO_PINS_N =>  DATA_OUT_TO_PINS_N_DOWN , --Output pins

 
  
-- Clock and reset signals
  CLK_IN =>   SERIAL_CLK,      -- Fast clock input from PLL/MMCM -- note that the clock is actually inverted - there is going to be a misalignment now
  CLK_DIV_IN =>   PARALLEL_CLK,    -- Slow clock input from PLL/MMCM
  IO_RESET =>   '0');          --system reset

PHI_UP_OUT_CLK_P<= DATA_OUT_TO_PINS_P_UP(4);
PHI_UP_OUT_CLK_N<= DATA_OUT_TO_PINS_N_UP(4);
PHI_UP_OUT_P<= DATA_OUT_TO_PINS_P_UP(3 downto 0);
PHI_UP_OUT_N<= DATA_OUT_TO_PINS_N_UP(3 downto 0);

DATA_OUT_FROM_DEVICE_UP <= ( phi_up_out);

OSERDES_up : TISC_TISC_Oserdes
  port map
   (
  -- From the device out to the system
  DATA_OUT_FROM_DEVICE =>   DATA_OUT_FROM_DEVICE_UP, --Input pins
  DATA_OUT_TO_PINS_P =>   DATA_OUT_TO_PINS_P_UP, --Output pins
  DATA_OUT_TO_PINS_N =>   DATA_OUT_TO_PINS_N_UP, --Output pins

 
  
-- Clock and reset signals
  CLK_IN =>   SERIAL_CLK,      -- Fast clock input from PLL/MMCM
  CLK_DIV_IN =>   PARALLEL_CLK,    -- Slow clock input from PLL/MMCM
  IO_RESET =>   '0');          --system reset



end Behavioral;

