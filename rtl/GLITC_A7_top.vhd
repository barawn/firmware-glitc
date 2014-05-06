----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:53:38 03/28/2014 
-- Design Name: 
-- Module Name:    GLITC_A7_top - Behavioral 
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

entity GLITC_A7_top is
port(
-- Inter-GLITC communication: naming convention: "DOWN" means toward the GLITC connected to lower phi-sectors (mod 16)
-- "UP" toward higher, and OUT and IN have the natural interpretation. So, for example PHI_DOWN_OUT is meant to output
-- the lower phi sector (e.g. in case of GLITC_A, "0" going toward the GLITC operating on "14" and "15" (-2 and -1))
-- and PHI_UP_IN is receiving the upper phi sector (e.g. in case of GLITC_A, phi sector "3")
PHI_DOWN_OUT_CLK_P : out std_logic;
PHI_DOWN_OUT_CLK_N : out std_logic;
PHI_DOWN_OUT_P :out std_logic_vector(3 downto 0);
PHI_DOWN_OUT_N :out std_logic_vector(3 downto 0);

PHI_UP_OUT_CLK_P : out std_logic;
PHI_UP_OUT_CLK_N : out std_logic;
PHI_UP_OUT_P :out std_logic_vector(3 downto 0);
PHI_UP_OUT_N :out std_logic_vector(3 downto 0);

PHI_DOWN_IN_CLK_P : in std_logic;
PHI_DOWN_IN_CLK_N : in std_logic;
PHI_DOWN_IN_P :in std_logic_vector(3 downto 0);
PHI_DOWN_IN_N :in std_logic_vector(3 downto 0);

PHI_UP_IN_CLK_P : in std_logic;
PHI_UP_IN_CLK_N : in std_logic;
PHI_UP_IN_P :in std_logic_vector(3 downto 0);
PHI_UP_IN_N :in std_logic_vector(3 downto 0);

-- Monitoring pins
GA_MON : out std_logic_vector(4 downto 0);

-- System clock
GA_SYSCLK_P : in std_logic;
GA_SYSCLK_N : in std_logic;



-- Data to/from TURF 
TA_OUT_P :out std_logic_vector(1 downto 0); -- single phi sector indicators
TA_OUT_N :out std_logic_vector(1 downto 0);
TA_IN_P :in std_logic; -- from TURF, PPS-like signal to synchronize GLITCs
TA_IN_N :in std_logic;

-- Source sync data from Channel A (Ritc 0)
A_CLK_P : in std_logic;
A_CLK_N : in std_logic;
A_P :in std_logic_vector(11 downto 0);
A_N :in std_logic_vector(11 downto 0);
-- Source sync data from Channel B (Ritc 0)
B_CLK_P : in std_logic;
B_CLK_N : in std_logic;
B_P :in std_logic_vector(11 downto 0);
B_N :in std_logic_vector(11 downto 0);
-- Source sync data from Channel C (Ritc 0)
C_CLK_P : in std_logic;
C_CLK_N : in std_logic;
C_P :in std_logic_vector(11 downto 0);
C_N :in std_logic_vector(11 downto 0);

-- Source sync data from Channel D (Ritc 1)
D_CLK_P : in std_logic;
D_CLK_N : in std_logic;
D_P :in std_logic_vector(11 downto 0);
D_N :in std_logic_vector(11 downto 0);
-- Source sync data from Channel E (Ritc 1)
E_CLK_P : in std_logic;
E_CLK_N : in std_logic;
E_P :in std_logic_vector(11 downto 0);
E_N :in std_logic_vector(11 downto 0);
-- Source sync data from Channel F (Ritc 1)
F_CLK_P : in std_logic;
F_CLK_N : in std_logic;
F_P :in std_logic_vector(11 downto 0);
F_N :in std_logic_vector(11 downto 0);

-- Clock from TISC FPGA
GCLK : in std_logic;
-- GLITCBUS signals
GRDWR_B : in std_logic;
GSEL_B : in std_logic; 
GAD : inout std_logic_vector(7 downto 0);

-- Ritc 0 interface 
R0_VCDL : out std_logic; --  clock for R0
R0_TRAIN : out std_logic; -- turn on training pattern
R0_DAC_DIN : out std_logic; -- Set internal DACs signals
R0_DAC_LATCH : out std_logic; -- Set internal DACs signals
R0_DAC_CLK : out std_logic; -- Set internal DACs signals
 
-- Ritc 1 interface 
R1_VCDL : out std_logic; -- clock for R0
R1_TRAIN : out std_logic; -- turn on training pattern
R1_DAC_DIN : out std_logic; -- Set internal DACs signals
R1_DAC_LATCH : out std_logic; -- Set internal DACs signals
R1_DAC_CLK : out std_logic; -- Set internal DACs signals

GA_SDA : inout std_logic;
GA_SCL : out std_logic
);
end GLITC_A7_top;
 
architecture Behavioral of GLITC_A7_top is
signal SYSCLK : std_logic; --derived from GA_SYSCLK, and used also to communicate with TURF 

signal PHI_A_FOR_TURF : std_logic; -- TURF-synchronous single phi sector trigger
signal PHI_B_FOR_TURF : std_logic; -- TURF-synchronous single phi sector trigger
 
component glitc_turf_if 
port(
SYSCLK : in std_logic; -- also using GACLK for TURF communication
TA_OUT_P :out std_logic_vector(1 downto 0); -- single phi sector indicators
TA_OUT_N :out std_logic_vector(1 downto 0);
TA_IN_P :in std_logic; -- from TURF, PPS-like signal to synchronize GLITCs
TA_IN_N :in std_logic;
PHI_A_in :in std_logic;
PHI_B_in :in std_logic;
PPS_OUT: out std_logic
);
end component;



signal GAD_IN : std_logic_vector(7 downto 0);
signal GAD_OUT : std_logic_vector(7 downto 0);
signal GAD_DIR:  std_logic; -- tristate out control for GAD, normally in, out only for 4 clock cycles.
signal GLITCBUS_VALID_DATA :  std_logic; -- remains '1' after a write, until a new GSEL is issued. Should make clock sync trivial.
signal GLITCBUS_DATA_IN :  std_logic_vector(31 downto 0);
signal GLITCBUS_DATA_OUT : std_logic_vector(31 downto 0);
signal GLITCBUS_ADD :  std_logic_vector(15 downto 0);


signal GLITCBUS_VALID_DATA_old :  std_logic; 
signal NEW_VALID_DATA :  std_logic; 



