library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

use work.common_pack.all;

entity tb_dataGenConsume is 
end;

architecture test of tb_dataGenConsume is 

  component dataGen is
  	port (
  	 clk:		in std_logic;
  		reset:		in std_logic; -- synchronous reset
  		ctrlIn: in std_logic;
  		ctrlOut: out std_logic;
  		data: out std_logic_vector(7 downto 0)
  	);
  end component;
  
  component dataConsume is
  	port (
	  clk:		in std_logic;
		reset:		in std_logic; -- synchronous reset
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
  end component;
  
  constant SEQ_COUNT_MAX : integer := 5; -- defines how many runs to test
  type ARRAY3D_TYPE is array (0 to SEQ_COUNT_MAX) of CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
  type ARRAY3D_BCD_TYPE is array (0 to SEQ_COUNT_MAX) of BCD_ARRAY_TYPE(2 downto 0);
  
  constant RESULTS : ARRAY3D_TYPE :=((X"43", X"31", X"37", X"7F", X"09", X"60", X"5B"),
                                     (X"E3", X"A5", X"C9", X"7E", X"67", X"E0", X"B5"),
                                     (X"72", X"FD", X"CB", X"7D", X"22", X"37", X"D4"),
                                     (X"5B", X"A3", X"C0", X"7E", X"9E", X"52", X"4E"),
                                     (X"C5", X"6C", X"70", X"7D", X"38", X"D5", X"80"),
                                     (X"43", X"31", X"37", X"7F", X"09", X"60", X"5B"));
                                     
  constant peak : ARRAY3D_BCD_TYPE :=((X"4",X"8",X"0"),(X"0",X"5",X"0"),(X"0",X"9",X"0"),
                                      (X"0",X"5",X"5"),(X"0",X"5",X"2"),(X"0",X"8",X"0"));
  
  constant maxCycleCount : integer := 4500; -- the sequences shoudn't take more than about 4200 cycles
  
  -- function to convert std_logic_vector having '1's and '0's to string
  -- for use in assert statements
  function vec2str(vec : std_logic_vector) return string is
    variable str : string(vec'LEFT+1 DOWNTO 1);
  begin
    for i in vec'REVERSE_RANGE loop
      if vec(i) = '1' then
        str(i+1) := '1';
      elsif vec(i) = '0' then
        str(i+1) := '0';
      else
        str(i+1) := 'X';
      end if;
    end loop;
    return str;
  end vec2str;
  
  signal clk: std_logic := '0';
  signal reset, start, ctrl_genDriv, ctrl_consDriv, dataReady, seqDone: std_logic;
  signal readData, curByte: std_logic_vector(7 downto 0);
  signal numWords, maxIndex: BCD_ARRAY_TYPE(2 downto 0);
  signal dataResults: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
  signal tbCount, seqCount: integer :=0;

begin
  clk <= NOT clk after 10 ns when seqCount <=SEQ_COUNT_MAX else clk;
  reset <= '0', '1' after 2 ns, '0' after 15 ns, '0' after 3600 ns, '0' after 3615 ns;
  
  
  assign_numWords: process
    variable curCount: integer :=0;
  begin
      start <= '0';
      wait until tbCount=2; -- wait a few clock cycles after reset
      numWords <=(X"5",X"0",X"0"); -- 500
      start <= '1';
      wait until seqDone='1';
      start <='0';
      curCount:= tbCount;
      wait until tbCount=curCount+10; -- wait for a few clock cycles
      numWords <=(X"1",X"0",X"0"); -- 100
      start <= '1';      
      wait;
  end process;
      
  
  tbCounter:	process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        assert tbCount<maxCycleCount report "Cycle count exceeded " & INTEGER'IMAGE(maxCycleCount) & "; Cycle count:" & INTEGER'IMAGE(tbCount) severity failure;
        tbCount <= 0;
      else  
	      tbCount <= tbCount + 1;
	    end if;
	  end if;
	end process;
  
  seqCounter:	process(seqDone)
  begin
    if reset = '1' then
      seqCount <= 0;
    elsif rising_edge(seqDone) then -- clearly only acceptable in a TB
       seqCount <= seqCount + 1;

       assert false report "Sequence No." & INTEGER'IMAGE(seqCount) & "; Cycle count:" & INTEGER'IMAGE(tbCount) severity note;
       
       for i in 0 to RESULT_BYTE_NUM-1 loop
          -- byte ordering may be different in different implementations
          -- try changing (RESULT_BYTE_NUM-1-i) to (i) if there is a mismatch between all bytes except the peak
          assert dataResults(RESULT_BYTE_NUM-1-i) = RESULTS(seqCount)(i) report "Mismatch for seq " & INTEGER'IMAGE(seqCount) 
          & ":" & CR & "byte " & INTEGER'IMAGE(i) & " should be " & vec2str(RESULTS(seqCount)(i))
          & CR & "but is           " & vec2str(dataResults(RESULT_BYTE_NUM-1-i)) severity warning;
       end loop;
       
       assert maxIndex = peak(seqCount) report "Mismatch for seq " & INTEGER'IMAGE(seqCount) 
          & ":" & CR & "peak " & INTEGER'IMAGE(seqCount) & " should be {" 
          & vec2str(peak(seqCount)(2)) & "} {" &vec2str(peak(seqCount)(1)) & "} {" &vec2str(peak(seqCount)(0)) &"}"
          & CR & "but is           {" & vec2str(maxIndex(2)) & "} {" & vec2str(maxIndex(1)) & "} {" & vec2str(maxIndex(0)) &"}" severity warning;
      
       assert tbCount<maxCycleCount report "Cycle count exceeded " & INTEGER'IMAGE(maxCycleCount) & "; Cycle count:" & INTEGER'IMAGE(tbCount) severity error;
	  end if;
	end process;

  
  dataGen1: dataGen
    port map (
      clk => clk,
      reset => reset,
      ctrlIn => ctrl_consDriv,
      ctrlOut => ctrl_genDriv,
      data => readData
    );
    
  dataConsume1: dataConsume
    port map (
      clk => clk,
      reset => reset,
      start => start,
      numWords_bcd => numWords,
      ctrlIn => ctrl_genDriv,
      ctrlOut => ctrl_consDriv,
      data => readData,
      dataReady => dataReady,
      byte => curByte,
      seqDone => seqDone,
      maxIndex => maxIndex,
      dataResults => dataResults
    );
 end test;