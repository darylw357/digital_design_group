----------------------------------------------------------------------------
--	dataGen.vhd -- Data Generator that will retrieve data according to a 
--                2-phse signalling protocol
----------------------------------------------------------------------------
-- Author:  Dinesh Pamunuwa
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- The code in this component should not be changed.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Version:			1.0
-- Revision History:
--  09/02/2014 (Dinesh): Created using Xilinx ISE for 64-bit win
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;

entity dataGen is
	port (
		clk:		in std_logic;
		reset:		in std_logic; -- synchronous reset
		ctrlIn: in std_logic;
		ctrlOut: out std_logic;
		data: out std_logic_vector(7 downto 0)
	);
end dataGen;

architecture behav of dataGen is
  
  signal ctrlIn_delayed, ctrlIn_detected, ctrlOut_reg: std_logic;
  signal index: integer range 0 to SEQ_LENGTH;
begin
  
  delay_CtrlIn: process(clk)     
  begin
    if rising_edge(clk) then
      ctrlIn_delayed <= ctrlIn;
    end if;
  end process;
  
  ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;
  
  count: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        index <=0;
        ctrlOut_reg <= '0';
      else
        if ctrlIn_detected = '1' then
  	   		  ctrlOut_reg <= not ctrlOut_reg;
  	   		  if index = SEQ_LENGTH then
        		  index <= 1;
      		  else
            index <= index + 1;
    				  end if;	
        end if;
      end if;
    end if;
  end process;
  
  data <= X"DD" when index=0 else dataSequence(index-1);
  ctrlOut <= ctrlOut_reg;
end behav;


