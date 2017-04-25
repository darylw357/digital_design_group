--dataConsume.vhd

--The Data Processor
--By Alexander Hamilton & Daryl White
-----------------------------------------------------------

--Packages
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;

entity dataConsume is
	port(
		clk:in std_logic;
		reset: in std_logic; 
		start: in std_logic; 
		numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn: in std_logic;
		ctrlOut: out std_logic;
		data: in std_logic_vector(7 downto 0);
		dataReady: out std_logic;
		byte: out std_logic_vector(7 downto 0);
		seqDone: out std_logic;
		maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
		dataResults: out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) 
		);
end;



-------------------- Architecture  ---------------------------
architecture dataConsume_Arch of dataConsume is
	type state_type is (init, dataRequest, sendBytes, assignPeak, sendPeak, checkPeak, finalByte); --States go here
	--Signals
	signal curState, nextState: state_type; -- Used for state machine control
	signal numWordsReg: BCD_ARRAY_TYPE(2 downto 0); --Stores numWords in a register
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer; -- Integers involved in the summing of numWord
	signal N: integer := 0; --A counter for the number of bytes that has been receieved
	signal resetCounter: std_logic; -- A synchronous reset signal that resets counters and the peak byte
	signal beginRequest, endRequest: std_logic; --Tells the processor to stop and start requesting data from the generator
	signal rollingPeakBin : signed(7 downto 0) := "10000000"; --Peak byte in signed binary
	signal peakIndex: integer := 0; --Index of peak byte in integer form
	signal ctrl_2Delayed, ctrl_2Detection: std_logic; --Ctrl_2 detection signals (ctrl_2 is now ctrlIn)
	signal resultsValid: std_logic; --When the array has the correct number of bytes in it
	signal dataArrived: std_logic; -- Checks that data has started to be allocated into the global array
	signal conversionComplete: std_logic; --Checks that peakIndex has been converted into a bcd format
	signal toggle: std_logic; -- Used for toggling ctrlOut between 1 and 0
	signal countEn: std_logic; --Enables the count for number of switches
	signal countInt: integer := 0; --Counts the number of switches (requests)
	signal count100, count10, count1: unsigned(3 downto 0); -- For converting integer into bcd
	signal flag100,flag10,flag1: std_logic; --Checks for the conversion of integers into bcd
	signal shiftRegister: char_array_type(0 to 6); --A shift register to store incoming bytes
	signal peakCounter: integer := 0; --Checks how many bytes have been check for the peak value
	signal peakFound: std_logic; --Signals all the bytes have been checked (i.e. the final peak has been found)

----------------------------------------------------------------

begin

----------- Processes handling the state machine --------------
	
	state_reg: process(clk, reset, curState)
	begin
		if reset = '1' then --if reset goes high, go back to the inital state
			curState <= init;
		elsif rising_edge(clk) then --Rising clock edge
			curState <= nextState;
		else
		   curState <= curState;
		end if;
	end process;

	state_order: process(curState, start, dataArrived, endRequest, conversionComplete, peakFound)
	begin
		case curState is
		when init => 					-- Waiting for the start signal
			if start = '1' then
				nextState <= dataRequest;
			else
				nextState <= init;
			end if;
		when dataRequest => 			-- Requesting data from the generator
			if start = '0' then
				nextState <= init;
			elsif dataArrived = '1' then
				nextState <= sendBytes;
			else
				nextState <= dataRequest;
			end if;
		when sendBytes => 				--Start sending the bytes from the global array
			if start = '0' then
				nextState <= init;
			elsif endRequest = '1' then
				nextState <= finalByte;
			else
				nextState <= sendBytes;
			end if;
		when finalByte =>
		  if start = '0' then
		    nextState <= init;
		  else
		    nextState <= checkPeak;
		  end if;
		when checkPeak => --Wait for the peak checker to go through the entire shift register
		  if start = '0' then
		    nextState <= init;
		  elsif peakFound = '1' then
		    nextState <= assignPeak;
		  else
		    nextState <= checkPeak;
		  end if;
		when assignPeak =>				 		-- Find the peak value and assign it and the 3 bytes before and after into dataResults. 
			if conversionComplete = '1' then	--Also the assigning of maxIndex occurs in this state
				nextState <= sendPeak;
			else
				nextState <= assignPeak;
			end if;
		when sendPeak =>						-- Sends dataResults, and maxIndex and resets counters in the machine
			nextState <= init;
		when others =>
			nextState <= init;
		end case;
	end process;

	combinational_output:process(curState)
	begin
		--Assigning default values
		dataReady <= '0';
		seqDone <= '0';
		beginRequest <= '0';
		resultsValid <= '0';
		resetCounter <= '0';
		countEn <= '0';
		if curState = dataRequest then
			beginRequest <= '1';	--Tells the data processor to start requesting data from the generator
			countEn <= '1';
		end if;
		if curState = sendBytes then
			dataReady <= '1';		--while requesting data, the data will also start sending indivdual bytes to the command processor
			beginRequest <= '1';
			countEn <= '1';
		end if;
		if curState = finalByte then -- to send the final byte
		  dataReady <= '1';
		end if;
		if curState = assignPeak then --Starts the allocation of bytes into dataResults and and converts the peak index into BCD format
			resultsValid <= '1';
		end if;
		if curState = sendPeak then --When the bytes have been put into dataResults and everything is ready to be sent
			seqDone <= '1';
			resetCounter <= '1'; --Resets some of the signals used in the data processor
		end if;
	end process;
  