component GLITCBUS_if 
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
end component;

	type arr_12_3 is array(0 to 2) of std_logic_vector(11 downto 0);
	type arr_48_3 is array(0 to 2) of std_logic_vector(47 downto 0);
	
	--% RITC incoming data (after differential input buffer). 4 samples of 3 bits each (at 4X clock rate)
	signal RITC_DATA_A : arr_12_3;
	signal RITC_DATA_B : arr_12_3;
	--% Delayed RITC data (after IODELAY)
	signal RITC_DATA_A_delay : arr_12_3;
	signal RITC_DATA_B_delay : arr_12_3;
	--% Deserialized data (4-fold) from the RITC. Now 16 samples of 3 bits each.
	signal RITC_DATA_A_deserialize  : arr_48_3;
	signal RITC_DATA_B_deserialize  : arr_48_3;
	--% Incoming data (not deserialized) passed from the deserializer (SERDES) for scanning.
	signal RITC_DATA_A_bypass : arr_12_3;
	signal RITC_DATA_B_bypass : arr_12_3;
	
	
   signal CH0_A_P :  std_logic_vector(11 downto 0);
   signal CH0_A_N :  std_logic_vector(11 downto 0);
	signal CH1_A_P :  std_logic_vector(11 downto 0);
   signal CH1_A_N :  std_logic_vector(11 downto 0);
	signal CH2_A_P :  std_logic_vector(11 downto 0);
   signal CH2_A_N :  std_logic_vector(11 downto 0);
   signal CH0_A :  std_logic_vector(11 downto 0);
   signal CH1_A :  std_logic_vector(11 downto 0);
   signal CH2_A :  std_logic_vector(11 downto 0);
	
   signal CH0_B_P :  std_logic_vector(11 downto 0);
   signal CH0_B_N :  std_logic_vector(11 downto 0);
	signal CH1_B_P :  std_logic_vector(11 downto 0);
   signal CH1_B_N :  std_logic_vector(11 downto 0);
	signal CH2_B_P :  std_logic_vector(11 downto 0);
   signal CH2_B_N :  std_logic_vector(11 downto 0);
   signal CH0_B :  std_logic_vector(11 downto 0);
   signal CH1_B :  std_logic_vector(11 downto 0);
   signal CH2_B :  std_logic_vector(11 downto 0);

	
component RITC_input_buffers
port(
CH0_P : in std_logic_vector(11 downto 0);
CH0_N : in std_logic_vector(11 downto 0);
CH1_P : in std_logic_vector(11 downto 0);
CH1_N : in std_logic_vector(11 downto 0);
CH2_P : in std_logic_vector(11 downto 0);
CH2_N : in std_logic_vector(11 downto 0);
CH0 : out std_logic_vector(11 downto 0);
CH1 : out std_logic_vector(11 downto 0);
CH2: out std_logic_vector(11 downto 0)
    );
end component;

signal CLK200 : std_logic; 			-- 200 MHz IDELAYCTRL clock
signal SYSCLK_DIV2_PS : std_logic;  -- 81.25MHz, with for phase scanner
signal DATACLK : std_logic; 			-- 325 MHz data capture clock, slight phase shift (~512 ps)
signal DATACLK_DIV2 : std_logic; 	-- 162.5MHz parallel capture clock, slight phase shift (~512 ps)
signal SYSCLKX2 : std_logic;			-- 325 MHz serdes capture/transmit clock. No phase shift.

component I2C_generic 
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
end component;

component TISC_TISC_comm 
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

phi_down_in : in  std_logic_vector(15 downto 0);
PHI_DOWN_IN_CLK_P : in std_logic;
PHI_DOWN_IN_CLK_N : in std_logic;
PHI_DOWN_IN_P :in std_logic_vector(3 downto 0);
PHI_DOWN_IN_N :in std_logic_vector(3 downto 0);

phi_up_in : in  std_logic_vector(15 downto 0);
PHI_UP_IN_CLK_P : in std_logic;
PHI_UP_IN_CLK_N : in std_logic;
PHI_UP_IN_P :in std_logic_vector(3 downto 0);
PHI_UP_IN_N :in std_logic_vector(3 downto 0)
);
end component;

signal phi_down_out :  std_logic_vector(15 downto 0);
signal phi_down_in :  std_logic_vector(15 downto 0);
signal phi_up_out :  std_logic_vector(15 downto 0);
signal phi_up_in :  std_logic_vector(15 downto 0);

signal I2C_address :  std_logic_vector(7 downto 0);
signal I2C_command :  std_logic_vector(7 downto 0);
signal I2C_byte1 :  std_logic_vector(7 downto 0);
signal I2C_byte2 :  std_logic_vector(7 downto 0);
signal I2C_length_flag :  std_logic; -- only 2 commands - with one or 2 value bytes
signal I2C_transmit :  std_logic;
signal I2C_ready :  std_logic;

signal REFCLK_A_P : std_logic_vector(2 downto 0);
signal REFCLK_A_N : std_logic_vector(2 downto 0);
signal REFCLK_A : std_logic_vector(2 downto 0);
signal REFCLK_A_delay : std_logic_vector(2 downto 0);

signal REFCLK_B_P : std_logic_vector(2 downto 0);
signal REFCLK_B_N : std_logic_vector(2 downto 0);
signal REFCLK_B : std_logic_vector(2 downto 0);
signal REFCLK_B_delay : std_logic_vector(2 downto 0);




signal datapath_reset : std_logic;
signal user_wr : std_logic;
signal user_rd : std_logic;
signal user_data_from_if : std_logic_vector(7 downto 0);

signal sel_delay_control_A : std_logic;
signal addr_delay_control_A : std_logic;
signal user_data_from_if_A : std_logic_vector(7 downto 0);
signal data_from_delay_control_A : std_logic_vector(7 downto 0);
signal user_wr_A : std_logic;
signal user_rd_A : std_logic;

signal sel_delay_control_B : std_logic;
signal addr_delay_control_B : std_logic;
signal user_data_from_if_B : std_logic_vector(7 downto 0);
signal data_from_delay_control_B : std_logic_vector(7 downto 0);
signal user_wr_B : std_logic;
signal user_rd_B : std_logic;

signal SERDES_CLKDIV_A : std_logic_vector(2 downto 0);
signal SERDES_CLKDIV_B : std_logic_vector(2 downto 0);

signal RITC_A_serdes_bitslip : std_logic;
signal RITC_B_serdes_bitslip : std_logic;
signal RITC_A_serdes_bitslip_addr : std_logic_vector(5 downto 0);
signal RITC_B_serdes_bitslip_addr : std_logic_vector(5 downto 0);

signal RITC_A_VCDL_SYNC : std_logic;
signal RITC_B_VCDL_SYNC : std_logic;

signal sel_phase_scanner : std_logic;
signal addr_phase_scanner : std_logic_vector(2 downto 0);
signal data_from_phase_scanner : std_logic_vector(7 downto 0);
signal SCAN_VALID : std_logic;
signal SCAN_DONE : std_logic;
signal scan_debug : std_logic_vector(2 downto 0);



