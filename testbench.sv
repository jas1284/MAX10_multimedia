module testbench();

timeunit 10ns;	// Half clock cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;

// These signals are internal because the processor will be 
// instantiated as a submodule in testbench.

logic clk50;
logic run;  // enable-run, or halts
logic reset;
logic key;
// SDRAM connections
logic ram_rden;
logic [24:0] ram_addr;
logic [15:0] ram_data;
logic ram_ack;
logic status_1;
logic status_2;   
// logic [47:0] vidasic.BITQUEUE;
// logic vidasic.queue_state;
// logic vidasic.q_nextstate;
// VGA connections
logic [3:0] red;
logic [3:0] green;
logic [3:0] blue;
logic hsync;
logic vsync;
logic [3:0] hex_out_5;
logic [3:0] hex_out_4;
logic [3:0] hex_out_3;
logic [3:0] hex_out_2;
logic [3:0] hex_out_1;
logic [3:0] hex_out_0;


// To store expected results
// logic [15:0] ans_example, ans_pp, ans_pn, ans_np, ans_nn;
				
// A counter to count the instances where simulation results
// do no match with expected results
integer ErrorCnt = 0;
		
// Instantiating the DUT
// Make sure the module and signal names match with those in your design
vidasic_top vidasic(.*);	

// Toggle the clock
// #1 means wait for a delay of 1 timeunit
always begin : CLOCK_GENERATION
#1 clk50 = ~clk50;
end

initial begin: CLOCK_INITIALIZATION
    clk50 = 0;
end 

initial begin: TEST_LOAD
#1  key = 1'b0;
#1  reset = 1'b1;
#1  reset = 1'b0;

#2  run = 1'b1;
#5  ram_ack = 0;
#10 ram_data = 16'h3449;
    ram_ack = 1'b1;

#3  ram_ack = 1'b0;

#5  ram_data = 16'h7220;
    ram_ack = 1'b1;

#3  ram_ack = 1'b0;

#5  ram_data = 16'h13C1;
    ram_ack  = 1'b1;

#3  ram_ack = 1'b0;

// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1 key = 1'b1;
// #1 key = 1'b0;
// #1
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2 key = 1'b0;
#2 key = 1'b1;
#2  ram_data = 16'hB0F0;
    ram_ack  = 1'b1;
    key = 1'b0;
#2  key = 1'b1;
#3  ram_ack = 1'b0;
#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

#3 key = 1'b1;
#3 key = 1'b0;

end

endmodule