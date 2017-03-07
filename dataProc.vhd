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
	--Signals
	signal curState, nextState: state_type;	
	signal numWordsReg: std_logic_vector(11 downto 0);

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
			end if;
		when s1 => -- Waiting for final data from the data generator(?)
			if 
		when s2 => -- fi
		when s3 =>
		when s4 =>
		when others =>
		end case;
	end process;
	
	register_numWords:process(start. clk) -- Registers the data from numWords when Start = 1
	begin
		if clk'event and clk ='1' then
			if start = '1' then
				numWordsReg <= numWords;
			end if;
		end if;
	end process;
	
	combinational_output:process(curState)
	begin
		dataReady <= '0'
		seqDone <= '0'
	end process;
	
	convert_numWords:process(numWordsReg) --A process to convert numWords to a readable number to get number of bytes
	begin
		
	end process;
	
end;

--#######	Architecture between the process and generator	#######--
--This is to request a new byte, the crtl_1 TRANSISTIONS from either 1 to 0 or vice versa.
--When a new byte is ready, crtl_2 TRANSISTIONS in the same way
architecture dataProc_dataGen of dataProc is
	signal dataReg: std_logic_vector(7 downto 0); -- Store the bytes received
	
	
	
	
begin
	
	register_data: process(ctrl_2)
	begin
		if ctrl_2'event then
			dataReg <= dataIn;
		end if;
	end process;
	
	count: process(clk) --Need a process to change ctrl_1 ennough times to get the correct number of bits, this comes from numWords
	begin
	
	end process;
	
	
	
	
	
end;		
	