library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--code goes here

entity dataProc is
	port(
	CLK: in std_logic;
	reset: in std_logic;
	--Ports between cmdProc and dataProc
	START: in std_logic;
	numWords: in std_logic_vector(11 downto 0);
	dataReady: out std_logic;
	byte: out std_logic_vector(7 downto 0);
	maxIndex: out std_logic_vector(11 downto 0);
	dataResults: out std_logic_vector(55 downto 0);
	seqDone: out std_logic;
	--Ports between Data Generator and the Data Processor
	ctrl_1: out std_logic;
	ctrl_2: in std_logic;
	dataIn: in std_logic_vector(7 downto 0)
 );
end;


--####### Architecture between command processor and data processor #######--
architecture dataProc_cmdProc of dataProc is
	type state_type is (s0, s1, s2, s3, s4); --States go here
	type array_type is array(0 to 998) of std_logic_vector(7 downto 0);
	--Signals
	signal curState, nextState: state_type;
	signal numWordsReg: std_logic_vector(11 downto 0);
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer;
	signal dataReg: std_logic_vector(7 downto 0); -- Store the bytes received
	signal beginRequest, endRequest: std_logic; --Tell the processor to stop and start requesting data from the generator
	signal totalIndex : integer; --Index for every byte recieved
	signal eighBitIndex : integer; -- Intdex to record every byte (8 bits)
	signal totalDataArray : array_type; --Stores every byte recived
	signal rollingPeakBin : signed(7 downto 0); --Peak byte in binary
	signal currentByteValue : signed(7 downto 0) --Current byte in binary
	signal peakIndex : integer; --Index of peak byte


begin

	state_reg: process(clk, reset)
	begin
		if reset ='1' then --if reset goes high, go back to the inital state
			curState <= s0;
		elsif clk 'event and clk ='1' then --Rising clock edge
			curState <= nextState;
		end if;
	end process;

	state_order: process(curState)
	begin
		case curState is -- dummy states
		when s0 => -- Waiting for the start signal
			if Start = '1' then
				nextState <= s1;
			end if;--signal rollingPeakDxpression thenec: signed(255 downto 0);
--signal rollingPeakDxpression thenec: signed(255 downto 0);
		when s1 => -- Requesting data from the generator
			if endRequest = '1' then
				nextState <= s2;
			end if;
		when s2 => -- State for outputing seqDone
		when s3 => -- State for outputing dataReady

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

	end process;


	register_numWords:process(start, clk) -- Registers the data from numWords when Start = 1
	begin
		if clk'event and clk ='1' then
			if start = '1' then
				numWordsReg <= numWords;
			end if;
		end if;
	end process;

	convert_numWords:process(numWordsReg) --A process to convert numWords to a readable number to get number of bytes
	begin
		integerPosistion1 <= to_integer(unsigned(numWordsReg(11 downto 8)));
		integerPosistion2 <= to_integer(unsigned(numWordsReg(7 downto 4)));
		integerPosistion3 <= to_integer(unsigned(numWordsReg(3 downto 0)));
		totalSum <= (integerPosistion1 + (integerPosistion2*10) + (integerPosistion3*100));
	end process;


	request_data:process(CLK)
	variable counter: integer;
	begin
		counter:=0;
		if beginRequest = '1' then
			if clk'event and clk ='1' then
				ctrl_1 <= '1';
				counter := counter + 1;
			elsif clk'event and clk = '0' then
				ctrl_1 <= '0';
				counter := counter + 1;
			end if;
			if counter = totalSum then
				endRequest <= '0';
			end if;
		end if;
	end process;

	register_data: process(ctrl_2)
	begin
		if ctrl_2'event then
			dataReg <= dataIn;

		end if;
	end process;



	global_data_array: process(clk,transmistting) --Transmitting is a signal that shows when data is being sent from data gen
	begin
		if rising_edge(clk) AND "transmitting" = 1 then
			totalDataArray(totalIndex) <= dataReg;
		end if;
	end process; --end data array


	--detector actually starts comparing values
	detector: process(clk,totalDataArray,totalIndex)
	begin
		if rising_edge(clk) then
			if totalIndex /= '0' then
				if currentByteValue = rollingPeakBin then
					--do a thing
				if currentByteValue > rollingPeakBin then
					--do another thing
				if currentByteValue < rollingPeakBin then
					--do this thing
				end if; --comparison if
			end if;
	end process; --end detector

	--Counters
	counter: process(clk,reset)
	begin
	if reset = '1';
		totalIndex <= '0';
		eighBitIndex <= '0'
	elsif rising_edge(clk) AND<= totalDataArray(peakIndex - '3') dataReg'event then
		totalIndex <= totalIndex +1; --increment global data index when data is detected.
	elsif rising_edge(clk) AND dataReg'event AND (totalIndex mod(8)) = '0' then
		eighBitIndex <= eighBitIndex +1; --increment byte index when 8 bits are detected.
	end if;
	end process; --end counters

	--Collects six results and the peak byte.
	requested_results: process(clk)
	begin
	if rising_edge(clk) then
		dataResults(7 downto 0) <= totalDataArray(peakIndex - '3'); --fix data array stores bits not bytes
		dataResults(15 downto 7) <= totalDataArray(peakIndex - '2'); --these vector ranges are not quite correct
		dataResults(23 downto 15) <= totalDataArray(peakIndex - '1');
		dataResults(31 downto 23) <= totalDataArray(peakIndex);
		dataResults(39 downto 31) <= totalDataArray(peakIndex + '3');
		dataResults(47 downto 39) <= totalDataArray(peakIndex + '3');
		dataResults(56 downto 47) <= totalDataArray(peakIndex + '3');
	end if;
	end process; -- end requested_results


end;