---------------------------------------------------------

-------   Processes handling numWords_BCD  --------------

	register_numWords:process(start, clk, reset) -- Registers the data from numWords when Start = 1
	begin
		if reset = '1' then
			numWordsReg <= (X"0",X"0",X"0"); 
		elsif rising_edge(clk) then
			if start = '1' then
				numWordsReg <= numWords_bcd;
			else
			  numWordsReg <= numWordsReg;
			end if;
		end if;
	end process;

	convert_numWords:process(numWordsReg) --Converting each BCD value into a digit
	begin
		integerPosistion1 <= to_integer(unsigned(numWordsReg(0)));
		integerPosistion2 <= to_integer(unsigned(numWordsReg(1)));
		integerPosistion3 <= to_integer(unsigned(numWordsReg(2)));
	end process;

	summing_numWords:process(integerPosistion1, integerPosistion2, integerPosistion3) -- summing the digits to convert from BCD to an integer
	begin
		totalSum <= (integerPosistion1 + (integerPosistion2*10) + (integerPosistion3*100));
	end process;

--------------------------------------------------------------------------

---------- Processes handling the handshaking protocol  ------------------
	
	ctrl_out_switching:process(toggle) --CtrlOut is set to the current value of toggle (either 0 or 1)
	begin
		ctrlOut <= toggle;
	end process;


	ctrlOut_counter : process(CLK, countEN, reset, resetCounter, totalSum)  --Counts the number of times a transistion has occured on the ctrlOut line.
	begin
		if reset = '1' then
			countInt <= 0;
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				countInt <= 0;
			elsif countEn = '1' and countInt < totalSum then
				countInt <= countInt + 1;
			else
			  countInt <= countInt;
			end if;
		end if;
	end process;
	
	switching:process(clk, reset, beginRequest, countInt, totalSum) --Alternates toggle between 0 and 1 on each rising clock edge
	begin
	  if reset = '1' then
	    toggle <= '0';
	  elsif rising_edge(clk) then
	    if beginRequest = '1' and countInt < totalSum then
	      toggle <= not toggle;
	    end if;
	  end if;
	end process;
	

-----------------------------------------------------------------------------

