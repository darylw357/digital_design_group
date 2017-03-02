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
  type state_type is (init, read, send);
  -- Init is the cmd block waitning for the signal, read is reading the data from the rx
  -- Send is sending the instructions to the data processor
  signal curState, nextState: state_type;
  --input Signals


begin

  stateReg: process(clk, reset)
  begin
    if reset ='1' then
      curState <= init;
    elsif clk 'event and clk ='1' then
      curState <= nextState;
    end if;
  end process;

  stateOrder: process(curState)
  begin
    case curState is
    when init =>
      if Valid = '1' then
        nextState <= read;
      end if;
    when read =>
      if done = '1' then
        nextState <= send;
    when send =>
    end case;
  end process;


end;


-- Daryl Rx
architecture cmdProc_Rx of cmdProc is
	state_type is (S0, S1, S2, S3, S4); --States go here
	--Signals
	signal curState, nextState: state_type;
  signal rxDs: std_logic;
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
		

end process;

combi_out: process(curState)
 begin
   Y <= '0'; -- assign default value
   if curState = S3 then
     Y <= '1';
   end if;
 end process; -- combi_output
