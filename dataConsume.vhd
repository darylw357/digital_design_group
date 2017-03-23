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
	type state_type is (init, dataRequest, sendBytes, assignPeak, sendPeak, s1, s2); --States go here
	--Signals
	signal curState, nextState: state_type; -- Used for state machine control
	signal numWordsReg: BCD_ARRAY_TYPE(2 downto 0); --Stores numWords in a register
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer; -- Integers involved in the summing of numWord
	signal N: integer := 0; --Controls the allocation of the data into the array
	signal resetN: std_logic; -- resets N back to zero when in init state;
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
  signal byteLoaded : std_logic;


begin


----------- Processes handling the state machine --------------
	state_reg: process(clk, reset)
	begin
		if reset ='1' then --if reset goes high, go back to the inital state
			curState <= init;
		elsif rising_edge(clk) then --Rising clock edge
			curState <= nextState;
		end if;
	end process;

	state_order: process(curState, start, dataArrived, endRequest, conversionComplete, switch)
	begin
		if start ='0' then 				--Start must always be asserted for the data processor to run
			nextState <= init;
		end if;
		case curState is
		when init => 					-- Waiting for the start signal
			if start = '1' then
				nextState <= dataRequest;
			end if;
		when dataRequest => 			-- Requesting data from the generator
			if dataArrived = '1' then
				nextState <= sendBytes;
			elsif switch ='1' then
				nextState <= s1;
			end if;
		when s1 =>
			if switch = '1' then
				if dataArrived = '1' then
				  nextState <= sendBytes;
				else
				  nextState <= dataRequest; 
				end if;
			end if;
		when sendBytes => 				--Start sending the bytes from the global array
			if endRequest = '1' then
				nextState <= assignPeak;
			elsif switch ='1' then
				nextState <= s2;
			end if;
		when s2 =>
		  if switch = '1' then
		    nextState <= sendBytes;
		  elsif endRequest = '1' then
		    nextState <= assignPeak;
		  end if;
		when assignPeak =>				 		-- Find the peak value and assign it and the 3 bytes before and after into dataResults. 
			if conversionComplete = '1' then	--Also the assigning of maxIndex occurs in this state
				nextState <= sendPeak;
			end if;
		when sendPeak =>						-- Sends dataResults, and maxIndex and resets many of the signals in the machine
			nextState <= init;
		when others =>
		end case;
	end process;

	combinational_output:process(curState)
	begin
		dataReady <= '0';
		seqDone <= '0';
		beginRequest <= '0';
		resultsValid <= '0';
		resetN <= '0';
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
		if curState = s1 then
		  beginRequest <= '1';
		  countEn <= '1';
		  toggle <= '1';
		end if; 
		if curState = s2 then
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
			resetN <= '1'; --Resets some of the signals used in the data processor
		end if;
	end process;
  
---------------------------------------------------------

-------   Processes handling numWords_BCD  --------------

	register_numWords:process(start, clk) -- Registers the data from numWords when Start = 1
	begin
		if rising_edge(clk) then
			if start = '1' then
				numWordsReg <= numWords_bcd;
			end if;
		end if;
	end process;

	convert_numWords:process(numWordsReg, reset) --Converting each BCD value into a digit
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

	summing_numWords:process(integerPosistion1, integerPosistion2, integerPosistion3, reset) -- summing the digits to convert from BCD to an integer
	begin
		if reset = '1' then
			totalSum <= 0;
		else
			totalSum <= (integerPosistion1 + (integerPosistion2*10) + (integerPosistion3*100));
		end if;
	end process;

--------------------------------------------------------------------------

---------- Processes handling the handshaking protocol  ------------------
	ctrl_out_switching:process(clk, toggle, reset)
	begin
	if reset = '1' then
	   ctrlOut <= '0';
	elsif rising_edge(clk) then
		if toggle = '0' then
			ctrlOut <= '0' ;
		elsif toggle = '1' then
			ctrlOut <= '1' ;
		end if;
	end if;
	end process;


	ctrlOut_counter : process(CLK, countEN, reset, resetN, totalSum) -- These is synthesized
	begin
		if reset ='1' then
			countInt <= 0;
		elsif rising_edge(clk) then
			if resetN = '1' then
				countInt <= 0;
			elsif countEn = '1' and countInt < totalSum then
				countInt <= countInt + 1;
			end if;
		end if;
	end process;
	
	request_data:process(reset, resetN, countInt, totalSum, beginRequest)
	begin                                
		if reset = '1' then
			switch <= '0';
		end if;
		if resetN = '1' then
		elsif countInt >= (totalSum-1) then
			 switch <= '0';
		elsif beginRequest = '1' and countInt < totalSum then
			switch <= '1';
		end if;
	end process;

	delay_ctrl_2:process(clk) -- A register storing the delayed value of the ctrlIn signal
	begin
		if rising_edge(clk) then
			ctrl_2Delayed <= ctrlIn;
		end if;
	end process;

