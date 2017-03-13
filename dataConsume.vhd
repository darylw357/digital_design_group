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
	signal N: integer := 0;
	--signal dataReg: signed(7 downto 0) := "00000000"; -- Store the bytes received
	signal beginRequest, endRequest: std_logic; --Tell the processor to stop and start requesting data from the generator
	signal totalDataArray : CHAR_ARRAY_TYPE(0 to 999); --Stores every byte recived
	signal rollingPeakBin : signed(7 downto 0) := "11111111"; --Peak byte in binary
	signal currentByteValue : signed(7 downto 0); --Current byte in binary
	signal peakIndex: integer; --Index of peak byte ## Just remember that maxIndex is BCD_ARRAY_TYPE ##
	signal ctrl_2Delayed, ctrl_2Detection: std_logic; --Ctrl_2 detection signals
	signal resultsValid, byteReady: std_logic;
	signal sendByte: std_logic;

begin


----------- Processes handling the state machine --------------
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
		if start ='0' then
			nextState <= s0;
		end if;
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
		  nextState <= s3;
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
		end if;
		if curState = s4 then
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
	request_data:process(CLK, reset)

	variable switching: std_logic := '0'; --#################################################################################
	variable switchCounter: integer := 0; --#The introduction of this variable has mean that not enough bytes are being sent#
	begin                                 --#################################################################################
		if reset = '1' then
			switching := '0';
			switchCounter := 0;
		end if;
		if beginRequest = '1' and switchCounter < totalSum +1 then
			if rising_edge(clk) then
				ctrlOut <= switching;
				switching := not switching;
				switchCounter := switchCounter + 1;
			end if;
		end if;
	end process;

	delay_ctrl_2:process(clk)
	begin
		if rising_edge(clk) then
			ctrl_2Delayed <= ctrlIn;
		end if;
	end process;

-----------------------------------------------------------------------------

----------------  Storing data processes ------------------------------------

--################################ This is lazy and should be fixed (later)
	send_byte:process(totalDataArray,clk)
	begin
		if rising_edge(clk) and N > 0 then
			byte <= totalDataArray(N-1);
			dataReady <= '1';
		end if;	
	end process; 
--#################################
  
	global_data_array: process(clk,beginRequest) --Transmitting is a signal that shows when data is being sent from data gen
	begin
		if beginRequest = '1' then -- Not sure about the last condition because the register can be "00000000"
			ctrl_2Detection <= ctrlIn xor ctrl_2Delayed;
			if ctrl_2Detection = '1' AND rising_edge(clk) then
				totalDataArray(N) <= data;
				N <= N + 1;
			end if;
			
			if N > (totalSum-1) AND N > 0 then --When the number of bytes requested is receieved, a signal is sent to move into the next state
			   endRequest <= '1';
			end if;
		end if;
		

	end process; --end data array

-------------------------------------------------------------------------------
	
	--detector actually starts comparing values
	detector: process(clk,totalDataArray, reset) 						
	variable valueFromArray: std_logic_vector(7 downto 0);
	begin
		if reset ='1' then
			peakIndex <= 0;
			valueFromArray := "11111111"; -- largest negative number
			rollingPeakBin <= "11111111";
		end if;
		if rising_edge(clk) and N > 0 then
			valueFromArray := totalDataArray(N-1); --Stores the the data bit in a variable which can be converted to signed
			if signed(valueFromArray) >=(rollingPeakBin) then --Compares the saved variable to the current peak value
				rollingPeakBin <= signed(totalDataArray(N-1));
				peakIndex <= N-1; --Set the index number of the peak value
			end if; --comparison if
		end if;

	end process; --end detector

	peakIndex_to_BCD:process(peakIndex, clk, reset)
	variable counter100: unsigned(3 downto 0):= "0000";
	variable counter10: unsigned(3 downto 0):= "0000";
	variable counter1: unsigned(3 downto 0):= "0000";
	variable flag1: std_logic:= '0';
	variable flag2: std_logic:= '0';
	variable flag3: std_logic:= '0';
	begin
		if reset ='1' then
			counter100:= "0000";
			counter10:= "0000";
			counter1:= "0000";
			flag1 := '0';
			flag2 := '0';
			flag3 := '0';
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
					else
						counter1 := (counter1 + 1);
					end if;
				end if;	
			end if;
		end if;
	end process;
	
	
	--Collects six results and the peak byte.
	requested_results: process(reset, resultsValid)
	begin
		if resultsValid = '1' then
			if peakIndex > 2 and peakIndex < totalSum - 4 then
				dataResults(0) <= totalDataArray(peakIndex - 3); --fix data array stores bits not bytes
				dataResults(1) <= totalDataArray(peakIndex - 2); --these vector ranges are not quite correct
				dataResults(2) <= totalDataArray(peakIndex - 1); --the peak index will be in BCD format so not sure how correct this will be (Alex)
				dataResults(3) <= totalDataArray(peakIndex);
				dataResults(4) <= totalDataArray(peakIndex + 1);
				dataResults(5) <= totalDataArray(peakIndex + 2);
				dataResults(6) <= totalDataArray(peakIndex + 3); -- ## Make a case if the peak index is less than 3 or something
			end if;	
		end if;
	end process; -- end requested_results
  

end;