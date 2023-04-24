/*
-------------
Upon being enabled, I2S_interface will start reading a raw PCM data
from given starting address and using it to output formatted I2S 
as required by the SGTL5000.
-------------
*/
module I2S_interface (
	input  logic clk50,
	input  logic reset,
	//inputs for muxing
	
	output logic [24:0]	ADDR_PRGM, //address for read to program. Formatted as 1 address space per 16 bits.
	input  logic [15:0]	RDdata_PRGM, //data for read to program
	output logic RDen,					 //read enable from program. 
	input logic avalon_bridge_acknowledge,
	
	
	output logic I2S_DIN, //data input
	input  logic I2S_LRCLK, //frame clock (input from master mode, 44.1 kHz)
	input  logic I2S_SCLK, //bit clock (input from master mode, 64 * frame  clk rate)
	
	
	input  logic ADDR_load, // enable loading ADDR_start, not implemented for now
	input  logic I2S_enable,
	input  logic [24:0] ADDR_start, //address to start sequentially reading from, not implemented for now
	output logic [3:0] hex_out_5,
    output logic [3:0] hex_out_4,
	output logic [3:0] hex_out_3,
	output logic [3:0] hex_out_2,
	output logic [3:0] hex_out_1,
	output logic [3:0] hex_out_0
	);
	assign hex_out_0 = ADDR_current[3:0];
	assign hex_out_1 = ADDR_current[7:4];
	assign hex_out_2 = ADDR_current[11:8];
	assign hex_out_3 = ADDR_current[15:12];
	assign hex_out_4 = ADDR_current[19:16];
	assign hex_out_5 = ADDR_current[23:20];
	
	logic LRCLK_state; //used to determine when LRCLK changes edge for reading
	logic [5:0]  load_counter; //  = 5'b11111; 
	logic [15:0] RDdata_buffer; // = 0; //to store result after a read
	logic [24:0] ADDR_current; // = 25'h13C;	//0
	logic [4:0]  write_counter; //  = 16;
	logic endian = 0;
	
	parameter BIT_DEPTH = 16;
							
	assign ADDR_PRGM = ADDR_current;
	
	always_ff @ (posedge clk50 or posedge reset) //load 16 bits after a frame clock. 
	begin
		if(reset) begin
			LRCLK_state <= 0;
			load_counter <= 5'b11111;	// dont know what the hell this is - jason
			RDdata_buffer <= 16'h0;	// zero the read buffer
			ADDR_current <= 25'h9E;	// starting location in memory
			RDen <= 1'b0;
		end
		else if (I2S_enable) begin
			LRCLK_state <= LRCLK_state;
			load_counter <= load_counter;
			RDdata_buffer <= RDdata_buffer;
			ADDR_current <= ADDR_current;
			// write_counter <= write_counter;
			RDen <= 1'b1;
			if(I2S_enable)//enable simply loads ADDR_start
			begin
				//if (ADDR_load) ADDR_current <= ADDR_start;
				if (LRCLK_state == 1'b0 && I2S_LRCLK == 1'b1) //rising edge
					begin
						LRCLK_state <= 1'b1;
						load_counter <= 0; //reset counter to zero and start read
						//RDen <= 1'b1;
					end
				else if (LRCLK_state == 1'b1 && I2S_LRCLK == 1'b0) //falling edge
					begin
						LRCLK_state <= 1'b0;
						load_counter <= 0; //reset counter to zero and start read
						//RDen <= 1'b1;
					end
				else if(load_counter == 5'b00110) //not rising or falling, after 14 cycles for the delay on SDRAM, data loaded into buffer
					begin
						if(endian == 0)
							begin
								RDdata_buffer[15] <= RDdata_PRGM[15];
								RDdata_buffer[14] <= RDdata_PRGM[15]; //add to buffer to free up memory
								RDdata_buffer[13] <= RDdata_PRGM[15];
								RDdata_buffer[12] <= RDdata_PRGM[15];
								RDdata_buffer[11:0] <= ((RDdata_PRGM) >> 4);
								// RDdata_buffer <= RDdata_PRGM;
							end
						else
							begin
								RDdata_buffer[7:0] <= (RDdata_PRGM[15:8] + 8'd127);
								// RDdata_buffer[7:0]  <= 8'h0;
								// RDdata_buffer[15:8] <= RDdata_PRGM[7:0];
								RDdata_buffer[15:8] <= 8'h0;
							end
						
						load_counter <= load_counter + 1;
						ADDR_current <= ADDR_current + 1;
						//RDen <= 1'b0;
						//write_counter <= 0; //start writing bits on the bit clock
					end
				else if(load_counter >= 5'b11111) //do nothing, reached the end cycle
					begin
					end
				else // counter is less than 14 cycles, wait
					begin
						load_counter <= load_counter + 1;
					end
			end
			else
			begin
				LRCLK_state <= I2S_LRCLK;
			end
		end
	end
	
	always_ff @ (negedge I2S_SCLK or posedge reset)
	begin
		if(reset) begin
			write_counter <= 5'd16;
			I2S_DIN <= 1'b0;
		end
		else begin
			I2S_DIN <= 1'b0;
			write_counter <= write_counter;
			
			if(I2S_enable) //we know that it is past the first cycle 
			begin
				if(load_counter >= 10 && load_counter <= 20)
					begin
						write_counter <= 1; //write bit on changing edge, note this does not update the state so clk50 can take care of it
						//note: set to 1 because need to write on first cycle
						
						//write the very first bit
						// I2S_DIN <= RDdata_buffer[0]; //replace write_counter with (BIT_DEPTH - write_counter - 1) for other direction
						I2S_DIN <= RDdata_buffer[15];
					end
					
					
				if (write_counter < BIT_DEPTH) //write bit by bit (otherwise still zero-pad)
					begin
						// I2S_DIN <= RDdata_buffer[write_counter]; //replace write_counter with (BIT_DEPTH - write_counter - 1) for other direction
						I2S_DIN <= RDdata_buffer[15 - write_counter];
						write_counter <= write_counter + 1;
					end
				else begin
					I2S_DIN <= RDdata_buffer[15];
				end
			end
		end
	end
	
	always_comb
	begin
		
	end

endmodule