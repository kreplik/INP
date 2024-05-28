-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
 ------------------------------------------------

    --PC----
    signal pc_reg: std_logic_vector(12 downto 0) := (others => '0');
    signal pc_inc: std_logic := '0';
    signal pc_dec: std_logic := '0';
    --PC--

    --CNT--
    signal cnt_reg: std_logic_vector(12 downto 0) := (others => '0');
    signal cnt_inc: std_logic;
    signal cnt_dec: std_logic;
    --CNT--

    --PTR--
    signal ptr_reg: std_logic_vector(12 downto 0) := (others => '0');
    signal ptr_inc: std_logic := '0';
    signal ptr_dec: std_logic := '0';
    --PTR--

    --MUX1--
    signal sel2: std_logic_vector(1 downto 0);
    signal mux2_out: std_logic_vector(7 downto 0);
    --MUX1--

    --STATE--
    type fsm_state is
        ( START,FETCH,DECODE, s_pointer_inc,
          s_pointer_dec,
	  s_pointer_dec_n,
	  s_pointer_dec_f,
          s_while_start,
          s_program_inc,
          s_program_dec,
	  s_pointer_inc_f,
	  s_pointer_inc_n,
	  s_while_start_n,
	  s_while_end_n,
	  s_write,
	  s_write_n,
	  s_write_f,
	  s_read,
	  s_read_n,
	  s_others,
	  s_null,
	  s_while_n,
	  s_while_cond,
	  e_while_start,
	  e_while_n,
	  e_while_cond,
	  e_while_cond2,
	  do_while_start,
	  do_while_end,
	  do_while_cond,
	  do_while_cond2,
	  do_while_cond3
        );
        signal state: fsm_state := START; 
        signal n_state: fsm_state;
    --STATE--
 ------------------------------------------------