--------------------------  Shift Register   --------------------------------

  --Handles the allocation of bytes into the data array as well as shifting the register along
  shift_register_allocate:process(clk, reset, shiftRegister, Data, resetCounter, totalSum)
	variable shiftCounter : integer; --A counter for keeping track of the number of times the shift register has moved data
	begin
		if reset = '1' then
			shiftRegister(0) <= "10000000";
			shiftRegister(1) <= "10000000";
			shiftRegister(2) <= "10000000";
			shiftRegister(3) <= "10000000";
			shiftRegister(4) <= "10000000";
			shiftRegister(5) <= "10000000";
			shiftRegister(6) <= "10000000";
			shiftCounter := 0;
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				shiftRegister(0) <= "10000000";
				shiftRegister(1) <= "10000000";
				shiftRegister(2) <= "10000000";
				shiftRegister(3) <= "10000000";
				shiftRegister(4) <= "10000000";
				shiftRegister(5) <= "10000000";
				shiftRegister(6) <= "10000000";
				shiftCounter := 0;
			end if;
			if ctrl_2Detection = '1' or (shiftCounter > 1 and shiftCounter < (totalSum +4)) then --The shift register shifts for so that all bytes reach shiftRegister(3)
				shiftRegister(1) <= shiftRegister(0);
				shiftRegister(2) <= shiftRegister(1);
				shiftRegister(3) <= shiftRegister(2);
				shiftRegister(4) <= shiftRegister(3);
				shiftRegister(5) <= shiftRegister(4);
				shiftRegister(6) <= shiftRegister(5);
				if shiftCounter >= totalSum then  -- If the peak is near the end of the sequence, the shift register inserts -128
					shiftRegister(0) <= "10000000";
				else
					shiftRegister(0) <= data;  --Otherwise insert data from the generator
				end if;
				shiftCounter := shiftCounter + 1;
			end if;
		else
			shiftRegister(1) <= shiftRegister(1);
			shiftRegister(2) <= shiftRegister(2);
			shiftRegister(3) <= shiftRegister(3);
			shiftRegister(4) <= shiftRegister(4);
			shiftRegister(5) <= shiftRegister(5);
			shiftRegister(6) <= shiftRegister(6);
			shiftRegister(0) <= shiftRegister(0);
		end if;
	end process;



-----------------------------------------------------------------------------

----------------  Storing data processes ------------------------------------

	delay_ctrl_2:process(clk) -- A register storing the delayed value of the ctrlIn signal
	begin
		if rising_edge(clk) then
			ctrl_2Delayed <= ctrlIn;
		end if;
	end process;
	
	send_byte:process(clk, dataArrived, reset, shiftRegister, N, totalSum) -- Sends the bytes from the global data array to command processor
	begin
    if reset = '1' then
		  byte <= "00000000";
    end if;
	if rising_edge(clk) then
		if (dataArrived = '1' or N = totalSum) and N > 0 then --Allocates bytes from the shift register to the command processor
			byte <= shiftRegister(0);
		end if;
	end if;
	end process; 
  
	global_array_counter: process(CLK, reset, resetCounter, ctrl_2Detection) --Now counts the number of bytes coming from the generator 
	begin
		if reset = '1' then
			N <= 0;
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				N <= 0;
			elsif N < totalSum and ctrl_2Detection = '1' then
				N <= N + 1;
			else
				N <= N;
			end if;
		end if;
	end process;
	
	data_generator_detector:process(ctrlIn, ctrl_2Delayed)
	begin
		ctrl_2Detection <= ctrlIn xor ctrl_2Delayed; --Checks that the input and its registered value are different which corresponds to an edge case
	end process;
	
	global_data_array: process(beginRequest, N, totalSum)  -- Controls when the correct number of bytes have been received
	begin
		dataArrived <= '0';
		endRequest <= '0';
		if N >= totalSum and N > 0 then --When the requested number of bytes have arrived
			endRequest <= '1';
		elsif beginRequest = '1' and (N > 0) then --When the first bytes has arrived
			dataArrived <= '1';
		else
			NULL;
		end if;
	end process;
	
-------------------------------------------------------------------------------
	
