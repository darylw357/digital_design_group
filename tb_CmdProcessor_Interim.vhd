----------------------------------------------------------------------------
--	tb_CmdProcessor_Interim.vhd -- A testbench that simulates the command processor 
--  (interim submission)
----------------------------------------------------------------------------
-- Author:  Dinesh Pamunuwa, Tian "Tyson" Qin
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- README:
--
-- This testbench instantiates all the components, including the Command
-- Processor you design and the blackbox of Data Processor. Note that this 
-- testbench is not aimed for synthesis, and some coding style you see is only
-- acceptable in a testbench. You should always follow the strict template for
-- a synthesizable design (RTL). 
--
-- To run simulation successfully, besides this testbench, the following
-- source files also need to be included in your Modelsim Project:
-- 
-- 
-- cmdProc.vhd :        the command processor that your need to design;
-- dataConsume_synthesis.vhd: The Xilinx synthesised versions of the Data Processor 
--                            (a pure structural implementation);
-- dataConsume_wrapper.vhd:   A wrapper defines some conversion functions and instantiates the synthesised version as a component; 
--                            Effectively, this file and the file above work together as a blackbox for Data Processor
--                            (how Data Processor interprete data is unimportant for interim command processor design);
-- UART_RX_CTRL.vhd:    The source for the UART receiver;
-- UART_TX_CTRL.vhd:    The source for the UART transmitter;
-- datGen.vhd :         Data Generator;
-- common_pack.vhd :    A repostory where global constants, frequently used data types as well as 
--                      the data sequence used by the data generatorand are defined. 
----------------------------------------------------------------------------
-- Version:			1.1
-- Revision History:
-- 02/02/2016 (Tyson):  Modified to fit the intermim cmdProc design
-- 09/02/2014 (Dinesh): Created using Modelsim
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;


entity tb_cmdProc_interim is 
end;