signal phase_control_clock_A : std_logic;
signal phase_control_in_A : std_logic_vector(7 downto 0);
signal phase_control_out_A : std_logic_vector(7 downto 0);
signal sel_phase_scanner_A : std_logic;
signal addr_phase_scanner_A : std_logic_vector(2 downto 0);
signal data_from_phase_scanner_A : std_logic_vector(7 downto 0);
signal SCAN_RESULT_A : std_logic;
signal SCAN2_RESULT_A : std_logic;
signal SCAN3_RESULT_A : std_logic;
signal SCAN_VALID_A : std_logic;
signal SCAN_DONE_A : std_logic;
signal SERVO_VDD_INCR_A : std_logic;
signal SERVO_VDD_DECR_A : std_logic;
signal REFCLK_Q_A : std_logic_vector(2 downto 0);
signal scan_debug_A : std_logic_vector(2 downto 0);


signal phase_control_clock_B : std_logic;
signal phase_control_in_B : std_logic_vector(7 downto 0);
signal phase_control_out_B : std_logic_vector(7 downto 0);
signal sel_phase_scanner_B : std_logic;
signal addr_phase_scanner_B : std_logic_vector(2 downto 0);
signal data_from_phase_scanner_B : std_logic_vector(7 downto 0);
signal SCAN_RESULT_B : std_logic;
signal SCAN2_RESULT_B : std_logic;
signal SCAN3_RESULT_B : std_logic;
signal SCAN_VALID_B : std_logic;
signal SCAN_DONE_B : std_logic;
signal SERVO_VDD_INCR_B : std_logic;
signal SERVO_VDD_DECR_B : std_logic;
signal REFCLK_Q_B : std_logic_vector(2 downto 0);
signal scan_debug_B : std_logic_vector(2 downto 0);

signal phase_control_clock : std_logic; -- multiplex common one?
signal phase_control_in : std_logic_vector(7 downto 0);
signal phase_control_out : std_logic_vector(7 downto 0);


signal clockpath_reset : std_logic;


signal sel_ritc_dac_A : std_logic;
signal addr_ritc_dac_A : std_logic_vector(1 downto 0);
signal data_from_ritc_dac_A : std_logic_vector(7 downto 0);
signal RITC_A_DAC_DIN : std_logic;
signal RITC_A_DAC_DOUT : std_logic;
signal RITC_A_DAC_CLOCK : std_logic;
signal RITC_A_DAC_LATCH : std_logic;
signal VDD_A : std_logic_vector(11 downto 0);

signal sel_ritc_dac_B : std_logic;
signal addr_ritc_dac_B : std_logic_vector(1 downto 0);
signal data_from_ritc_dac_B : std_logic_vector(7 downto 0);
signal RITC_B_DAC_DIN : std_logic;
signal RITC_B_DAC_DOUT : std_logic;
signal RITC_B_DAC_CLOCK : std_logic;
signal RITC_B_DAC_LATCH : std_logic;
signal VDD_B : std_logic_vector(11 downto 0);



signal global_synchronizer : std_logic;
signal datapath_reset_A : std_logic;
signal datapath_reset_B : std_logic;

signal sel_ritc_control_A : std_logic;
signal addr_ritc_control_A : std_logic_vector(1 downto 0);
signal data_from_ritc_control_A : std_logic_vector(7 downto 0);
signal RITC_A_VCDL_START : std_logic;
signal ritc_vcdl_debug_A : std_logic;
signal vcdl_counter_A : std_logic_vector(9 downto 0);
signal TRAINING_ON_A : std_logic;
signal train_sync_A : std_logic_vector(7 downto 0);

signal sel_ritc_control_B : std_logic;
signal addr_ritc_control_B : std_logic_vector(1 downto 0);
signal data_from_ritc_control_B : std_logic_vector(7 downto 0);
signal RITC_B_VCDL_START : std_logic;
signal ritc_vcdl_debug_B : std_logic;
signal vcdl_counter_B : std_logic_vector(9 downto 0);
signal TRAINING_ON_B : std_logic;
signal train_sync_B : std_logic_vector(7 downto 0);


signal sum_max_up : std_logic_vector(11 downto 0);
signal pos_sum_max_up : std_logic_vector(5 downto 0);

signal sum_max_down : std_logic_vector(11 downto 0);
signal pos_sum_max_down : std_logic_vector(5 downto 0);


signal sum_max_A : std_logic_vector(11 downto 0);
signal pos_sum_max_A : std_logic_vector(5 downto 0);
signal zero_delay_A : std_logic_vector(11 downto 0);
signal map_18_delay_A : std_logic_vector(11 downto 0);
signal A_18_A : std_logic_vector(47 downto 0);
signal B_18_A : std_logic_vector(47 downto 0);
signal C_18_A : std_logic_vector(47 downto 0);
signal A_45_A : std_logic_vector(47 downto 0);
signal B_45_A : std_logic_vector(47 downto 0);
signal C_45_A : std_logic_vector(47 downto 0);
signal powerA_A : std_logic_vector(30 downto 0);
signal powerB_A : std_logic_vector(30 downto 0);
signal powerC_A : std_logic_vector(30 downto 0);
signal sumA_A : std_logic_vector(30 downto 0);
signal sumB_A : std_logic_vector(30 downto 0);
signal sumC_A : std_logic_vector(30 downto 0);
signal new_power_flag_A : std_logic;
signal acc_cnt_debug_A : std_logic_vector(23 downto 0);

signal sum_max_B : std_logic_vector(11 downto 0);
signal pos_sum_max_B : std_logic_vector(5 downto 0);
signal zero_delay_B : std_logic_vector(11 downto 0);
signal map_18_delay_B : std_logic_vector(11 downto 0);
signal A_18_B : std_logic_vector(47 downto 0);
signal B_18_B : std_logic_vector(47 downto 0);
signal C_18_B : std_logic_vector(47 downto 0);
signal A_45_B : std_logic_vector(47 downto 0);
signal B_45_B : std_logic_vector(47 downto 0);
signal C_45_B : std_logic_vector(47 downto 0);
signal powerA_B : std_logic_vector(30 downto 0);
signal powerB_B : std_logic_vector(30 downto 0);
signal powerC_B : std_logic_vector(30 downto 0);
signal sumA_B : std_logic_vector(30 downto 0);
signal sumB_B : std_logic_vector(30 downto 0);
signal sumC_B : std_logic_vector(30 downto 0);
signal new_power_flag_B : std_logic;
signal acc_cnt_debug_B : std_logic_vector(23 downto 0);
				
				
signal phase_control_A_notB : std_logic;

signal user_address : std_logic_vector(6 downto 0);
signal user_data_to_if : std_logic_vector(7 downto 0);



component trigger_module port(
CLK : in std_logic;
sum_low : in std_logic_vector(11 downto 0);
sum_center : in std_logic_vector(11 downto 0);
sum_high : in std_logic_vector(11 downto 0);
threshold : in std_logic_vector(11 downto 0);
trigger : out std_logic);
end component;

signal threshold_A : std_logic_vector(11 downto 0);
signal threshold_B : std_logic_vector(11 downto 0);
signal trigger_A : std_logic;
signal trigger_B : std_logic;

signal REFCLK_A_to_BUFR : std_logic;
signal REFCLK_B_to_BUFR : std_logic;

begin

GA_MON <= ( others => '0' );

