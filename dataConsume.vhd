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
	type state_type is (init, dataRequest, sendBytes, assignPeak, sendPeak, dataRequestSwitch, sendBytesSwitch); --States go here
	--Signals
	signal curState, nextState: state_type; -- Used for state machine control
	signal numWordsReg: BCD_ARRAY_TYPE(2 downto 0); --Stores numWords in a register
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer; -- Integers involved in the summing of numWord
	signal N: integer := 0; --Controls the allocation of the data into the array
	signal resetCounter: std_logic; -- a synchronous reset signal that resets counters and the peak byte
	signal beginRequest, endRequest: std_logic; --Tells the processor to stop and start requesting data from the generator
	signal totalDataArray : CHAR_ARRAY_TYPE(0 to 999); --Stores every byte recived
	signal rollingPeakBin : signed(7 downto 0) := "10000001"; --Peak byte in signed binary
	signal peakIndex: integer; --Index of peak byte in integer form
	signal ctrl_2Delayed, ctrl_2Detection: std_logic; --Ctrl_2 detection signals (ctrl_2 is now ctrlIn)
	signal resultsValid: std_logic; --When the array has the correct number of bytes in it
	signal dataArrived: std_logic; -- Checks that data has started to be allocated into the global array
	signal conversionComplete: std_logic; --Checks that peakIndex has been converted into a bcd format
	signal toggle: std_logic; -- used for toggling ctrlOut between 1 and 0
	signal switch: std_logic; -- used to switch between states that alters toggle
	signal countEn: std_logic; --enables the count for number of switches
	signal countInt: integer; --counts the number of switches
	signal count100, count10, count1: unsigned(3 downto 0); -- for converting integer into bcd
	signal flag100,flag10,flag1: std_logic; --Checks for the conversion of integers into bcd


begin


----------- Processes handling the state machine --------------
	state_reg: process(clk, reset)
	begin
		if reset ='1' then --if reset goes high, go back to the inital state
			curState <= init;
		elsif rising_edge(clk) then --Rising clock edge
			curState <= nextState;
		else
		   null;
		end if;
	end process;

	state_order: process(curState, start, dataArrived, endRequest, conversionComplete, switch)
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
				nextState <= sendBytesSwitch;
			elsif switch ='1' then
				nextState <= dataRequestSwitch;
			else
				nextState <= dataRequest;
			end if;
		when dataRequestSwitch =>		--Similar to dataRequest but contains the toggle
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
				nextState <= assignPeak;
			elsif switch ='1' then
				nextState <= sendBytesSwitch;
			else
				nextState <= sendBytes;
			end if;
		when sendBytesSwitch =>			--Similar to sendBytes but contains the a toggle
			if start = '0' then
				nextState <= init;
			elsif endRequest = '1' then
				nextState <= assignPeak;
			else
				nextState <= sendBytes;
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
		dataReady <= '0';
		seqDone <= '0';
		beginRequest <= '0';
		resultsValid <= '0';
		resetCounter <= '0';
		toggle <= '0';
		countEn <= '0';
		if curState = dataRequest then
			beginRequest <= '1';	--Tells the data processor to start requesting data from the generator
			toggle <= '0';
			countEn <= '1';
		end if;
		if curState = sendBytes then
			dataReady <= '1';		--while requesting data, the data will also start sending indivdual bytes to the command processor
			beginRequest <= '1';
			countEn <= '1';
		end if;
		if curState = dataRequestSwitch then --Assert toggle
			beginRequest <= '1';
			countEn <= '1';
			toggle <= '1';
		end if; 
		if curState = sendBytesSwitch then --Assert toggle
			beginRequest <='1';
			dataReady <= '1';
			countEn <= '1';
			toggle <= '1';
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
			end if;
		end if;
	end process;

	convert_numWords:process(numWordsReg, reset) --Converting each BCD value into a digit
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
	ctrl_out_switching:process(clk, toggle, reset)
	begin
		ctrlOut <= '0';
		if toggle = '1' then
		   ctrlOut <= '1';
		end if;
	end process;


	ctrlOut_counter : process(CLK, countEN, reset, resetCounter, totalSum) -- These is synthesized
	begin
		if reset ='1' then
			countInt <= 0;
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				countInt <= 0;
			elsif countEn = '1' and countInt < totalSum then
				countInt <= countInt + 1;
			end if;
		end if;
	end process;
	
	request_data:process(countInt, totalSum, beginRequest)
	begin                                
		switch <= '0';
		if countInt >= (totalSum) then
			switch <= '0';
		elsif beginRequest = '1' and countInt < totalSum then
			switch <= '1';
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
	
	send_byte:process(clk, dataArrived, reset, totalDataArray, N, totalSum)
	begin
    if reset = '1' then
      byte <= "00000000";
    end if;
		if rising_edge(clk) and dataArrived = '1' and N > 0 then
			byte <= totalDataArray(N-1);
		elsif rising_edge(clk) and N = totalSum and N>0 then
		  byte <= totalDataArray(totalSum-1);
		end if;	
	end process; 
  
	global_array_counter: process(CLK, reset, resetCounter)
	begin
		if reset = '1' then
			N <= 0;
		elsif rising_edge(clk) then
			if resetCounter = '1' then
				N <= 0;
			elsif N < totalSum and dataArrived = '1' then
				N <= N + 1;
			end if;
		end if;
	end process;
	
	ctrl_2Detection <= ctrlIn xor ctrl_2Delayed; --Checks that the input and its registered value are different which corresponds to an edge case
	
	global_data_array: process(beginRequest, N, ctrl_2Detection, totalSum) 
	begin
		dataArrived <= '0';
		endRequest <= '0';
		if N >= totalSum and N > 0 then
			endRequest <= '1';
		elsif beginRequest = '1' and ctrl_2Detection = '1' then
			dataArrived <= '1';
		else
			NULL;
		end if;
	end process; --end data array
	
	global_data_allocation:process(clk, reset, ctrl_2Detection, data, N)
	begin 
		if reset = '1' then
			totalDataArray(N) <= "00000000";
		elsif rising_edge(clk) and ctrl_2Detection = '1' then
			totalDataArray(N) <= data;
		else
			null;
		end if;
	end process;