architecture testbench of tb_cmdProc_interim is 

  component UART_TX_CTRL is
    port ( 
      SEND : in  STD_LOGIC;
      DATA : in  STD_LOGIC_VECTOR (7 downto 0);
      CLK : in  STD_LOGIC;
      READY : out  STD_LOGIC;
      UART_TX : out  STD_LOGIC
    );
  end component;  
  
  component UART_RX_CTRL is
    port(
      RxD: in std_logic;                -- serial data in
      sysclk: in std_logic; 		-- system clock
      reset: in std_logic;		--	synchronous reset
      rxDone: in std_logic;		-- data succesfully read (active high)
      rcvDataReg: out std_logic_vector(7 downto 0); -- received data
      dataReady: out std_logic;	        -- data ready to be read
      setOE: out std_logic;		-- overrun error (active high)
      setFE: out std_logic		-- frame error (active high)
    );
  end component; 

  component dataGen is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: out std_logic_vector(7 downto 0)
    );
  end component;
  
  component dataConsume is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      start: in std_logic;
      numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: in std_logic_vector(7 downto 0);
      dataReady: out std_logic;
      byte: out std_logic_vector(7 downto 0);
      seqDone: out std_logic;
      maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
      dataResults: out CHAR_ARRAY_TYPE(0 to 6) 
    );
  end component;
  
  component cmdProc is
    port (
      clk:		in std_logic;
      reset:		in std_logic;
      rxnow:		in std_logic;
      rxData:			in std_logic_vector (7 downto 0);
      txData:			out std_logic_vector (7 downto 0);
      rxdone:		out std_logic;
      ovErr:		in std_logic;
      framErr:	in std_logic;
      txnow:		out std_logic;
      txdone:		in std_logic;
      start: out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
    );
  end component;
  
  signal clk: std_logic := '0';
  signal reset, sig_start, ctrl_genDriv, ctrl_consDriv, sig_dataReady, sig_seqDone: std_logic;
  signal sig_rxDone, sig_rxNow, sig_ovErr, sig_framErr, sig_txNow, sig_txDone: std_logic;
  signal sig_rx, sig_tx, sig_rx_debug: std_logic;
  
  signal sig_rxData, sig_txData, sig_byte: std_logic_vector(7 downto 0);
  signal sig_maxIndex: BCD_ARRAY_TYPE(2 downto 0);
  
  signal sig_dataResults: CHAR_ARRAY_TYPE(0 to 6);
  signal sig_numWords_bcd: BCD_ARRAY_TYPE(2 downto 0);
  
  signal sig_data: std_logic_vector(7 downto 0);
    
  constant SEQ_COUNT_MAX : integer := 1; -- defines how many runs to test
  
  type ARRAY3D_TYPE is array (0 to SEQ_COUNT_MAX) of CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
  type ARRAY3D_BCD_TYPE is array (0 to SEQ_COUNT_MAX) of BCD_ARRAY_TYPE(2 downto 0);
  type SEQUENCE_TYPE is array (integer range<> ) of CHAR_ARRAY_TYPE(1 to 2);
 
  constant sequence1 : SEQUENCE_TYPE(1 to 12) := (("00111001","00110101"),   --X"95"
                                                  ("00110001","00110011"),   --X"13"
                                                  ("00110110","00110000"),   --X"60"
                                                  ("00110000","00111001"),   --X"09"
                                                  ("00110110","00111000"),   --X"68"
                                                  ("01000001","00111000"),   --X"A8"
                                                  ("00111001","00110011"),   --X"93"
                                                  ("01000110","00111001"),   --X"F9"
                                                  ("00110111","00110001"),   --X"71"
                                                  ("01000011","00110111"),   --X"C7"
                                                  ("00111001","00110010"),   --X"92"
                                                  ("00110000","00110110")   --X"06"
                                                  );
   
    
                                    
  -- function to convert std_logic_vector having '1's and '0's to string
  -- used in assertion
  function vec2str(vec : std_logic_vector) return string is
    variable str : string(vec'LEFT+1 DOWNTO 1);
  begin
    for i in vec'REVERSE_RANGE loop
      if vec(i) = '1' then
        str(i+1) := '1';
      elsif vec(i) = '0' then
        str(i+1) := '0';
      else
        str(i+1) := 'X';
      end if;
    end loop;
    return str;
  end vec2str;
  
  
begin
  clk <= NOT clk after 5 ns when now <2000 ms else clk;
  reset <= '0', '1' after 2 ns, '0' after 15 ns, '0' after 3600 ns, '0' after 3615 ns;

  byteCounter: process (sig_start, sig_dataReady, sig_seqDone)  --this process checks that correct number of bytes are logged according to cmd
    variable seqCount: integer :=0;
    variable byteCount, bytetoProcess: integer := 0;
    variable v_numWords_bcd: BCD_ARRAY_TYPE(2 downto 0);
  begin
    if rising_edge (sig_start) and byteCount = 0 then
      seqCount := seqCount + 1;
      assert false report "=====Process of Sequence No." & INTEGER'IMAGE(seqCount) & " starts." severity note;
      v_numWords_bcd := sig_numWords_bcd;
      bytetoProcess := to_integer(unsigned(v_numWords_bcd(2)))* 100 + to_integer(unsigned(v_numWords_bcd(1)))* 10 + to_integer(unsigned(v_numWords_bcd(0)));
    end if;
    if rising_edge (sig_dataReady) then
      byteCount := byteCount + 1;
    end if;
    if rising_edge (sig_seqDone) then
      assert false report "=====Process of Sequence No." & INTEGER'IMAGE(seqCount) & " is done." severity note;
      
      report "=====A total of " & INTEGER'IMAGE(byteCount) & " bytes has been processed; " severity note;
      assert byteCount = bytetoProcess report "numWords_BCD = " & INTEGER'IMAGE(bytetoProcess) & " at the start of this sequence" severity warning;
      byteCount := 0;
      bytetoProcess := 0;
    end if;
  end process;
 
 
  checkByte: process   --this process checks whether the bytes in sequence 1 are correctly transmited through TX
                 --it is assumed that an delimiter (such as blank space) is in between two bytes when sent to PC
  begin
    wait for 10 ns;
    for i in 1 to 12 loop
      wait until sig_start = '1';
      for j in 1 to 3 loop
          wait until sig_txNow = '1';
          if j/=3 then
            assert sig_txData = sequence1(i)(j) 
            report "txData is " & vec2str(sig_txData)& "; while byte(" & INTEGER'IMAGE(i) & ") character(" & INTEGER'IMAGE(j) & ") should be " & vec2str(sequence1(i)(j)) severity error;
          end if;
      end loop;
    end loop;
    wait;
  end process;
  
  -----------------------------
  -- issue first read cmd a012
  -----------------------------
  -- a: 1, 0, 1000_0110, 1 (idle - 1, start bit - 0, a (0110_0001) in order of LSB first, stop bit -1)
  sig_rx <= '1', '0' after 1 us, '1' after 105 us, '0' after 209 us,  '0' after 313 us,  '0' after 417 us,  
  '0' after 521 us,  '1' after 625 us,  '1' after 729 us,  '0' after 833 us, '1' after 937 us, 
  -- 0: 0, 0000_1100, 1 (start bit - 0, decimal 0 (0011_0000) in order of LSB first, stop bit -1)
  '0' after 1200 us, '0' after 1304 us, '0' after 1408 us, '0' after 1512 us,  '0' after 1616 us,  
  '1' after 1720 us, '1' after 1824 us,  '0' after 1928 us,  '0' after 2032 us,  '1' after 2136 us, 
  -- 1: 0, 10001100, 1 (start bit - 0, decimal 0 (0011_0001) in order of LSB first, stop bit -1)
    '0' after 2500 us, '1' after 2604 us, '0' after 2708 us, '0' after 2812 us, '0' after 2916 us,
    '1' after 3020 us,  '1' after 3124 us,  '0' after 3228 us,  '0' after 3332 us,  '1' after 3436 us,  
  -- 2: 0, 0100_1100, 1 (start bit - 0, decimal 2 (0011_0010) in order of LSB first, stop bit -1)
  '0' after 3800 us, '0' after 3904 us, '1' after 4008 us, '0' after 4112 us, '0' after 4216 us, 
  '1' after 4320 us, '1' after 4424 us, '0' after 4528 us, '0' after 4632 us, '1' after 4736 us,
  -----------------------------
  -- issue second read cmd A013
  -----------------------------
  -- A: 1, 01000010, 1 (idle - 1, start bit - 0, A (0100_0001) in order of LSB first, stop bit -1)
  '1' after 132000 us, '0' after 132001 us, '1' after 132105 us, '0' after 132209 us,  '0' after 132313 us,  '0' after 132417 us,  
  '0' after 132521 us,  '0' after 132625 us,  '1' after 132729 us,  '0' after 132833 us, '1' after 132937 us, 
  -- 0: 0, 00001100, 1 (start bit - 0, decimal 0 (0011_0000) in order of LSB first, stop bit -1)
  '0' after 133200 us, '0' after 133304 us, '0' after 133408 us, '0' after 133512 us,  '0' after 133616 us,  
  '1' after 133720 us, '1' after 133824 us,  '0' after 133928 us,  '0' after 134032 us,  '1' after 134136 us, 
  -- 1: 0, 10001100, 1 (start bit - 0, decimal 0 (0011_0001) in order of LSB first, stop bit -1)
  '0' after 134500 us, '1' after 134604 us, '0' after 134708 us, '0' after 134812 us, '0' after 134916 us,
  '1' after 135020 us,  '1' after 135124 us,  '0' after 135228 us,  '0' after 135332 us,  '1' after 135436 us,  
  -- 3: 0, 11001100, 1 (start bit - 0, decimal 2 (0011_0011) in order of LSB first, stop bit -1)
  '0' after 135800 us, '1' after 135904 us, '1' after 136008 us, '0' after 136112 us, '0' after 136216 us, 
  '1' after 136320 us, '1' after 136424 us, '0' after 136528 us, '0' after 136632 us, '1' after 136736 us;
  ------------------------------
 


----------------------------------------
-- structural design starts from below
----------------------------------------  
  dataGen1: dataGen
    port map (
      clk => clk,
      reset => reset,
      ctrlIn => ctrl_consDriv,
      ctrlOut => ctrl_genDriv,
      data => sig_data
    );
    
  dataConsume1: dataConsume
    port map (
      clk => clk,
      reset => reset,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      ctrlIn => ctrl_genDriv,
      ctrlOut => ctrl_consDriv,
      dataReady => sig_dataReady,
      byte => sig_byte,
      data => sig_data,
      seqDone => sig_seqDone,
      maxIndex => sig_maxIndex,
      dataResults => sig_dataResults
    );
    
  cmdProc1: cmdProc
    port map (
      clk => clk,
      reset => reset,
      rxNow => sig_rxNow,
      rxData => sig_rxData,
      txData => sig_txData,
      rxDone => sig_rxDone,
      ovErr => sig_ovErr,
      framErr => sig_framErr,
      txNow => sig_txNow,
      txDone => sig_txDone,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      dataReady => sig_dataReady,
      byte => sig_byte,
      maxIndex => sig_maxIndex,
      seqDone => sig_seqDone,
      dataResults => sig_dataResults
    );
    	
  tx: UART_TX_CTRL
    port map (
      SEND => sig_txNow,
      DATA => sig_txData,
      CLK => clk,
      READY => sig_txDone,
      UART_TX => sig_tx
    );    	
  	
  rx : UART_RX_CTRL
   port map(
     RxD => sig_rx, -- input serial line
     sysclk => clk,
     reset => reset, 
     rxDone => sig_rxdone,
     rcvDataReg => sig_rxData,
     dataReady => sig_rxNow,
     setOE => sig_ovErr,
     setFE =>  sig_framerr
   );   	
  	
 end testbench;

