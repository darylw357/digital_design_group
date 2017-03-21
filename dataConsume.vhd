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
	type state_type is (init, dataRequest, sendBytes, assignPeak, sendPeak); --States go here
	--Signals
	signal curState, nextState: state_type; -- Used for moving through the state machine
	signal numWordsReg: BCD_ARRAY_TYPE(2 downto 0); --Stores numWords in a register
	signal integerPosistion3,integerPosistion2,integerPosistion1, totalSum : integer; -- Integers involved in numWords
	signal N: integer := 0; --Controls the allocation of the data into the array
	signal resetN: std_logic; -- resets N back to zero when in init;
	signal beginRequest, endRequest: std_logic; --Tell the processor to stop and start requesting data from the generator
	signal totalDataArray : CHAR_ARRAY_TYPE(0 to 999); --Stores every byte recived
	signal rollingPeakBin : signed(7 downto 0) := "10000001"; --Peak byte in binary
	signal peakIndex: integer; --Index of peak byte ## Just remember that maxIndex is BCD_ARRAY_TYPE ##
	signal ctrl_2Delayed, ctrl_2Detection: std_logic; --Ctrl_2 detection signals
	signal resultsValid: std_logic; 
	signal dataArrived: std_logic; -- Check that data has started to be allocated into the global array
	signal conversionComplete: std_logic; --Check that peakIndex has been converted into a bcd format

begin


----------- Processes handling the state machine --------------
	state_reg: process(clk, reset)
	begin
		if reset ='1' then --if reset goes high, go back to the inital state
			curState <= init;
		elsif clk 'event and clk ='1' then --Rising clock edge
			curState <= nextState;
		end if;
	end process;

	state_order: process(clk,curState)
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
			end if;
		when sendBytes => 				--Start sending the bytes from the global array
			if endRequest = '1' then
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
		if curState = dataRequest then
			beginRequest <= '1';
		end if;
		if curState = sendBytes then
			dataReady <= '1';
			beginRequest <= '1';
		end if;
		if curState = assignPeak then
			resultsValid <= '1';
		end if;
		if curState = sendPeak then
			seqDone <= '1';
			resetN <= '1';
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

	summing_numWords:process(integerPosistion1, integerPosistion2, integerPosistion3) -- summing the digits to convert from BCD to an integer
	begin
		if reset = '1' then
			totalSum <= 0;
		else
			totalSum <= (integerPosistion1 + (integerPosistion2*10) + (integerPosistion3*100));
		end if;
	end process;

--------------------------------------------------------------------------

---------- Processes handling the handshaking protocol  ------------------
	request_data:process(CLK, reset, resetN)
	variable switching: std_logic; 
	variable switchCounter: integer := 0; -- switchCounter counts the number of times that ctrlOut has switched and therefore the number of bits requested
	begin                                
		if reset = '1' then
			switching := '0';
			switchCounter := 0;
		end if;
		if rising_edge(clk) then
			if resetN = '1' then
			   switchCounter := 0;
			end if;
			if switchCounter > totalSum  then
			elsif beginRequest = '1'then
				ctrlOut <= switching;
				switching := not switching;
				switchCounter := switchCounter + 1;
			end if;
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

--################################ Might be fixed now but who knows
	send_byte:process(totalDataArray,clk)
	begin
		if rising_edge(clk) and N > 0 then
			byte <= totalDataArray(N-1);
		end if;	
	end process; 
--#################################
  
	global_data_array: process(clk, beginRequest, resetN) --Transmitting is a signal that shows when data is being sent from data gen
	begin
		dataArrived <= '0';
		endRequest <= '0';
		if resetN = '1' and rising_edge(clk) then
		    N <= 0;
		end if;
		ctrl_2Detection <= ctrlIn xor ctrl_2Delayed;
		if rising_edge(clk) then
			if N >= (totalSum) AND N > 0 then --When the number of bytes requested is receieved, a signal is sent to move into the next state
					endRequest <= '1';
			end if;	
			if beginRequest = '1' and endRequest = '0' then
				if ctrl_2Detection = '1' then
					totalDataArray(N) <= data;
					N <= N + 1;
					dataArrived <= '1';
				end if;
			end if;
			
		end if;
	end process; --end data array

