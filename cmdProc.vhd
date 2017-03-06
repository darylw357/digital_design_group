--Command Processor 
--Daryl White and Alexander Hamilton
library ieee;
use ieee.std_logic_1164.all;

--code goes here

entity cmdProc is	 
	port(
	CLK: in std_logic;
	reset: in std_logic;
	--Ports between cmdProc and dataProc
	START: out std_logic;
	numWords: out std_logic_vector(11 downto 0);
	dataReady: in std_logic;
	byte: in std_logic_vector(7 downto 0);
	maxIndex: in std_logic_vector(11 downto 0);
	dataResults: in std_logic_vector(55 downto 0);
	seqDone: in std_logic;
	--Ports between cmdProc and Rx
	done: out std_logic;
	dataIn: in std_logic_vector(7 downto 0);
	valid: in std_logic;
	oe: in std_logic;
	fe: in std_logic;
	--Ports between cmdProc and Tx
	dataOut: out std_logic_vector(7 downto 0);
	txNow: out std_logic;
	txDone: in std_logic
 );
end;
 
architecture cmdProc_arch of cmdProc is
	type state_type is (init, read, beginSend);
	-- Init is the cmd block waitning for the signal, read is reading the data from the rx
	-- beginSend is sending the instructions to the data processor (only for one clock cycle)
	signal curState, nextState: state_type;
	--input Signals
	-- Most of the internal signals can be done on the go
	--Data signals
	signal rxCommands: std_logic_vector(11 downto 0); -- Store data from RX in this signal
  
  
begin

	stateReg: process(clk, reset)
	begin 
    if reset ='1' then
      curState <= init;
    elsif clk 'event and clk ='1' then
      curState <= nextState;
    end if;
	end process;
  
  
  stateOutput: process(curState)
  begin
    case curState is
    when init =>
    when read =>
    when beginSend =>
      start <= '1';
    end case;
  end process;

end;


-- Daryl Rx
architecture cmdProc_Rx of cmdProc is
	type state_type is (S0, S1, S2, S3, S4); --States go here
	--Signals
	signal curState, nextState: state_type;	
	signal Y: std_logic;
  
begin	


	seq_state: process (CLK, reset) --changes state on clock
	begin
	if reset = '0' then
		curState <= S0;
	elsif clk'event AND clk='1' then
		curState <= nextState;
	end if;
	end process; -- seq


	rxStateMachine: process(curState,rxD) -- process rxStateMachine sensitivity
	begin
	case curState is
		when S0 =>
    if valid = '1';
		nextState <= S1
    else nextState <= S0;
		when S1 =>
		if rxD = "a"
		
	end if;	
	end case;
	end process; 

  combi_out: process(curState)
	begin
	Y <= '0'; -- assign default value
	end process; -- combi_output

end;

architecture cmdProc_tx of cmdProc is
	type state_type is (s0, s1, s2); --States go here
	--Signals
	signal curState, nextState: state_type;
	signal txNowS, txDoneS: std_logic;
 
 begin
	
	stateReg: process(clk, reset)
	begin 
	if reset ='1' then --if reset goes high, go back to the inital state
		curState <= s0;
	elsif clk 'event and clk ='1' then --Rising clock edge
		curState <= nextState;
	end if;
	end process;
	
	combi_out: process(curState)
	begin
	txNow <= '0'; -- assign default value
	if curState = s1 then
		txNow <= '1';
	end if;
	end process; -- combi_output
	
	state_order:process(curState)
	begin
	case curState is
	when s0 =>
		if seqDone = '1' then
			nextState <= s1;
		end if;
	when s1 =>
		nextState <= s2;
	when s2 =>
		if txDone = '1' then
			nextState <= s0;
		end if;
	when others =>
		nextState <= s0;
	end case;
	end process;

end;

architecture cmdProc_dataProcessor of cmdProc is
	signal numWordsFromRx : std_logic_vector(11 downto 0);
	signal dataValid : std_logic;
	type state_type is (s0, s1, s2, s3); --States go here
	--Signals
	signal curState, nextState: state_type;	
begin
	
	stateReg: process(clk, reset)
	begin 
	if reset ='1' then --if reset goes high, go back to the inital state
		curState <= s0;
	elsif clk 'event and clk ='1' then --Rising clock edge
		curState <= nextState;
	end if;
	end process;
	
	state_order:process(curState)
	begin
	case curState is
	when s0 =>
		if dataValid = '1' then
			nextState <= s1;
		end if;
	when s1 =>
		nextState <= s2;
	when s2 =>
		if dataReady = '1' then
			nextState <= s3;
		end if;
	when others =>
		nextState <= s0;
	end case;
	end process;
	
	combi_out: process(curState)
	begin
	start <= '0'; -- assign default value
	if curState = s1 then
		start <= '1';
	end if;
	end process; -- combi_output
	
end;
 