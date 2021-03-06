--
-------------------------------------------------------------------------------------------
-- Copyright � 2010-2013, Xilinx, Inc.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-------------------------------------------------------------------------------------------
--
-- Disclaimer:
-- This disclaimer is not a license and does not grant any rights to the materials
-- distributed herewith. Except as otherwise provided in a valid license issued to
-- you by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE
-- MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY
-- DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY,
-- INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT,
-- OR FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable
-- (whether in contract or tort, including negligence, or under any other theory
-- of liability) for any loss or damage of any kind or nature related to, arising
-- under or in connection with these materials, including for any direct, or any
-- indirect, special, incidental, or consequential loss or damage (including loss
-- of data, profits, goodwill, or any type of loss or damage suffered as a result
-- of any action brought by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-safe, or for use in any
-- application requiring fail-safe performance, such as life-support or safety
-- devices or systems, Class III medical devices, nuclear facilities, applications
-- related to the deployment of airbags, or any other applications that could lead
-- to death, personal injury, or severe property or environmental damage
-- (individually and collectively, "Critical Applications"). Customer assumes the
-- sole risk and liability of any use of Xilinx products in Critical Applications,
-- subject only to applicable laws and regulations governing limitations on product
-- liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
--
-------------------------------------------------------------------------------------------
--
--
-- Production definition of a 1K program for KCPSM6 in a 7-Series device using a 
-- RAMB18E1 primitive.
--
-- Note: The complete 12-bit address bus is connected to KCPSM6 to facilitate future code 
--       expansion with minimum changes being required to the hardware description. 
--       Only the lower 10-bits of the address are actually used for the 1K address range
--       000 to 3FF hex.  
--
-- Program defined by 'C:\cygwin\home\barawn\repositories\github\firmware-glitc\src\glitc_external_settings_rom.psm'.
--
-- Generated by KCPSM6 Assembler: 01 Jun 2015 - 17:19:13. 
--
-- Assembler used ROM_form template: ROM_form_7S_1K_14March13.vhd
--
--
-- Standard IEEE libraries
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
-- The Unisim Library is used to define Xilinx primitives. It is also used during
-- simulation. The source can be viewed at %XILINX%\vhdl\src\unisims\unisim_VCOMP.vhd
--  
library unisim;
use unisim.vcomponents.all;
--
--
entity glitc_external_settings_rom is
    Port (      address : in std_logic_vector(11 downto 0);
            instruction : out std_logic_vector(17 downto 0);
                 enable : in std_logic;
                    clk : in std_logic;
		    bram_adr_i : in std_logic_vector(9 downto 0);
		    bram_dat_o : out std_logic_vector(17 downto 0);
		    bram_dat_i : in std_logic_vector(17 downto 0);
		    bram_we_i : in std_logic;
		    bram_rd_i : in std_logic;
		    bram_ack_o : out std_logic);
    end glitc_external_settings_rom;
--
architecture low_level_definition of glitc_external_settings_rom is
--
signal  address_a : std_logic_vector(13 downto 0);
signal  data_in_a : std_logic_vector(17 downto 0);
signal data_out_a : std_logic_vector(17 downto 0);
signal  address_b : std_logic_vector(13 downto 0);
signal  data_in_b : std_logic_vector(17 downto 0);
signal data_out_b : std_logic_vector(17 downto 0);
signal   enable_b : std_logic;
signal      clk_b : std_logic;
signal       we_b : std_logic_vector(3 downto 0);
signal	     ack  : std_logic;
--
begin
--
  address_a <= address(9 downto 0) & "1111";
  instruction <= data_out_a(17 downto 0);
  data_in_a <= "0000000000000000" & address(11 downto 10);
  --
  address_b <= bram_adr_i & "1111";
  data_in_b <= bram_dat_i(17 downto 0);
  bram_dat_o <= data_out_b;
  enable_b <= bram_we_i or bram_rd_i;
  we_b <= "00" & bram_we_i & bram_we_i;
  clk_b <= clk;
  bram_ack_o <= ack;
  ack_process : process (clk)
  begin
	if (rising_edge(clk)) then
	   ack <= bram_we_i or bram_rd_i;
	end if;
  end process;
  --
  --
  -- 
  kcpsm6_rom: RAMB18E1
  generic map ( READ_WIDTH_A => 18,
                WRITE_WIDTH_A => 18,
                DOA_REG => 0,
                INIT_A => "000000000000000000",
                RSTREG_PRIORITY_A => "REGCE",
                SRVAL_A => X"000000000000000000",
                WRITE_MODE_A => "WRITE_FIRST",
                READ_WIDTH_B => 18,
                WRITE_WIDTH_B => 18,
                DOB_REG => 0,
                INIT_B => X"000000000000000000",
                RSTREG_PRIORITY_B => "REGCE",
                SRVAL_B => X"000000000000000000",
                WRITE_MODE_B => "WRITE_FIRST",
                INIT_FILE => "NONE",
                SIM_COLLISION_CHECK => "ALL",
                RAM_MODE => "TDP",
                RDADDR_COLLISION_HWCONFIG => "DELAYED_WRITE",
                SIM_DEVICE => "7SERIES",
                INIT_00 => X"6007D0082004D004600ED101B118900000ED00F9F0181000D00010801F001E00",
                INIT_01 => X"030020070188100560D2D03860B7D0079002606BD0F0601FD00F90012007D001",
                INIT_02 => X"EA909A1018011901EA903A0F9A1118011901EA901A402034D3011900180010C2",
                INIT_03 => X"9A1218011901EA903A0F9A1318011901EA901A422045D302DA011A0118011901",
                INIT_04 => X"18011901EA903A0F9A1518011901EA901A442056D304DA011A0218011901EA90",
                INIT_05 => X"1901EA903A0F9A1718011901EA901A462067D308DA011A0418011901EA909A14",
                INIT_06 => X"D3101900180010C003002007015212000180DA011A0818011901EA909A161801",
                INIT_07 => X"DA011A1018011901EA909A1818011901EA903A0F9A1918011901EA901A402080",
                INIT_08 => X"1A2018011901EA909A1A18011901EA903A0F9A1B18011901EA901A422091D320",
                INIT_09 => X"18011901EA909A1C18011901EA903A0F9A1D18011901EA901A4420A2D340DA01",
                INIT_0A => X"1901EA909A1E18011901EA903A0F9A1F18011901EA901A4620B3D380DA011A40",
                INIT_0B => X"4A08490E1A00391F9921381F9820F80018022007015212000180DA011A801801",
                INIT_0C => X"1040D00212001103F902F801598009A04A064A069A2208A04A08490E4A08490E",
                INIT_0D => X"08A04A08490E4A08490E4A08490E1A00391F9924381F9823F800180220070152",
                INIT_0E => X"5000D0029000200701521042D00212001103F902F801598009A04A064A069A25",
                INIT_0F => X"100FD082100060F9D002908411005000D0001002D0033EF71E01A0E01000CFE0",
                INIT_10 => X"01881002211101901042110101881001210B01901040D0821080D0811000D080",
                INIT_11 => X"2123013B1040110101881004211D019010C01101018810032117019010C21101",
                INIT_12 => X"10C0110101881003212F014B10C21101018810022129013B1042110101881001",
                INIT_13 => X"18FFF8001802120011035000D0001004F1181000D1011101018810042135014B",
                INIT_14 => X"F201F80018C01200110250000152F202F201F8001806110350000152F802F801",
                INIT_15 => X"D8841810D883A89019006183D8800199D8841890D0832169D100019950000152",
                INIT_16 => X"D8841890D883180108002182D200019DD8841840615C910119016183D8800199",
                INIT_17 => X"18406174D2001901E89098830199D884182861789201182019006183D8800199",
                INIT_18 => X"50000F80E0F01000C8E0380F180108F050004807019DD88418405000019DD884",
                INIT_19 => X"1000D840988421991000D80298845000D880019DD08410400199D0841090D083",
                INIT_1A => X"000000000000000000000000000000000000000000000000000000000000219D",
                INIT_1B => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_1C => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_1D => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_1E => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_1F => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_20 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_21 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_22 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_23 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_24 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_25 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_26 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_27 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_28 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_29 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2A => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2B => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2C => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2D => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2E => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_2F => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_30 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_31 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_32 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_33 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_34 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_35 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_36 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_37 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_38 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_39 => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3A => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3B => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3C => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3D => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3E => X"0000000000000000000000000000000000000000000000000000000000000000",
                INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000",
               INITP_00 => X"85858163002821616058C8585816321616058C858581630028CC330CCCD0A880",
               INITP_01 => X"2302884DC28828545554008A20A1515550022821616058C8585816321616058C",
               INITP_02 => X"358A343289368D7288328B6AA02AA0EA2028B08E08E08E08E08E08E08E08E222",
               INITP_03 => X"000000000000000000000000000000000000000000000002C2C228A28B449A2A",
               INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
               INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
               INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
               INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000")
  port map(   ADDRARDADDR => address_a,
                  ENARDEN => enable,
                CLKARDCLK => clk,
                    DOADO => data_out_a(15 downto 0),
                  DOPADOP => data_out_a(17 downto 16), 
                    DIADI => data_in_a(15 downto 0),
                  DIPADIP => data_in_a(17 downto 16), 
                      WEA => "00",
              REGCEAREGCE => '0',
            RSTRAMARSTRAM => '0',
            RSTREGARSTREG => '0',
              ADDRBWRADDR => address_b,
                  ENBWREN => enable_b,
                CLKBWRCLK => clk_b,
                    DOBDO => data_out_b(15 downto 0),
                  DOPBDOP => data_out_b(17 downto 16), 
                    DIBDI => data_in_b(15 downto 0),
                  DIPBDIP => data_in_b(17 downto 16), 
                    WEBWE => we_b,
                   REGCEB => '0',
                  RSTRAMB => '0',
                  RSTREGB => '0');
--
--
end low_level_definition;
--
------------------------------------------------------------------------------------
--
-- END OF FILE glitc_external_settings_rom.vhd
--
------------------------------------------------------------------------------------
