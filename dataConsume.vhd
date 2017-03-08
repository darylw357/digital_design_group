library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;

--code goes here

entity dataConsume is
	port(
		clk:in std_logic;
		reset: in std_logic; -- synchronous reset
		start: in std_logic; -- goes high to signal data transfer
		numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn: in std_logic;
		ctrlOut: out std_logic;
		data: in std_logic_vector(7 downto 0);
		dataReady: out std_logic;
		byte: out std_logic_vector(7 downto 0);
		seqDone: out std_logic;
		maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
		dataResults: out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
	);
end;


--####### Architecture between command processor and data processor #######--
architecture dataConsume_Arch of dataConsume is
	type state_type is (s0, s1, s2, s3, s4); --States go here
	--type array_type is array(0 to 998) of std_logic_vector(7 downto 0);
	--Signals
	signal curState, nextState: state_type;
	signal numWordsReg: BCD_ARRAY_TYPE(2 downto 0);
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer; -- Integers involved in numWords
	signal dataReg: std_logic_vector(7 downto 0) := "00000000"; -- Store the bytes received
	signal beginRequest, endRequest: std_logic; --Tell the processor to stop and start requesting data from the generator
	signal totalIndex : integer; --Index for every byte recieved
	signal eighBitIndex : integer; -- Intdex to record every byte (8 bits)
	signal totalDataArray : CHAR_ARRAY_TYPE(0 to 998); --Stores every byte recived
	signal rollingPeakBin : signed(7 downto 0); --Peak byte in binary
	signal currentByteValue : signed(7 downto 0); --Current byte in binary
	signal peakIndex: integer; --Index of peak byte
	signal ctrl_2Delayed, ctrl_2Detection: std_logic; --Ctrl_2 detection signals
	signal resultsValid: std_logic;

begin

	state_reg: process(clk, reset)
	begin
		if reset ='1' then --if reset goes high, go back to the inital state
			curState <= s0;
		elsif clk 'event and clk ='1' then --Rising clock edge
			curState <= nextState;
		end if;
	end process;

	state_order: process(clk,curState)
	begin
		case curState is -- dummy states
		when s0 => -- Waiting for the start signal
			if start = '1' then
				nextState <= s1;
			end if;
		when s1 => -- Requesting data from the generator
			if endRequest = '1' then
				nextState <= s2;
			end if;
		when s2 =>

		when s3 =>

		when s4 =>
		when others =>
		end case;
	end process;


	combinational_output:process(curState)
	begin
		dataReady <= '0';
		seqDone <= '0';
		beginRequest <= '0';
		if curState = s1 then
			beginRequest <= '1';
		end if;
		if curState = s3 then
			resultsValid <= '1';
			seqDone <= '1';
		end if;



	end process;


	register_numWords:process(start, clk) -- Registers the data from numWords when Start = 1
	begin
		if rising_edge(clk) then
			if start = '1' then
				numWordsReg <= numWords_bcd;
			end if;
		end if;
	end process;



	convert_numWords:process(numWordsReg, reset) --A process to convert numWords to a readable number to get number of bytes
	begin
		if reset = '1' then
		  integerPosistion1 <=0;
		  integerPosistion2 <=0;
		  integerPosistion3 <=0;
		end if;
		integerPosistion1 <= to_integer(unsigned(numWordsReg(0)));
		integerPosistion2 <= to_integer(unsigned(numWordsReg(1)));
		integerPosistion3 <= to_integer(unsigned(numWordsReg(2)));
	end process;

	summing_numWords:process(integerPosistion1, integerPosistion2, integerPosistion3)
	begin
		if reset = '1' then
			totalSum <= 0;
		else
			totalSum <= (integerPosistion1 + (integerPosistion2*10) + (integerPosistion3*100));
		end if;
	end process;


	request_data:process(CLK, reset)
	variable counter: integer := 0;
	variable switching: std_logic := '0';
	begin
		if reset = '1' then
			counter := 0;
			switching := '0';
		end if;
		if beginRequest = '1' then
			if rising_edge(clk) then
				ctrlOut <= switching;
				counter := counter + 1;
				switching := not switching;
			end if;
			if counter = totalSum then
				endRequest <= '1';
			end if;
		end if;
	end process;

---------- Processes handling the handshaking protocol

	delay_ctrl_2:process(clk)
	begin
		if rising_edge(clk) then
			ctrl_2Delayed <= ctrlIn;
		end if;
	end process;

	register_data: process(clk)
	begin
		ctrl_2Detection <= ctrlIn xor ctrl_2Delayed;
		if ctrl_2Detection = '1' AND rising_edge(clk) then
			dataReg <= data;
		end if;
	end process;
----------------------------------------------------------


	global_data_array: process(clk,beginRequest) --Transmitting is a signal that shows when data is being sent from data gen
	variable n: integer:=0;
	begin
		if rising_edge(clk) AND beginRequest = '1' AND dataReg /= "00000000" then
			totalDataArray(n) <= dataReg;
			n := n + 1;
		end if;
	end process; --end data array


	--detector actually starts comparing values
	detector: process(clk,totalDataArray,totalIndex)
	begin
		if rising_edge(clk) then
			if totalIndex /= 0 then
				if currentByteValue = rollingPeakBin then
					--do a thing
				elsif currentByteValue > rollingPeakBin then
					--do another thing
				elsif currentByteValue < rollingPeakBin then
					--do this thing
				end if; --comparison if
			end if;
		end if;
	end process; --end detector

	--Counters
	counter: process(clk,reset,dataReg,totalIndex)
	begin
		if reset = '1' then
			totalIndex <= 0;
			eighBitIndex <= 0;
			peakIndex <= 0;
		elsif rising_edge(clk) AND dataReg'event then
			totalIndex <= totalIndex +1; --increment global data index when data is detected.
		elsif rising_edge(clk) AND dataReg'event AND (totalIndex mod(8)) = 0 then
			eighBitIndex <= eighBitIndex +1; --increment byte index when 8 bits are detected.
		end if;
	end process; --end counters

	--Collects six results and the peak byte.
	requested_results: process(clk, reset)
	begin
		if rising_edge(clk) and resultsValid = '1' then
			dataResults(0) <= totalDataArray(peakIndex - 3); --fix data array stores bits not bytes
			dataResults(1) <= totalDataArray(peakIndex - 2); --these vector ranges are not quite correct
			dataResults(2) <= totalDataArray(peakIndex - 1);
			dataResults(3) <= totalDataArray(peakIndex);
			dataResults(4) <= totalDataArray(peakIndex + 3);
			dataResults(5) <= totalDataArray(peakIndex + 3);
			dataResults(6) <= totalDataArray(peakIndex + 3);
		end if;
	end process; -- end requested_results


end;