REFCLK_A_P <= C_CLK_P & B_CLK_P & A_CLK_P; -- channel 0 => A
REFCLK_A_N <= C_CLK_N & B_CLK_N & A_CLK_N; -- channel 0 => A
REFCLK_B_P <= F_CLK_P & E_CLK_P & D_CLK_P; -- channel 0 => D
REFCLK_B_N <= F_CLK_N & E_CLK_N & D_CLK_N; -- channel 0 => D

u_clock_generator:	entity work.RITC_clock_generator_V3_LM 
port map( 
CLK_IN_P => GA_SYSCLK_P ,
CLK_IN_N => GA_SYSCLK_N ,
CLK200 => CLK200 ,
SYSCLK => SYSCLK ,
SYSCLK_DIV2_PS => SYSCLK_DIV2_PS ,
SYSCLKX2 => SYSCLKX2 ,
DATACLK => DATACLK ,
DATACLK_DIV2 => DATACLK_DIV2 ,

REFCLK_A_P => REFCLK_A_P ,
REFCLK_A_N => REFCLK_A_N ,
REFCLK_A => REFCLK_A ,

REFCLK_B_P => REFCLK_B_P ,
REFCLK_B_N => REFCLK_B_N ,
REFCLK_B => REFCLK_B ,

phase_control_clk => phase_control_clock , --? as before?
--phase_control_clk => SYSCLK ,
phase_control_in => phase_control_in ,
phase_control_out => phase_control_out ,
system_reset => clockpath_reset -- single - gets distributed to both RITC phase circuits
);


trigger_module_A: trigger_module port map(
CLK=>SYSCLK,
sum_low => sum_max_down,
sum_center => sum_max_A,
sum_high => sum_max_B,
threshold => threshold_A,
trigger => trigger_A);

trigger_module_B: trigger_module port map(
CLK=>SYSCLK,
sum_low => sum_max_A,
sum_center => sum_max_B,
sum_high => sum_max_up,
threshold => threshold_B,
trigger => trigger_B);

PHI_A_FOR_TURF<=trigger_A;
PHI_B_FOR_TURF<=trigger_B;

glitc_turf_if_u: glitc_turf_if port map(
SYSCLK => SYSCLK,
-- Data to/from TURF 
TA_OUT_P => TA_OUT_P, -- single phi sector indicators
TA_OUT_N => TA_OUT_N,
TA_IN_P =>  TA_IN_P,-- from TURF, PPS-like signal to synchronize GLITCs
TA_IN_N => TA_IN_N, -- missing the input from phi sectors, and output for PPS
PHI_A_in => PHI_A_FOR_TURF,
PHI_B_in => PHI_B_FOR_TURF
);



GAD_buffer_gen: for i in 0 to 7 generate
GAD_buffer: IOBUF
generic map (
DRIVE => 12,
IOSTANDARD => "DEFAULT",
SLEW => "SLOW")
port map (
O => GAD_IN(i), -- Buffer output
IO => GAD(i), -- Buffer inout port (connect directly to top-level port)
I => GAD_OUT(i), -- Buffer input
T => GAD_DIR -- 3-state enable input, high=input, low=output
);
end generate;

GLITCBUS_if_u: GLITCBUS_if port map(
-- Clock from TISC FPGA
GCLK =>  GCLK,
-- GLITCBUS signals
GRDWR_B => GRDWR_B,
GSEL_B => GSEL_B,
GAD_IN => GAD_IN,
GAD_OUT => GAD_OUT,
GAD_DIR => GAD_DIR,
VALID_DATA => GLITCBUS_VALID_DATA,
DATA_IN => GLITCBUS_DATA_IN,
DATA_OUT => GLITCBUS_DATA_OUT,
ADD => GLITCBUS_ADD
);


-- Below needs to be rewritten and polished from the baroque mess it is. Wait to see if different GLITCBUS strategies are preferred.
process(GCLK)
begin
if rising_edge(GCLK) then -- note: this will in general have a conflict - need to add TIGs or path timing qualifications or better some domain crossing strategy
	user_wr <= '0';
	user_wr_A <= '0';
	user_wr_B <= '0';
	user_rd <= '1'; -- always read
	user_rd_A <= '1'; -- always read
	user_rd_B <= '1';
	user_address <= GLITCBUS_ADD(6 downto 0);
	I2C_transmit<= '0';
	GLITCBUS_VALID_DATA_old <= GLITCBUS_VALID_DATA;
	if GLITCBUS_VALID_DATA = '1' and GLITCBUS_VALID_DATA_old = '0' then NEW_VALID_DATA <= '1'; else NEW_VALID_DATA <= '0'; end if;
	if GLITCBUS_ADD(7)= '0' then -- calibration
		GLITCBUS_DATA_IN<=x"000000" & user_data_to_if; -- it will need to be multiplexed with other requests.
	else
		if GLITCBUS_ADD(7 downto 1) = "1100000" then -- I2C commands:  1100 000 0 -> write address command byte1 
																	--					 	1100 000 1 -> write address command byte1 byte2 
					
			if NEW_VALID_DATA = '1' then
				I2C_command <= GLITCBUS_DATA_OUT(7 downto 0);
				I2C_byte1 <= GLITCBUS_DATA_OUT(15 downto 8);
				I2C_byte2 <= GLITCBUS_DATA_OUT(23 downto 16);
				I2C_address <= GLITCBUS_DATA_OUT(31 downto 24);
				I2C_length_flag <= GLITCBUS_ADD(0);
				I2C_transmit<= '1'; -- this will be longer than a single cycle if no proper domain crossing done, but it should be fine given 
										 -- response time of I2C module.
			end if;
		elsif GLITCBUS_ADD(7 downto 0) = "11000001" then 
			threshold_A<= GLITCBUS_DATA_OUT(11 downto 0);
		elsif GLITCBUS_ADD(7 downto 0) = "11000010" then 
			threshold_B<= GLITCBUS_DATA_OUT(11 downto 0);
		else
			case GLITCBUS_ADD(3 downto 0) is
				when "0000" => GLITCBUS_DATA_IN<= x"000" & "00" & pos_sum_max_A & sum_max_A; -- not particularly useful as is - 33MHz and 8 cycles per readout...
				when "0001" => GLITCBUS_DATA_IN<= x"000" & "00" & pos_sum_max_B & sum_max_B; -- here only to guarantee things don't get simplified away in first attempt of compilation
				when others => GLITCBUS_DATA_IN<= (others=>'0');
			end case;
		end if;
	end if;
	if NEW_VALID_DATA = '1' then
		if GLITCBUS_ADD(7)= '0' then -- calibration
			user_wr <= '1';  -- this will be longer than a single cycle if no proper domain crossing done - ask Patrick if a problem.
			user_wr_A <= not user_address(5);
			user_wr_B <=  user_address(5);
			user_data_from_if_A <= GLITCBUS_DATA_OUT(7 downto 0);
			user_data_from_if_B <= GLITCBUS_DATA_OUT(7 downto 0);
			user_data_from_if <= GLITCBUS_DATA_OUT(7 downto 0);
		end if;
	end if;
