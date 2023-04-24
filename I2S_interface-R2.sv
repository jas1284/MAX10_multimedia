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
	input  logic [24:0] ADDR_start //address to start sequentially reading from, not implemented for now
	);
	
	// logic LRCLK_state; //used to determine when LRCLK changes edge for reading
	// logic [5:0]  load_counter; //  = 5'b11111; 
	// logic [15:0] RDdata_buffer; // = 0; //to store result after a read
	// logic [24:0] ADDR_current; // = 25'h13C;	//0
	// logic [4:0]  write_counter; //  = 16;
	// logic endian = 1;
	
	parameter BIT_DEPTH = 16;
							

	// Values for Ram buffering logic
	logic RAM_DATA_BUFFER_EN; // Flag for enabling the RAM_DATA_BUFFER.
	logic RAM_DATA_BUFFER_STATE; // Buffered state for operation of RAM data buffer. 
	logic [15:0]    RAM_BUFFERED_READBACK;
	// Ram readback buffering mechanism - makes sure we don't miss data.
	always_ff @ (posedge clk50 or posedge reset)
	begin
		if(reset)
		begin
			RAM_BUFFERED_READBACK <= 16'h0;
			RAM_DATA_BUFFER_STATE <= 1'b0;  // state: inactive
		end
		else if(RAM_DATA_BUFFER_STATE)  // If active state...
		begin
			if(ram_ack) begin
				RAM_BUFFERED_READBACK <= ram_data;
				RAM_DATA_BUFFER_STATE <= 0; // go back to inactive/unarmed state.
			end
		end
		else
			RAM_DATA_BUFFER_STATE <= RAM_DATA_BUFFER_EN;    // Wait to be activated.
	end

	logic [24:0]    READ_ADDR, READ_ADDR_NEXT;  // current address of read from buffer.
	logic [15:0]    READ_WORD;  // word to load into queue
	logic [15:0] 	OUTPUT_WORD, OUTPUT_WORD_NEXT;	 // word to be output; Signed, 16 bit, little endian!
	logic [5:0]     SCLK_COUNT, SCLK_COUNT_NEXT; // keeps track of how many SCLKS happened.


	assign ADDR_PRGM = READ_ADDR;

	enum logic [12:0] 
    {q_shift, 
    q_shift_release, 
    q_fetch,
	q_fetch_wait
    } queue_state, q_nextstate;

	always_ff @ (posedge clk50 or posedge reset) begin
		if(reset) begin
			READ_ADDR <= 25'h4f;	// Starting address of "4f" in words -> byte address 13C.
			// OUTPUT_WORD <= 25'h0;	// start with a clean slate
			SCLK_COUNT <= 6'h0;		// Count up when shifting...
			queue_state = q_fetch;
		end
		else if(I2S_enable) begin
			READ_ADDR <= READ_ADDR_NEXT
			// OUTPUT_WORD <= OUTPUT_WORD_NEXT;
			SCLK_COUNT <= SCLK_COUNT_NEXT;
			queue_state <= q_nextstate;
		end
	end

	always_comb begin
		q_nextstate = queue_state;
		READ_ADDR_NEXT = READ_ADDR;
		SCLK_COUNT_NEXT = SCLK_COUNT;
		RDen = 1'b0;
		RAM_DATA_BUFFER_EN = 1'b0;
		case (queue_state)
			q_fetch:  begin
				RAM_DATA_BUFFER_EN = 1'b1;
				RDen = 1'b1;
				q_nextstate = q_fetch_wait;
			end
			q_fetch_wait: begin
				RDen = 1'b1;
				if(~RAM_DATA_BUFFER_STATE)	begin	// if the buffer caught something
					
				end
			end
			default: ;
		endcase

	end

	always_ff @ (negedge I2S_SCLK or posedge reset) begin
		if(reset) begin
			I2S_DIN <= 1'b0;
		end
		else if(I2S_enable) begin
			if(SCLK_COUNT == 0) begin
				I2S_DIN <= 1'b0;
				PADDING_SENT <= 1'b1;
			end
			else if (SCLK_COUNT_NEXT >= 16)
			I2S_DIN <= OUTPUT_WORD[15];
			OUTPUT_WORD <= OUTPUT_WORD_NEXT;
		end
	end

	
endmodule