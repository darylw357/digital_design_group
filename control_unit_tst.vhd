----------------------------------------------------------------------------
--	UART_RX_CTRL.vhd -- UART Data Transfer Receiver
----------------------------------------------------------------------------
-- Author:  Dinesh Pamunuwa
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	This component demonstrates the use of the Tx and Rx over a UART device. 
-- Any input typed on the terminal will be echoed. 
-- Requires a serial link that operates on the RS232 protocol with:
--         *9600 Baud Rate
-- 		      *1 start bit, 0
--         *8 data bits, LSB first
--         *1 stop bit, 1
--         *no parity
--         				
-- In this example, the output of the Rx is directly connected to the input 
-- of the Tx, and a state machine manages the control signals to the Rx and 
-- Tx.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Version:			1.0
-- Revision History:
--  08/01/2013 (Dinesh): Created using Xilinx Tools 14.2 for 64 bit Win
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

package state_pack is
	type STATE_NAME is
		(
			INIT,
			START_TRANSMIT,
			TRANSMIT_DATA
		);

	type LOGICAL is (TRUE, FALSE);
end state_pack;

library ieee;
use work.state_pack.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit_tst is
	port (
		clk:		in std_logic; -- system clock
		clear:		in std_logic; -- asynchronous reset
		reset:		in std_logic; -- synchronous reset
		rxNow:		in std_logic; -- data ready signal from Rx
		rx:			in std_logic_vector (7 downto 0); -- parallel data in
		tx:			out std_logic_vector (7 downto 0); -- parallel data out
		rxDone:		out std_logic; -- data read complete signal to Rx
		ovrErr:		in std_logic; -- overrun error (not used in this implementation)
		framErr:	in std_logic; -- frame error  (not used in this implementation)
		txNow:		out std_logic; -- data ready signal to Tx
		txDone:		in std_logic	 -- data transmission complete signal from Tx
	);
end;
	
architecture control_unit_arch of control_unit_tst is
	signal curState, nextState : state_name;
begin 
	

	nextStateLogic:	process (curState, rxNow, txDone)
	begin
		-- assign defaults at the beginning to avoid having to assign in every branch
		txNow <= '0';
		rxDone <= '0';
		case curState is
			when INIT =>
			  if rxNow = '1' then -- Rx signals that data is ready
				  nextState <= START_TRANSMIT;
				else 
				  nextState <= INIT;
				end if;  
			-- START_TRANSMIT is necessary to assert txNow and rxDone for 1 cycle
			-- It also gives 1 cycle for the Tx to deassert (take low) the txDone
			-- signal so that it can be monitored in TRANSMIT_DATA for completion 
			-- of transmission of current word
			when START_TRANSMIT => 
				txNow <= '1';
				rxDone <= '1';
				nextState <= TRANSMIT_DATA;
			when TRANSMIT_DATA =>
			  if txDone = '1' then -- wait for Tx to signal that transmission is complete
					nextState <= INIT;
				else
					nextState <= TRANSMIT_DATA;
      		end if;
			when others => -- should never be reached
				nextState <= INIT;
		end case;
	end process;
	
	stateRegister:	process (clk, clear)
	begin
		if (clear = '1') then -- asynchronous reset
			curState <= INIT;
		elsif rising_edge (clk) then
			if (reset = '1') then -- synchronous reset
				curState <= INIT;
			else
				curState <= nextState;
			end if;
		end if;
	end process;
	
	-- Directly connect output from Rx to input of Tx
	tx <= rx;
	
end;