end if;
end process;

--GLITCBUS_memory_u:  GLITCBUS_memory_u port map(
--INCLK =>  GCLK,
--VALID_DATA => GLITCBUS_VALID_DATA,
--DATA_IN => GLITCBUS_DATA_IN,
--ADD => GLITCBUS_ADD
--DATA_OUT => GLITCBUS_DATA_OUT,
--
--
--);

-- Careful with name meanings: for inputs the various channels are A, B, C, D, E, F,
--						but inside the code the 3 channels of a RITC are marked 0, 1, 2
--					   and the 2 RITCs are distinguished as A and B
-- WARNING! Need to check that the order of the 12 bits uis the same in the 2 projects!!!
CH0_A_P <= A_P;
CH1_A_P <= B_P;
CH2_A_P <= C_P;
CH0_A_N <= A_N;
CH1_A_N <= B_N;
CH2_A_N <= C_N;
--% Input buffers. Convert incoming differential to single-ended.
u_input_buffers_A: RITC_input_buffers port map(
CH0_P => CH0_A_P,
CH0_N => CH0_A_N,
CH1_P => CH1_A_P,
CH1_N => CH1_A_N,
CH2_P => CH2_A_P,
CH2_N => CH2_A_N,
CH0 => RITC_DATA_A(0),
CH1 => RITC_DATA_A(1),
CH2 => RITC_DATA_A(2));

CH0_B_P <= D_P;
CH1_B_P <= E_P;
CH2_B_P <= F_P;
CH0_B_N <= D_N;
CH1_B_N <= E_N;
CH2_B_N <= F_N;

u_input_buffers_B: RITC_input_buffers port map(
CH0_P => CH0_B_P,
CH0_N => CH0_B_N,
CH1_P => CH1_B_P,
CH1_N => CH1_B_N,
CH2_P => CH2_B_P,
CH2_N => CH2_B_N,
CH0 => RITC_DATA_B(0),
CH1 => RITC_DATA_B(1),
CH2 => RITC_DATA_B(2));

u_idelay_A:	entity work.RITC_IDELAY 
generic map(
CH0_POLARITY => "0000000000000",
CH1_POLARITY => "0000000000000",
CH2_POLARITY => "1111111111111",
GRP0_NAME => "IODELAY_14",
GRP0_CLOCK_NAME => "IODELAY_14",
GRP1_NAME => "IODELAY_15",
GRP1_CLOCK_NAME => "IODELAY_15",
GRP2_NAME => "IODELAY_16",
GRP2_CLOCK_NAME => "IODELAY_16",
IDELAYCTRL_LOC0 => "IDELAYCTRL_X0Y2", -- bank 14
IDELAYCTRL_LOC1 => "IDELAYCTRL_X0Y3", -- bank 15
IDELAYCTRL_LOC2 => "IDELAYCTRL_X0Y4"  -- bank 16
)
port map(
CLK200 => CLK200,
CH0 => RITC_DATA_A(0),
CH0_CLK => REFCLK_A(0),
CH1 => RITC_DATA_A(1),
CH1_CLK => REFCLK_A(1),
CH2 => RITC_DATA_A(2),
CH2_CLK => REFCLK_A(2),
REFCLKDIV2 => SERDES_CLKDIV_A,


CH0_delay => RITC_DATA_A_delay(0),
CH0_CLK_delay => REFCLK_A_delay(0),
CH1_delay => RITC_DATA_A_delay(1),
CH1_CLK_delay => REFCLK_A_delay(1),
CH2_delay => RITC_DATA_A_delay(2),
CH2_CLK_delay => REFCLK_A_delay(2),

CLK => SYSCLK,
user_sel_i => sel_delay_control_A,
user_addr_i => addr_delay_control_A,
user_dat_i => user_data_from_if_A,
user_dat_o => data_from_delay_control_A,
user_wr_i => user_wr_A,
user_rd_i => user_rd_A,
rst_i => datapath_reset_A
);


u_idelay_B:	entity work.RITC_IDELAY 
generic map(
CH0_POLARITY => "0000000000000",
CH1_POLARITY => "0000000000000",
CH2_POLARITY => "1111111111111",
GRP0_NAME => "IODELAY_35",
GRP0_CLOCK_NAME => "IODELAY_35",
GRP1_NAME => "IODELAY_34",
GRP1_CLOCK_NAME => "IODELAY_34",
GRP2_NAME => "IODELAY_13",
GRP2_CLOCK_NAME => "IODELAY_13",
IDELAYCTRL_LOC0 => "IDELAYCTRL_X1Y3",  -- bank 35
IDELAYCTRL_LOC1 => "IDELAYCTRL_X1Y2",  -- bank 34
IDELAYCTRL_LOC2 => "IDELAYCTRL_X0Y1"   -- bank 13
)
port map(
CLK200 => CLK200,
CH0 => RITC_DATA_B(0),
CH0_CLK => REFCLK_B(0),
CH1 => RITC_DATA_B(1),
CH1_CLK => REFCLK_B(1),
CH2 => RITC_DATA_B(2),
CH2_CLK => REFCLK_B(2),
REFCLKDIV2 => SERDES_CLKDIV_B,

CH0_delay => RITC_DATA_B_delay(0),
CH0_CLK_delay => REFCLK_B_delay(0),
CH1_delay => RITC_DATA_B_delay(1),
CH1_CLK_delay => REFCLK_B_delay(1),
CH2_delay => RITC_DATA_B_delay(2),
CH2_CLK_delay => REFCLK_B_delay(2),

CLK => SYSCLK,
user_sel_i => sel_delay_control_B,
user_addr_i => addr_delay_control_B,
user_dat_i => user_data_from_if_B,
user_dat_o => data_from_delay_control_B,
user_wr_i => user_wr_B,
user_rd_i => user_rd_B,
rst_i => datapath_reset_B
);

u_datapath_A :	entity work.RITC_datapath generic map(
	GRP0_NAME => "IODELAY_14",
	GRP1_NAME => "IODELAY_15",
	GRP2_NAME => "IODELAY_16"	
)
port map(
REFCLK=>REFCLK_A_delay,
CH0=>RITC_DATA_A_delay(0),
CH1=>RITC_DATA_A_delay(1),
CH2=>RITC_DATA_A_delay(2),
DATACLK=>DATACLK,
DATACLK_DIV2=>DATACLK_DIV2,

CLK=>SYSCLK,
RST=>datapath_reset_A,
BITSLIP=>RITC_A_serdes_bitslip,
BITSLIP_ADDR=>RITC_A_serdes_bitslip_addr,
CH0_OUT=>RITC_DATA_A_deserialize(0),
CH1_OUT=>RITC_DATA_A_deserialize(1),
CH2_OUT=>RITC_DATA_A_deserialize(2),

SERDES_CLKDIV=>SERDES_CLKDIV_A,

CH0_BYPASS=>RITC_DATA_A_bypass(0),
CH1_BYPASS=>RITC_DATA_A_bypass(1),
CH2_BYPASS=>RITC_DATA_A_bypass(2)
									 );