------------	Processes for finding the converting peak values --------------
	
	--Finds the peak value from the middle of the shift array and when found, the 7 bytes are allocated into dataResults
	detector: process(clk, reset, resetCounter, beginRequest, shiftRegister) 			
	variable valueFromArray: std_logic_vector(7 downto 0);
	begin
		if reset = '1' then
			peakIndex <= 0;
			valueFromArray := "10000000"; -- largest negative number
			peakCounter <= 0;
			rollingPeakBin <= "10000000"; 
			dataResults(0) <= "10000000";
			dataResults(1) <= "10000000";
			dataResults(2) <= "10000000";
			dataResults(3) <= "10000000";
			dataResults(4) <= "10000000";
			dataResults(5) <= "10000000";
			dataResults(6) <= "10000000";
		elsif rising_edge(clk) then
			if resetCounter = '1' then --Counter reset
				peakIndex <= 0;
				valueFromArray := "10000000"; 
				peakCounter <= 0;
				rollingPeakBin <= "10000000";
				dataResults(0) <= "10000000";
				dataResults(1) <= "10000000";
				dataResults(2) <= "10000000";
				dataResults(3) <= "10000000";
				dataResults(4) <= "10000000";
				dataResults(5) <= "10000000";
				dataResults(6) <= "10000000";
			elsif N > 3 and (beginRequest = '1' or peakCounter < totalSum + 3) then
				valueFromArray := shiftRegister(3); 				--Stores the the data bit in a variable which can be converted to signed
				if signed(valueFromArray) >=(rollingPeakBin) then 	--Compares the saved variable to the current peak value
					rollingPeakBin <= signed(shiftRegister(3));
					peakIndex <= peakCounter;
					dataResults(0) <= shiftRegister(0);  --If so, dataResults takes the values from the shift register
					dataResults(1) <= shiftRegister(1);
					dataResults(2) <= shiftRegister(2);
					dataResults(3) <= shiftRegister(3);
					dataResults(4) <= shiftRegister(4);
					dataResults(5) <= shiftRegister(5);
					dataResults(6) <= shiftRegister(6);					
				end if;
				peakCounter <= peakCounter +1;
			end if;
		end if;
	end process;
	
	peak_found: process(peakCounter, totalSum) --Process to check when all the bytes have been compared to the current peak
	begin
		peakFound <= '0';
		if peakCounter >= (totalSum) then
			peakFound <= '1';
		end if;
	end process;
	
	maxIndex_counters:process(CLK, reset, resetCounter, resultsValid, flag100,flag10,flag1) --Counters involved in converting an integer into bcd format
	begin
		if reset = '1' then
			count100 <= "0000";
			count10 <= "0000";
			count1 <= "0000";
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				count100 <= "0000";
				count10 <= "0000";
				count1 <= "0000";
			end if;
			if resultsValid = '1' then --Wait until all the values are in the global array
				if flag100 = '0' then -- Until hundredths has been found
					count100 <= (count100 + 1);
				elsif flag100 = '1' and flag10 = '0' then --When the hundredths has been found and tenths have not been found 
					count10 <= (count10 +1);
				elsif flag10 = '1' and flag1 = '0' then --When the tenths have been found and the ones have not been found
					count1 <= (count1 +1);
				end if;
			end if;
		end if;
	end process;
	
	-- The process works by finding each digit from left right (e.g. for 480 it finds 400, then 80, and then 0)
	peakIndex_to_BCD:process(peakIndex, resultsValid, count100, count10, count1, flag100, flag10)
	begin
		flag1 <= '0';
		flag10 <= '0';
		flag100 <= '0';
		conversionComplete <= '0';
		if resultsValid = '1' then
			if 100*to_integer(count100) > peakIndex then
				flag100 <= '1';
			end if;
			if 10*to_integer(count10) > peakIndex - 100*to_integer(count100 - 1) and flag100 = '1' then --Subtracts the hundredths from the peak index
				flag10 <= '1';
			end if;
			if count1 > peakIndex - 100*to_integer(count100 - 1) - 10*to_integer(count10 - 1) and flag10 ='1' then --Subtracts the hundredths and the tenths from the peak index
				flag1 <= '1';
				conversionComplete <= '1';
			end if;
		end if;
	end process;
	
	maxIndex_allocation:process(clk, reset, flag1) --When the ones have been found, the maxdIndex is set on a rising clock edge
	begin
		if reset = '1' then
			maxIndex(2) <= "0000";
			maxIndex(1)	<= "0000";
			maxIndex(0) <= "0000";
		elsif rising_edge(clk)then
			if flag1 = '1' then	
				maxIndex(2) <= std_logic_vector(count100 - 1);
				maxIndex(1)	<= std_logic_vector(count10 - 1);
				maxIndex(0) <= std_logic_vector(count1 - 1);
			end if;
		else
			null;
		end if;
	end process;
	
end;

-------------------------------------------------------------------------------------