begin
--PC_CNTR    
    pc_cntr: process (RESET, CLK, pc_inc, pc_dec) is begin
        if (RESET='1') then
           pc_reg <= (others=>'0');
        elsif (CLK'event) and (CLK = '1') then
            if (pc_inc='1') then
                pc_reg <= pc_reg + 1;
            elsif (pc_dec='1') then
                pc_reg <= pc_reg - 1;   
           end if;
        end if;
     end process pc_cntr;
--PC_CNTR--     

--CNT--
cnt: process (RESET, CLK,cnt_inc, cnt_dec) is begin
    if (RESET='1') then
       cnt_reg <= (others=>'0');
    elsif (CLK'event) and (CLK = '1') then
       
        if (cnt_inc='1') then
            cnt_reg <= cnt_reg + 1;
        elsif (cnt_dec='1') then
            cnt_reg <= cnt_reg - 1;   
        end if;
    end if;
 end process cnt;
--CNT--

--PTR--
ptr: process (RESET, CLK, ptr_inc, ptr_dec) is
 begin
    if (RESET='1') then
       ptr_reg <= "1000000000000";
    elsif (CLK'event) and (CLK = '1') then
        if (ptr_inc='1') then
	if(ptr_reg = "1111111111111") then
	ptr_reg <= "1000000000000";
	else
	ptr_reg <= ptr_reg + 1;
	end if;
	elsif (ptr_dec='1') then
	if (ptr_reg = "1000000000000") then
	ptr_reg <= "1111111111111";
	else 
       ptr_reg <= ptr_reg - 1;
	end if;
	end if;
    end if;
 end process ptr;
--PTR--

--MUX2--
mux2: process(CLK, sel2, RESET, pc_reg, ptr_reg)
begin
	if(RESET = '1') then
		mux2_out <= (others => '0');
	else if(CLK'event) and (CLK = '1') then
	case sel2 is		
		 when "00" =>
			mux2_out <= IN_DATA;
		when "01" =>
			mux2_out <= DATA_RDATA + 1;
		when "10" => 
			mux2_out <= DATA_RDATA - 1;
		when others =>
			 mux2_out <= (others => '0');
	end case;
	end if;
	end if;
DATA_WDATA <= mux2_out;
end process mux2;	
--MUX2--
--STATE--

fsm_p_state: process (CLK, RESET, EN) is
    begin
        if (RESET='1') then
            state <= START;
        elsif (CLK'event) and (CLK = '1') then
            if (EN='1') then
                state <= n_state;
            end if;        
        end if;    
    end process fsm_p_state;

--STATE

--FSM--
fsm_n_state: process (state, IN_VLD, OUT_BUSY, DATA_RDATA)
    begin
	cnt_dec <= '0';
	cnt_inc <= '0';
        pc_dec <= '0';
        pc_inc <= '0';
        ptr_dec <= '0';
        ptr_inc <= '0';
        DATA_EN <= '0';
        IN_REQ <= '0';
        OUT_WE <= '0';
	DATA_RDWR <= '0';
	sel2 <= "00";
	case state is
		when START =>
			n_state <= FETCH;
		when FETCH =>
			DATA_EN <= '1';
			DATA_ADDR <= pc_reg;
			n_state <= DECODE;
		when DECODE =>
			
       			 case DATA_RDATA is
           			 when X"3E" =>
               				 n_state <= s_program_inc;
           			 when X"3C" =>
               				 n_state <= s_program_dec;
           			 when X"2B" =>
               				 n_state <= s_pointer_inc;
           			 when X"2D" =>
               				 n_state <= s_pointer_dec;  
           			 when X"2E" =>
               				 n_state <= s_write;
				 when X"2C" =>
					 n_state <= s_read;
           			 when X"5B" =>
               				 n_state <= s_while_start;
           			 when X"5D" =>
               				 n_state <= e_while_start;              
	   			 when X"00" =>
					n_state <= s_null;
			 	 when X"28" =>
					n_state <= do_while_start;
				 when X"29" =>
					n_state <= do_while_end;
				 when others => 
					n_state <= s_others;
       			 end case;
		when s_program_inc =>
			ptr_inc <= '1';	
			pc_inc <= '1';
			
			n_state <= FETCH;
		when s_program_dec =>
			ptr_dec <= '1';
			pc_inc <= '1';
			n_state <= FETCH;
		when s_pointer_inc =>
			
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= ptr_reg;
			n_state <= s_pointer_inc_n;
		when s_pointer_inc_n =>
			DATA_EN <= '1';
			sel2 <= "01";
			n_state <= s_pointer_inc_f;
		when s_pointer_inc_f =>
			
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			pc_inc <= '1';
			n_state <= FETCH;
		when s_pointer_dec =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= ptr_reg;
			n_state <= s_pointer_dec_n;
		when s_pointer_dec_n =>
			DATA_EN <= '1';
			sel2 <= "10";
					
			n_state <= s_pointer_dec_f;
		when s_pointer_dec_f =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			pc_inc <= '1';
			n_state <= FETCH;
		
		when s_while_start =>
			DATA_ADDR <= ptr_reg;
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= s_while_n;

		when s_while_n =>
			if DATA_RDATA /= "00000000" then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			DATA_ADDR <= pc_reg;
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			pc_inc <= '1';
			n_state <= s_while_cond;
			end if;

		when s_while_cond =>
			if(DATA_RDATA = X"5D") then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			pc_inc <= '1';
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= pc_reg;
			n_state <= s_while_cond;
			end if;

		when e_while_start =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= ptr_reg;
			n_state <= e_while_n;

		when e_while_n =>
			if DATA_RDATA = "00000000" then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			pc_dec <= '1';
			DATA_ADDR <= pc_reg;
			n_state <= e_while_cond;
			end if;
		
		when e_while_cond =>
			if(DATA_RDATA = X"5B") then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			pc_dec <= '1';
			DATA_ADDR <= pc_reg;
			n_state <= e_while_cond2;
			end if;

		when e_while_cond2 =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= e_while_cond;
		when s_write =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= ptr_reg;	
			n_state <= s_write_n;
	
		when s_write_n =>
			if (OUT_BUSY = '1') then
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			DATA_ADDR <= ptr_reg;
			n_state <= s_write_n;
			elsif (OUT_BUSY = '0') then
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= s_write_f;
			end if;

		when s_write_f =>
			OUT_WE <= '1';
			OUT_DATA <= DATA_RDATA;
			pc_inc <= '1';
			n_state <= FETCH;

		when s_read =>
			DATA_ADDR <= ptr_reg;
			IN_REQ <= '1';
			if(IN_VLD /= '1') then
			sel2 <= "00";
			n_state <= s_read;
			else
			n_state <= s_read_n;
			end if;

		when s_read_n =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			pc_inc <= '1';
			n_state <= FETCH;

		when do_while_start =>
			pc_inc <= '1';
			n_state <= FETCH;

		when do_while_end =>
			DATA_ADDR <= ptr_reg;
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= do_while_cond;
		when do_while_cond =>
			if DATA_RDATA = "00000000" then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			pc_dec <= '1';
			DATA_ADDR <= pc_reg;
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= do_while_cond2;
			end if;
		when do_while_cond2 =>
			if(DATA_RDATA = X"28") then
			pc_inc <= '1';
			n_state <= FETCH;
			else
			pc_dec <= '1';
			DATA_ADDR <= pc_reg;
			n_state <= do_while_cond3;	
			end if;
		when do_while_cond3 =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			n_state <= do_while_cond2;
		when s_others =>
			pc_inc <= '1';
			n_state <= FETCH;

		when s_null =>
			n_state <= s_null;

		when others =>
			null;
		
	end case;

    end process fsm_n_state;
--FSM--    
end behavioral;