u_datapath_B :	entity work.RITC_datapath generic map(
	GRP0_NAME => "IODELAY_35",
	GRP1_NAME => "IODELAY_34",
	GRP2_NAME => "IODELAY_13"
)
port map(
REFCLK=>REFCLK_B_delay,
CH0=>RITC_DATA_B_delay(0),
CH1=>RITC_DATA_B_delay(1),
CH2=>RITC_DATA_B_delay(2),
DATACLK=>DATACLK,
DATACLK_DIV2=>DATACLK_DIV2,

CLK=>SYSCLK,
RST=>datapath_reset_B,
BITSLIP=>RITC_B_serdes_bitslip,
BITSLIP_ADDR=>RITC_B_serdes_bitslip_addr,
CH0_OUT=>RITC_DATA_B_deserialize(0),
CH1_OUT=>RITC_DATA_B_deserialize(1),
CH2_OUT=>RITC_DATA_B_deserialize(2),

SERDES_CLKDIV=>SERDES_CLKDIV_B,

CH0_BYPASS=>RITC_DATA_B_bypass(0),
CH1_BYPASS=>RITC_DATA_B_bypass(1),
CH2_BYPASS=>RITC_DATA_B_bypass(2)
									 );

--
--u_phase_scanner_A : 	entity work.RITC_phase_scanner_v2 port map(
--CLK=>SYSCLK,
--CLK_PS=>SYSCLK_DIV2_PS,
--CLOCK_SCAN=>REFCLK_A_delay,
--CH0_SCAN=>RITC_DATA_A_bypass(0),
--CH1_SCAN=>RITC_DATA_A_bypass(1),
--CH2_SCAN=>RITC_DATA_A_bypass(2),
--VCDL_SCAN=>RITC_A_VCDL_SYNC,
--phase_control_clk=>open, -- permanently connected to SYSCLK
--phase_control_out=>phase_control_in_A,
--phase_control_in=>phase_control_out,
--rst_i=>clockpath_reset,
--user_sel_i=>sel_phase_scanner_A,
--user_addr_i=>addr_phase_scanner_A,
--user_dat_i=>user_data_from_if_A,
--user_dat_o=>data_from_phase_scanner_A,
--user_wr_i=>user_wr_A,
--user_rd_i=>user_rd_A,
--SCAN_RESULT=>SCAN_RESULT_A,
--SCAN2_RESULT=>SCAN2_RESULT_A,
--SCAN3_RESULT=>SCAN3_RESULT_A,
--SCAN_VALID=>SCAN_VALID_A,
--SCAN_DONE=>SCAN_DONE_A,
--SERVO_VDD_INCR=>SERVO_VDD_INCR_A,
--SERVO_VDD_DECR=>SERVO_VDD_DECR_A,
--REFCLK_Q=>REFCLK_Q_A,
--debug_o=>scan_debug_A);
--
--u_phase_scanner_B : 	entity work.RITC_phase_scanner_v2 port map(
--CLK=>SYSCLK,
--CLK_PS=>SYSCLK_DIV2_PS,
--CLOCK_SCAN=>REFCLK_B_delay,
--CH0_SCAN=>RITC_DATA_B_bypass(0),
--CH1_SCAN=>RITC_DATA_B_bypass(1),
--CH2_SCAN=>RITC_DATA_B_bypass(2),
--VCDL_SCAN=>RITC_B_VCDL_SYNC,
----phase_control_clk=>phase_control_clock_B,
--phase_control_clk=>open, -- permanently connected to SYSCLK
--phase_control_out=>phase_control_in_B,
--phase_control_in=>phase_control_out,
--rst_i=>clockpath_reset,
--user_sel_i=>sel_phase_scanner_B,
--user_addr_i=>addr_phase_scanner_B,
--user_dat_i=>user_data_from_if_B,
--user_dat_o=>data_from_phase_scanner_B,
--user_wr_i=>user_wr_B,
--user_rd_i=>user_rd_B,
--SCAN_RESULT=>SCAN_RESULT_B,
--SCAN2_RESULT=>SCAN2_RESULT_B,
--SCAN3_RESULT=>SCAN3_RESULT_B,
--SCAN_VALID=>SCAN_VALID_B,
--SCAN_DONE=>SCAN_DONE_B,
--SERVO_VDD_INCR=>SERVO_VDD_INCR_B,
--SERVO_VDD_DECR=>SERVO_VDD_DECR_B,
--REFCLK_Q=>REFCLK_Q_B,
--debug_o=>scan_debug_B);


phase_control_in_A <= phase_control_in;
phase_control_in_B <= phase_control_in;
data_from_phase_scanner_A <= data_from_phase_scanner;
data_from_phase_scanner_B <= data_from_phase_scanner;



u_phase_scanner_A_B : 	entity work.RITC_dual_phase_scanner port map(
CLK=>SYSCLK,
CLK_PS=>SYSCLK_DIV2_PS,
CLOCK_SCAN_R0=>REFCLK_A_delay,
CLOCK_SCAN_R1=>REFCLK_B_delay,
CH0_SCAN_R0=>RITC_DATA_A_bypass(0),
CH1_SCAN_R0=>RITC_DATA_A_bypass(1),
CH2_SCAN_R0=>RITC_DATA_A_bypass(2),
CH0_SCAN_R1=>RITC_DATA_B_bypass(0),
CH1_SCAN_R1=>RITC_DATA_B_bypass(1),
CH2_SCAN_R1=>RITC_DATA_B_bypass(2),
VCDL_SCAN_R0=>RITC_A_VCDL_SYNC,
VCDL_SCAN_R1=>RITC_B_VCDL_SYNC,

phase_control_clk=>phase_control_clock, 
phase_control_out=>phase_control_in, --? only one or to both?
phase_control_in=>phase_control_out,
rst_i=>clockpath_reset,
user_sel_i=>sel_phase_scanner, -- use a single sel_phase_scanner?
user_addr_i=>addr_phase_scanner,
user_dat_i=>user_data_from_if, 
user_dat_o=>data_from_phase_scanner,
user_wr_i=>user_wr,
user_rd_i=>user_rd,

SCAN_RESULT_R0=>SCAN_RESULT_A,
SCAN2_RESULT_R0=>SCAN2_RESULT_A,
SCAN3_RESULT_R0=>SCAN3_RESULT_A,

SCAN_RESULT_R1=>SCAN_RESULT_B,
SCAN2_RESULT_R1=>SCAN2_RESULT_B,
SCAN3_RESULT_R1=>SCAN3_RESULT_B,

SCAN_VALID=>SCAN_VALID,
SCAN_DONE=>SCAN_DONE,
SERVO_VDD_INCR_R0=>SERVO_VDD_INCR_A,
SERVO_VDD_DECR_R0=>SERVO_VDD_DECR_A,
SERVO_VDD_INCR_R1=>SERVO_VDD_INCR_B,
SERVO_VDD_DECR_R1=>SERVO_VDD_DECR_B,
REFCLK_Q_R0=>REFCLK_Q_A,
REFCLK_Q_R1=>REFCLK_Q_B,
REFCLK_R0_to_BUFR => REFCLK_A_to_BUFR,
REFCLK_R1_to_BUFR => REFCLK_B_to_BUFR,
debug_o=>scan_debug);
	
 


