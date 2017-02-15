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
	data: in std_logic_vector(7 downto 0);
	valid: in std_logic;
	oe: in std_logic;
	fe: in std_logic;
	--Ports between cmdProc and Tx
	data: out std_logic_vector(7 downto 0);
	txNow: out std_logic;
	txDone: in std_logic;
 
 
 