-------------------------------------------------------------------------------
	
	--detector actually starts comparing values
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
			   valueFromArray := "10000001"; -- largest negative number
			   rollingPeakBin <= "10000001";
			end if;  
			if N > 0 and beginRequest = '1' then
				valueFromArray := totalDataArray(N-1); --Stores the the data bit in a variable which can be converted to signed
				if signed(valueFromArray) >=(rollingPeakBin) then --Compares the saved variable to the current peak value
					rollingPeakBin <= signed(totalDataArray(N-1));
					peakIndex <= N-1; --Set the index number of the peak value
				end if; --comparison if
			end if;
		end if;

	end process; --end detector

	peakIndex_to_BCD:process(peakIndex, clk, reset)
	variable counter100: unsigned(3 downto 0):= "0000"; -- Counts the hundreds
	variable counter10: unsigned(3 downto 0):= "0000";	-- Counts the tens
	variable counter1: unsigned(3 downto 0):= "0000";	-- 
	variable flag1: std_logic:= '0';
	variable flag2: std_logic:= '0';
	variable flag3: std_logic:= '0';
	begin
		conversionComplete <= '0';
		if reset ='1' or resetN ='1' then
			counter100:= "0000";
			counter10:= "0000";
			counter1:= "0000";
			flag1 := '0';
			flag2 := '0';
			flag3 := '0';
			conversionComplete <= '0';
		end if;
		if resultsValid = '1' then
			if rising_edge(clk) then
				if flag1 = '0' then
					if (to_integer(counter100)*100) > peakIndex then
						maxIndex(2) <= std_logic_vector(counter100 - 1);
						flag1:='1';
					else
						counter100 := (counter100 + 1);
					end if;
				end if;
				if flag2 = '0' and flag1 = '1' then
					if (to_integer(counter10)*10) > (peakIndex - (100*to_integer(counter100-1))) then
						maxIndex(1) <= std_logic_vector(counter10 - 1);
						flag2 :='1';
					else
						counter10 := (counter10 + 1);
					end if;
				end if;
				if flag3 = '0' and flag2 = '1' then
					if to_integer(counter1) > (peakIndex - (100*to_integer(counter100-1)) - (10*to_integer(counter10-1))) then
						maxIndex(0) <= std_logic_vector(counter1 - 1);
						flag3 := '1';
						conversionComplete <= '1';
					else
						counter1 := (counter1 + 1);
					end if;
				end if;	
			end if;
		end if;
	end process;
	
	
	requested_results: process(reset, resultsValid)--the peak index will be in BCD format so not sure how correct this will be (Alex)
	begin
		if resultsValid = '1' then
			dataResults(0) <= "00000000";
			dataResults(1) <= "00000000";
			dataResults(2) <= "00000000";
			dataResults(3) <= "00000000";
			dataResults(4) <= "00000000";
			dataResults(5) <= "00000000";
			dataResults(6) <= "00000000";
			--Perfect Case at least 7 bytes
			if peakIndex > 2 and peakIndex < totalSum - 4 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
				dataResults(6) <= totalDataArray(peakIndex + 3);

			elsif peakIndex > 2 and peakIndex < totalSum - 3 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);

			elsif peakIndex > 2 and peakIndex < totalSum - 2 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);

			elsif peakIndex > 2 and peakIndex < totalSum - 1 then
				dataResults(0) <= totalDataArray(peakIndex - 3);
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);


			elsif peakIndex > 1 and peakIndex < totalSum - 3 then
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);

			elsif peakIndex > 1 and peakIndex < totalSum - 2 then
				dataResults(1) <= totalDataArray(peakIndex - 2);
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);


			elsif peakIndex = 1  and peakIndex < totalSum - 3 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);

			elsif peakIndex = 1 and peakIndex < totalSum - 2 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);

			elsif peakIndex = 1 and peakIndex < totalSum - 1 then
				dataResults(2) <= totalDataArray(peakIndex - 1);
				dataResults(3) <= totalDataArray(peakIndex);

			elsif peakIndex = 0 and peakIndex = totalSum  then
				dataResults(3) <= totalDataArray(peakIndex);

			end if;

		end if;
	end process; -- end requested_results
  

end;