--
--phase_control_A_notB <= user_address(5); -- using one new bit of the address to select twhich of the RITCs to use
--process(phase_control_in_A, phase_control_in_B, phase_control_A_notB)
--begin
--if phase_control_A_notB = '1' then
--	phase_control_in <= phase_control_in_A;
--else 
--	phase_control_in <= phase_control_in_B;
--end if;	
--end process;


u_ritc_dac_A : entity work.RITC_DAC_Simple generic map(CLOCK_DELAY => 1) 
port map(
CLK=>SYSCLK,
user_sel_i=>sel_ritc_dac_A,
user_addr_i=>addr_ritc_dac_A,
user_dat_i=>user_data_from_if_A,
user_dat_o=>data_from_ritc_dac_A,
user_wr_i=>user_wr_A,
user_rd_i=>user_rd_A,																 
DAC_DIN=>RITC_A_DAC_DIN,
DAC_DOUT=>RITC_A_DAC_DOUT,
DAC_CLOCK=>RITC_A_DAC_CLOCK,
DAC_LATCH=>RITC_A_DAC_LATCH,
VDD=>VDD_A,
VDD_INCR=>SERVO_VDD_INCR_A,
VDD_DECR=>SERVO_VDD_DECR_A);

R0_DAC_DIN<= RITC_A_DAC_DIN;
R0_DAC_LATCH <= RITC_A_DAC_LATCH;
R0_DAC_CLK <= RITC_A_DAC_CLOCK;
RITC_A_DAC_DOUT <= '0'; -- No feedback from RITC!!

u_ritc_dac_B : entity work.RITC_DAC_Simple generic map(CLOCK_DELAY => 1) 
port map(
CLK=>SYSCLK,
user_sel_i=>sel_ritc_dac_B,
user_addr_i=>addr_ritc_dac_B,
user_dat_i=>user_data_from_if_B,
user_dat_o=>data_from_ritc_dac_B,
user_wr_i=>user_wr_B,
user_rd_i=>user_rd_B,																 
DAC_DIN=>RITC_B_DAC_DIN,
DAC_DOUT=>RITC_B_DAC_DOUT,
DAC_CLOCK=>RITC_B_DAC_CLOCK,
DAC_LATCH=>RITC_B_DAC_LATCH,
VDD=>VDD_B,
VDD_INCR=>SERVO_VDD_INCR_B,
VDD_DECR=>SERVO_VDD_DECR_B);

R1_DAC_DIN<= RITC_B_DAC_DIN;
R1_DAC_LATCH <= RITC_B_DAC_LATCH;
R1_DAC_CLK <= RITC_B_DAC_CLOCK;
RITC_B_DAC_DOUT <= '0'; -- No feedback from RITC!!

--	always @(posedge SYSCLK) global_synchronizer <= ~global_synchronizer;
process(SYSCLK)
begin
if rising_edge(SYSCLK) then
	global_synchronizer <= not global_synchronizer;
end if;
end process;

u_ritc_control_A: 	entity work.RITC_Controller 
generic map(VCDL_IODELAY_GROUP=>"IODELAY_13",IDELAYE2LOC => "IDELAY_X0Y99") 
port map(
CLK=>SYSCLK,
CLK200=>CLK200,
user_sel_i=>sel_ritc_control_A,
user_addr_i=>addr_ritc_control_A,
user_dat_i=>user_data_from_if_A,
user_dat_o=>data_from_ritc_control_A,
user_wr_i=>user_wr_A,
user_rd_i=>user_rd_A,
CH0=>RITC_DATA_A_deserialize(0),
CH1=>RITC_DATA_A_deserialize(1),
CH2=>RITC_DATA_A_deserialize(2),
bitslip_o=>RITC_A_serdes_bitslip,
bitslip_addr_o=>RITC_A_serdes_bitslip_addr,
SYNC=>global_synchronizer,
REFCLK_to_BUFR=>REFCLK_A_to_BUFR,
VCDL_START=>RITC_A_VCDL_START,
VCDL_SYNC=>RITC_A_VCDL_SYNC,
vcdl_debug=>ritc_vcdl_debug_A,
COUNTER=>vcdl_counter_A,
REFCLK_Q=>REFCLK_Q_A,
TRAINING=>TRAINING_ON_A,
train_sync_o=>train_sync_A,
rst_o=>datapath_reset_A
);

R0_VCDL <= RITC_A_VCDL_START;
R0_TRAIN <= TRAINING_ON_A;

u_ritc_control_B: 	entity work.RITC_Controller
generic map(VCDL_IODELAY_GROUP => "IODELAY_34", IDELAYE2LOC => "IDELAY_X1Y134") 
port map(
CLK=>SYSCLK,
CLK200=>CLK200,
user_sel_i=>sel_ritc_control_B,
user_addr_i=>addr_ritc_control_B,
user_dat_i=>user_data_from_if_B,
user_dat_o=>data_from_ritc_control_B,
user_wr_i=>user_wr_B,
user_rd_i=>user_rd_B,
CH0=>RITC_DATA_B_deserialize(0),
CH1=>RITC_DATA_B_deserialize(1),
CH2=>RITC_DATA_B_deserialize(2),
bitslip_o=>RITC_B_serdes_bitslip,
bitslip_addr_o=>RITC_B_serdes_bitslip_addr,
SYNC=>global_synchronizer,
REFCLK_to_BUFR=>REFCLK_B_to_BUFR,
VCDL_START=>RITC_B_VCDL_START,
VCDL_SYNC=>RITC_B_VCDL_SYNC,
vcdl_debug=>ritc_vcdl_debug_B,
COUNTER=>vcdl_counter_B,
REFCLK_Q=>REFCLK_Q_B,
TRAINING=>TRAINING_ON_B,
train_sync_o=>train_sync_B,
rst_o=>datapath_reset_B
);

R1_VCDL <= RITC_B_VCDL_START;
R1_TRAIN <= TRAINING_ON_B;