-------------------------------------------------------------------------------
	
------------	Processes for finding the converting peak values --------------
	detector: process(clk, reset, resetCounter, beginRequest) 						
	variable valueFromArray: std_logic_vector(7 downto 0);
	begin
		if reset ='1' then
			peakIndex <= 0;
			valueFromArray := "10000001"; -- largest negative number
			rollingPeakBin <= "10000001"; 
		elsif rising_edge(clk) then
			if resetCounter = '1' then
			   peakIndex <= 0;
			   valueFromArray := "10000001"; 
			   rollingPeakBin <= "10000001";
			end if;  
			if N > 0 and beginRequest = '1' then
				valueFromArray := totalDataArray(N-1); --Stores the the data bit in a variable which can be converted to signed
				if signed(valueFromArray) >=(rollingPeakBin) then --Compares the saved variable to the current peak value
					rollingPeakBin <= signed(totalDataArray(N-1));
					peakIndex <= N-1; --Set the index number of the peak value
				end if;
			end if;
		end if;
	end process;

	maxIndex_counters:process(CLK, reset, resetCounter, resultsValid, flag100,flag10,flag1)
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
			if resultsValid = '1' then
				if flag100 = '0' then
					count100 <= (count100 + 1);
				elsif flag100 = '1' and flag10 = '0' then
					count10 <= (count10 +1);
				elsif flag10 = '1' and flag1 = '0' then
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
			if 10*to_integer(count10) > peakIndex - 100*to_integer(count100 - 1) and flag100 = '1' then
				flag10 <= '1';
			end if;
			if count1 > peakIndex - 100*to_integer(count100 - 1) - 10*to_integer(count10 - 1) and flag10 ='1' then
				flag1 <= '1';
				conversionComplete <= '1';
			end if;
		end if;
	end process;
	
	maxIndex_allocation:process(clk, reset, flag1)
	begin
		if reset = '1' then
			maxIndex(2) <=  "0000";
			maxIndex(1)	<= "0000";
			maxIndex(0) <= "0000";
		elsif rising_edge(clk) and flag1 = '1' then
			maxIndex(2) <=  std_logic_vector(count100 - 1);
			maxIndex(1)	<= std_logic_vector(count10 - 1);
			maxIndex(0) <= std_logic_vector(count1 - 1);
		else
			null;
		end if;
	end process;
	
	requested_results: process(reset, resultsValid, totalDataArray, peakIndex,clk)--the peak index will be in BCD format so not sure how correct this will be (Alex)
	begin
		if reset = '1' then
			dataResults(0) <= "00000000";
			dataResults(1) <= "00000000";
			dataResults(2) <= "00000000";
			dataResults(3) <= "00000000";
			dataResults(4) <= "00000000";
			dataResults(5) <= "00000000";
			dataResults(6) <= "00000000";
			--Perfect Case at least 7 bytes
		elsif rising_edge(clk) and resultsValid = '1' then
			dataResults(0) <= totalDataArray(peakIndex - 3);
			dataResults(1) <= totalDataArray(peakIndex - 2);
			dataResults(2) <= totalDataArray(peakIndex - 1);
			dataResults(3) <= totalDataArray(peakIndex);
			dataResults(4) <= totalDataArray(peakIndex + 1);
			dataResults(5) <= totalDataArray(peakIndex + 2);
			dataResults(6) <= totalDataArray(peakIndex + 3);
		else
			null;
		end if;
	end process; -- end requested_results
  

end;