-----------------------------------------------------------------------------

----------------  Storing data processes ------------------------------------

	send_byte:process(totalDataArray,clk, N)
	begin
		if rising_edge(clk) and N > 0 then
			byte <= totalDataArray(N-1);
		end if;	
	end process; 
  
	global_array_counter: process(CLK, reset, resetN)
	begin
		if reset = '1' then
			N <= 0;
		elsif rising_edge(clk) then
			if resetN = '1' then
				N <= 0;
			elsif N < totalSum and dataArrived = '1' then
				N <= N + 1;
			end if;
		end if;
	end process;
	
	ctrl_2Detection <= ctrlIn xor ctrl_2Delayed;
	
	
	
	global_data_array: process(beginRequest, resetN, N, ctrl_2Detection, reset, totalSum, data) 
	begin
		if resetN = '1' or reset = '1' then
		    dataArrived <= '0';
		    endRequest <= '0';
		end if;
		if N >= totalSum and N > 0 then
			endRequest <= '1';
		elsif beginRequest = '1' and ctrl_2Detection = '1' then
			totalDataArray(N) <= data;
			dataArrived <= '1';
		else
		  totalDataArray(N) <= "00000000";
		end if;
		
		
		-- if rising_edge(clk) then
			-- if beginRequest = '1' and endRequest = '0' then
				-- if N >= (totalSum) AND N > 0 then --When the number of bytes requested is receieved, a signal is sent to move into the next state
					-- endRequest <= '1';
				-- elsif ctrl_2Detection = '1' then
					-- totalDataArray(N) <= data;
					-- dataArrived <= '1';
				-- end if;
			-- end if;
		-- end if;
	end process; --end data array

-------------------------------------------------------------------------------
	
------------	Processes for finding the converting peak values --------------
	detector: process(clk, reset, resetN, beginRequest) 						
	variable valueFromArray: std_logic_vector(7 downto 0);
	begin
		if reset ='1' then
			peakIndex <= 0;
			valueFromArray := "10000001"; -- largest negative number
			rollingPeakBin <= "10000001"; 
		end if;
		if rising_edge(clk) then
			if resetN = '1' then
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

	maxIndex_counters:process(CLK, reset, resetN, resultsValid, flag100,flag10,flag1)
	begin
		if reset = '1' then
			count100 <= "0000";
			count10 <= "0000";
			count1 <= "0000";
		elsif rising_edge(clk) then
			if resetN = '1' then
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
	peakIndex_to_BCD:process(peakIndex, resultsValid, reset, resetN, count100, count10, count1)
	begin
		if reset ='1' or resetN ='1' then
			flag1 <= '0';
			flag10 <= '0';
			flag100 <= '0';
			conversionComplete <= '0';
		end if;
		if resultsValid = '1' then
			if 100*to_integer(count100) > peakIndex then
				flag100 <= '1';
				maxIndex(2) <= std_logic_vector(count100 - 1);
			end if;
			if 10*to_integer(count10) > peakIndex - 100*to_integer(count100 - 1) and flag100 = '1' then
				flag10 <= '1';
				maxIndex(1) <= std_logic_vector(count10 - 1);
			end if;
			if count1 > peakIndex - 100*to_integer(count100 - 1) - 10*to_integer(count10 - 1) and flag10 ='1' then
				flag1 <= '1';
				maxIndex(0) <= std_logic_vector(count1 - 1);
				conversionComplete <= '1';
			end if;
		end if;
	end process;
	
	
	requested_results: process(reset, resultsValid, totalDataArray, peakIndex, totalSum)--the peak index will be in BCD format so not sure how correct this will be (Alex)
	begin
		if resultsValid = '1' then
			dataResults(0) <= "00000000";
			dataResults(1) <= "00000000";
			dataResults(2) <= "00000000";
			dataResults(3) <= totalDataArray(peakIndex);
			dataResults(4) <= "00000000";
			dataResults(5) <= "00000000";
			dataResults(6) <= "00000000";
			--Perfect Case at least 7 bytes
			if peakIndex > 2 and peakIndex < totalSum - 4 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
				dataResults(6) <= totalDataArray(peakIndex + 3);
			elsif peakIndex > 2 and peakIndex < totalSum - 3 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
			elsif peakIndex > 2 and peakIndex < totalSum - 2 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
			elsif peakIndex > 2 and peakIndex < totalSum - 1 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
			elsif peakIndex > 1 and peakIndex < totalSum - 3 then
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
			elsif peakIndex > 1 and peakIndex < totalSum - 2 then
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
			elsif peakIndex = 1  and peakIndex < totalSum - 3 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
			elsif peakIndex = 1 and peakIndex < totalSum - 2 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(4) <= totalDataArray(peakIndex + 1);
			elsif peakIndex = 1 and peakIndex < totalSum - 1 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
			end if;
		end if;
	end process; -- end requested_results
  

end;