--Change this with another memory based interface
--	qnd_uart_interface #(.CLOCK(162500000),.BAUD(921600)) 
--					u_uart_if(.CLK(SYSCLK),
--								 .TX(UART_TX),
--								 .RX(UART_RX),
--								 .user_address_o(user_address),
--								 .user_data_i(user_data_to_if),
--								 .user_data_o(user_data_from_if),
--								 .user_rd_o(user_rd),
--								 .user_wr_o(user_wr));

 
top_glitc_A_u: entity work.top_glitc_mod_with_square port map(
clk=>SYSCLK,
A=>RITC_DATA_A_deserialize(0), --LM added "power" outputs with the sum of squares
B=>RITC_DATA_A_deserialize(1),
C=>RITC_DATA_A_deserialize(2),
sum_max=>sum_max_A,
pos_sum_max=>pos_sum_max_A,
zero_delay=>zero_delay_A,
map_18_delay=>map_18_delay_A,
A_18=>A_18_A,
B_18=>B_18_A,
C_18=>C_18_A,
A_45=>A_45_A,
B_45=>B_45_A,
C_45=>C_45_A,
powerA=>powerA_A, 
powerB=>powerB_A, 
powerC=>powerC_A, 
sumA=>sumA_A,
sumB=>sumB_A,
sumC=>sumC_A,
new_power_flag=>new_power_flag_A,
acc_cnt_debug=>acc_cnt_debug_A										  
);
	  
top_glitc_B_u: entity work.top_glitc_mod_with_square port map(
clk=>SYSCLK,
A=>RITC_DATA_B_deserialize(0), --LM added "power" outputs with the sum of squares
B=>RITC_DATA_B_deserialize(1),
C=>RITC_DATA_B_deserialize(2),
sum_max=>sum_max_B,
pos_sum_max=>pos_sum_max_B,
zero_delay=>zero_delay_B,
map_18_delay=>map_18_delay_B,
A_18=>A_18_B,
B_18=>B_18_B,
C_18=>C_18_B,
A_45=>A_45_B,
B_45=>B_45_B,
C_45=>C_45_B,
powerA=>powerA_B, 
powerB=>powerB_B, 
powerC=>powerC_B,
sumA=>sumA_B,
sumB=>sumB_B,
sumC=>sumC_B,
new_power_flag=>new_power_flag_B,
acc_cnt_debug=>acc_cnt_debug_B										  
);



	 sel_phase_scanner <=   user_address(3);
	 addr_phase_scanner <= user_address(2 downto 0);

	-- Address decoders - use user_address(5) to select between the 2 RITCs 0->A, 1->B
	 sel_phase_scanner_A <= (not user_address(5)) and user_address(3);
	 addr_phase_scanner_A <= user_address(2 downto 0);
	 sel_ritc_dac_A <= (not user_address(5)) and (not user_address(3)) and user_address(2);-- 2'b01
	 addr_ritc_dac_A <= user_address(1 downto 0);
	 sel_ritc_control_A <= (not user_address(5)) and user_address(4) and (not user_address(3)) and (not user_address(2)); --2'b00
	 addr_ritc_control_A <= user_address(1 downto 0);
	 sel_delay_control_A <= (not user_address(5)) and not user_address(4) and (not user_address(3)) and (not user_address(2)); --2'b00;
	 addr_delay_control_A <=  user_address(0);

	 sel_phase_scanner_B <= (user_address(5)) and user_address(3);
	 addr_phase_scanner_B <=  user_address(2 downto 0);
	 sel_ritc_dac_B <= (user_address(5)) and (not user_address(3)) and user_address(2);-- 2'b01
	 addr_ritc_dac_B <=  user_address(1 downto 0);
	 sel_ritc_control_B <= (user_address(5)) and user_address(4) and (not user_address(3)) and (not user_address(2)); --2'b00
	 addr_ritc_control_B <=  user_address(1 downto 0);
	 sel_delay_control_B <= (user_address(5)) and not user_address(4) and (not user_address(3)) and (not user_address(2)); --2'b00;
	 addr_delay_control_B <=  user_address(0);
	 



process(SYSCLK)
begin
if rising_edge(SYSCLK) then
	if sel_phase_scanner_A = '1' then
		user_data_to_if <= data_from_phase_scanner_A;
	elsif sel_phase_scanner_B = '1' then
		user_data_to_if <= data_from_phase_scanner_B;
	elsif sel_ritc_dac_A = '1' then
		user_data_to_if <= data_from_ritc_dac_A;
	elsif sel_ritc_dac_B = '1' then
		user_data_to_if <= data_from_ritc_dac_B;
	elsif sel_ritc_control_A = '1' then
		user_data_to_if <= data_from_ritc_control_A;
	elsif sel_ritc_control_B = '1' then
		user_data_to_if <= data_from_ritc_control_B;
	elsif user_address(5) = '0' then
		user_data_to_if <= data_from_delay_control_A;
	else
		user_data_to_if <= data_from_delay_control_B;
	end if;
end if;
end process;



I2C_generic_u: I2C_generic
port map(
CLK => SYSCLK,
address => I2C_address,
command => I2C_command,
byte1 => I2C_byte1,
byte2 => I2C_byte2,
length_flag =>  I2C_length_flag, -- only 2 commands - with one or 2 value bytes
transmit => I2C_transmit,
ready => I2C_ready,
SCL => GA_SCL,
SDA => GA_SDA
);


phi_down_out <= pos_sum_max_A(5 downto 2) & sum_max_A;
phi_up_out <= pos_sum_max_B(5 downto 2) & sum_max_B;
sum_max_down <= phi_down_in(11 downto 0);
sum_max_up <= phi_up_in(11 downto 0);

pos_sum_max_down <= phi_down_in(15 downto 12) & "00";
pos_sum_max_up <= phi_up_in(15 downto 12) & "00";

TISC_TISC_comm_u: TISC_TISC_comm 
port map(
CLK => SYSCLK, 
PARALLEL_CLK => SYSCLK,
SERIAL_CLK => SYSCLKX2,

phi_down_out => phi_down_out,
PHI_DOWN_OUT_CLK_P => PHI_DOWN_OUT_CLK_P,
PHI_DOWN_OUT_CLK_N => PHI_DOWN_OUT_CLK_N,
PHI_DOWN_OUT_P => PHI_DOWN_OUT_P,
PHI_DOWN_OUT_N => PHI_DOWN_OUT_N,

phi_up_out => phi_up_out,
PHI_UP_OUT_CLK_P => PHI_UP_OUT_CLK_P,
PHI_UP_OUT_CLK_N => PHI_UP_OUT_CLK_N,
PHI_UP_OUT_P => PHI_UP_OUT_P,
PHI_UP_OUT_N => PHI_UP_OUT_N,

phi_down_in => phi_down_in,
PHI_DOWN_IN_CLK_P =>  PHI_DOWN_IN_CLK_P,
PHI_DOWN_IN_CLK_N => PHI_DOWN_IN_CLK_N,
PHI_DOWN_IN_P=> PHI_DOWN_IN_P,
PHI_DOWN_IN_N => PHI_DOWN_IN_N,

phi_up_in => phi_up_in,
PHI_UP_IN_CLK_P =>  PHI_UP_IN_CLK_P,
PHI_UP_IN_CLK_N => PHI_UP_IN_CLK_N,
PHI_UP_IN_P => PHI_UP_IN_P,
PHI_UP_IN_N => PHI_UP_IN_N
);

end Behavioral;

