/*
-------------
Upon being enabled, I2S_interface will start reading a raw PCM data
from given starting address and using it to output formatted I2S 
as required by the SGTL5000.
-------------
*/
module I2S_interface_R2 (
	input 	logic clk50,
	input 	logic reset,
	// input 	logic run,
	//inputs for muxing
	
	output 	logic [24:0]	ADDR_PRGM, //address for read to program. Formatted as 1 address space per 16 bits.
	input  	logic [15:0]	RDdata_PRGM, //data for read to program
	output 	logic RDen,					 //read enable from program. 
	input 	logic avalon_bridge_acknowledge,
	
	
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
	
	// logic LRCLK_state; //used to determine when LRCLK changes edge for reading
	// logic [5:0]  load_counter; //  = 5'b11111; 
	// logic [15:0] RDdata_buffer; // = 0; //to store result after a read
	// logic [24:0] ADDR_current; // = 25'h13C;	//0
	// logic [4:0]  write_counter; //  = 16;
	// logic endian = 1;
	
	assign hex_out_0 = READ_ADDR[3:0];
	assign hex_out_1 = READ_ADDR[7:4];
	assign hex_out_2 = READ_ADDR[11:8];
	assign hex_out_3 = READ_ADDR[15:12];
	assign hex_out_4 = READ_ADDR[19:16];
	assign hex_out_5 = READ_ADDR[23:20];

	parameter BIT_DEPTH = 16;	// Assume this much, lol. We don't have a good way to deal with it otherwise!
	parameter VOLUME_SHIFT = 6; // how many bits to shift to preserve hearing?

	enum logic [12:0] 
    {q_shift, 
    q_shift_release, 
    q_prefetch,
    q_prefetch_release,
    q_load1, 
    q_load1_wait, 
    q_load2, 
    q_load2_wait, 
    q_load3, 
    q_load3_wait
    } queue_state, q_nextstate;

	logic [24:0]    READ_ADDR, READ_ADDR_NEXT;  // current address of read from buffer.
	// logic [15:0]    READ_WORD;  // word to load into queue
	logic [5:0]     SHIFTCOUNT, SHIFTCOUNT_NEXT; // keeps track of how many shifts happened.
	logic [47:0]    BITQUEUE, BITQ_NEXT;    // queue of bits coming in
	logic Q_RDY; // Is the queue safe to read from? 

	// Values for Ram buffering logic
	logic RAM_DATA_BUFFER_EN; // Flag for enabling the RAM_DATA_BUFFER.
	// logic RAM_DATA_RDEN;	// RDEN for the ram buffering logic... synonymous with the state it seems
	reg RAM_DATA_BUFFER_STATE; // Buffered state for operation of RAM data buffer. 
	logic [15:0]    RAM_BUFFERED_READBACK;

	// Ram readback buffering mechanism - makes sure we don't miss data.
	always_ff @ (posedge clk50 or posedge reset)
	begin
		if(reset)
		begin
			// RAM_DATA_RDEN <= 1'b0;
			RAM_BUFFERED_READBACK <= 16'h0;
			RAM_DATA_BUFFER_STATE <= 1'b0;  // state: inactive
		end
		else if(RAM_DATA_BUFFER_STATE)  // If active state...
		begin
			// RAM_DATA_RDEN <= 1'b1;
			if(avalon_bridge_acknowledge) begin
				RAM_BUFFERED_READBACK <= RDdata_PRGM;
				RAM_DATA_BUFFER_STATE <= 1'b0; // go back to inactive/unarmed state.
			end
		end
		else	// Inactive state
			// RAM_DATA_RDEN <= 1'b0;
			RAM_DATA_BUFFER_STATE <= RAM_DATA_BUFFER_EN;    // Wait to be activated.
	end

	logic RDEN_override;
	// assign RAM_DATA_RDEN = RAM_DATA_BUFFER_STATE;
	assign RDen = (RAM_DATA_BUFFER_STATE |RDEN_override);

	always_ff @ (posedge clk50 or posedge reset)
	begin
		if(reset)
		begin
			BITQUEUE <= 48'h0;
			SHIFTCOUNT <= 6'h0;
			queue_state <= q_load3;
			READ_ADDR <= 25'h0A;    // A gets us to byte d20, which determines datatype
		end
		else if(I2S_enable)
		begin
			BITQUEUE <= BITQ_NEXT;
			SHIFTCOUNT <= SHIFTCOUNT_NEXT;
			queue_state <= q_nextstate;
			READ_ADDR <= READ_ADDR_NEXT;
		end
	end

	always_comb 
	begin
		// default values: 
		BITQ_NEXT = BITQUEUE;       // queue doesnt move
		READ_ADDR_NEXT = READ_ADDR; // addr doesnt change
		SHIFTCOUNT_NEXT = SHIFTCOUNT;   // shift-counter stays
		ADDR_PRGM = READ_ADDR;       // Pre-set the ram address
		RDEN_override = 1'b0; 
		q_nextstate = queue_state;  // stay in current state
		// status_1 = 1'b0;    // lights - blank em 
		// status_2 = 1'b0;
		Q_RDY = 1'b0;   // Assume the queue's NOT READY unless otherwise stated.
		RAM_DATA_BUFFER_EN = 1'b0;  // Ram buffering mechanism assumes no incoming data.


		case (queue_state)
			q_shift: begin
				Q_RDY = 1'b1;
				if(shiftsig)
					q_nextstate = q_shift_release;
			end
			q_shift_release :   // TEMP STATE release for testing, should be q_shift_load
			begin
				Q_RDY = 1'b1;
				if(~shiftsig)
				begin
					q_nextstate = q_shift;              // TESTING PURPOSE!
					BITQ_NEXT = BITQUEUE << 1;          // shift the bitqueue, should be 1, 4 to test
					SHIFTCOUNT_NEXT = SHIFTCOUNT + 1;   // shift count increments, should be 1 (4 to test)
					if(SHIFTCOUNT_NEXT >= 1) begin     // Note that since we're in a COMB thus must use shiftcount_next!
						q_nextstate = q_prefetch;  // we need to top up the queue. 
						// RDen = 1'b1;        // Call upon RAM to send data.
						// ADDR_PRGM = READ_ADDR;
						RAM_DATA_BUFFER_EN = 1'b1;  // Arm the RAM readback data buffer
						// status_1 = 1'b1;
						// SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
						// Q_RDY = 1'b0;  // Un-ready the queue!
					end
				end
			end
			q_prefetch: begin
				Q_RDY = 1'b1;
				// RDen = 1'b1;
				// status_1 = 1'b1;
				if(shiftsig)
					q_nextstate = q_prefetch_release;
			end
			q_prefetch_release: begin
				Q_RDY = 1'b1;
				// RDen = 1'b1;
				// status_1 = 1'b1;
				if(~shiftsig)
				begin
					q_nextstate = q_prefetch;              // TESTING PURPOSE!
					BITQ_NEXT = BITQUEUE << 1;          // shift the bitqueue, should be 1, 4 to test
					SHIFTCOUNT_NEXT = SHIFTCOUNT + 1;   // shift count increments, should be 1 (4 to test)
					if(SHIFTCOUNT_NEXT >= 16) begin // If the buffer has disarmed, it must have caught data
						q_nextstate = q_shift;  // we should be clear to return to normal operation.
						// RDen = 1'b0;    // let the RAM rest
						BITQ_NEXT[15:0] = RAM_BUFFERED_READBACK[15:0];    // PCM is Little-Endian - no flip needed.
						// BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
						READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
						SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
					end
				end
			end
			q_load1 : begin // load 1st word - most common
				// RDen = 1'b1;        // Call upon RAM to send data.
				// ADDR_PRGM = READ_ADDR;
				RAM_DATA_BUFFER_EN = 1'b1;  // Arm the RAM readback data buffer
				// status_1 = 1'b1;
				q_nextstate = q_load1_wait;
			end
			q_load1_wait : begin
				// RDen = 1'b1;        // Call upon RAM to send data.
				// ADDR_PRGM = READ_ADDR;
				if(RAM_DATA_BUFFER_STATE == 1'b0) begin // If the buffer has disarmed, it must have caught data
					q_nextstate = q_shift;  // we should be clear to return to normal operation.
					// RDen = 1'b0;    // let the RAM rest
					BITQ_NEXT[15:0] = RAM_BUFFERED_READBACK[15:0];    // little-vs-big-endian tomfoolery
					// BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
					READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
				end
				// otherwise, we keep waiting, lol.
			end
			q_load3 : begin // load 3rd word
				RDEN_override = 1'b1;
				// ADDR_PRGM = READ_ADDR;
				if(avalon_bridge_acknowledge) begin
					q_nextstate = q_load3_wait;
					BITQ_NEXT[47:32] = RDdata_PRGM[15:0];    // little-vs-big-endian tomfoolery necessary for video
					// BITQ_NEXT[39:32] = RDdata_PRGM[15:8];	// Tomfooleren't with PCM!
					READ_ADDR_NEXT = READ_ADDR + 1;
				end
				// status_1 = 1'b1;
			end
			q_load3_wait    : begin // wait for bus to settle
				if(avalon_bridge_acknowledge == 1'b0)begin
					q_nextstate = q_load2;
				end
				// status_1 = 1'b1;
			end
			q_load2  :  // load 2nd word
			begin
				RDEN_override = 1'b1;
				// ADDR_PRGM = READ_ADDR;
				if(avalon_bridge_acknowledge) begin
					q_nextstate = q_load2_wait;
					BITQ_NEXT[31:16] = RDdata_PRGM[15:0];
					// BITQ_NEXT[23:16] = RDdata_PRGM[15:8];
					READ_ADDR_NEXT = READ_ADDR + 1;
				end
			end
			q_load2_wait    : begin // wait for bus to settle
				if(avalon_bridge_acknowledge == 1'b0)begin
					q_nextstate = q_load1;
				end
			end
			default: ;
		endcase
	end


	

	always_ff @( posedge clk50 or posedge reset ) begin
		if(reset) begin
			shiftsig <= 1'b0;
		end
		else begin
			shiftsig <= shiftsig_next;
		end
	end

	enum logic [7:0] 
    {start_determine_type,
	pcm_start_wait,
	IMA_ADPCM_start_wait,
	left_dummy,
	left_data,
	left_pad,
	right_dummy,
	right_data,
	right_pad
    } I2S_STATE, I2S_nextstate;

	logic shiftsig, shiftsig_next;
	logic saved_sign_bit, next_sign_bit;
	logic LRCLK_saved, LRCLK_next;
	logic I2S_go, I2S_go_next;
	logic [8:0] I2S_counter, I2S_count_next;

	always_comb begin
		// default values;
		I2S_DIN = 1'b0;
		// shiftsig_next = 1'b0;
		I2S_count_next = I2S_counter;
		I2S_nextstate = I2S_STATE;
		next_sign_bit = saved_sign_bit;
		shiftsig_next = 1'b0;
		I2S_go_next = 1'b0;
		if(Q_RDY & I2S_enable) begin
			case (I2S_STATE)
				start_determine_type : begin
					I2S_count_next = 0;
					case (BITQUEUE[47:32])	// These are endian-ness flipped due to wav stupidity.
						16'h0001 : I2S_nextstate = pcm_start_wait;
						16'h0011 : I2S_nextstate = IMA_ADPCM_start_wait;
						default: ;
					endcase			
				end
				pcm_start_wait : begin
					if(I2S_counter < 9'd192) begin	// 192 bit-shifts to get into starting position.
						shiftsig_next = I2S_SCLK;
						I2S_count_next = I2S_counter + 1;
					end
					else begin
						if(~I2S_LRCLK & LRCLK_saved) begin	// If just changed to right from left
							I2S_go_next = 1'b1;
						end
					end
					if(I2S_go) begin	// this is necessary due to the above condition failing to persist...
						I2S_count_next = 0;
						I2S_nextstate = left_data;
					end
				end
				left_dummy : begin
					I2S_DIN = 1'b0;
					I2S_nextstate = left_data;
				end
				left_data : begin
					I2S_DIN = BITQUEUE[47];
					if(I2S_counter >= VOLUME_SHIFT) begin
						shiftsig_next = I2S_SCLK; 	// This should end up shifting right on time.
						// Only shift if we are above the volume.
						// Should also nicely sign-extend when reducing amplitude.
					end
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter == 0) begin
						next_sign_bit = BITQUEUE[47];
					end
					else if(I2S_counter >= 31) begin	// This shouldn't happen, will probably screw up.
						I2S_count_next = 0;
						I2S_nextstate = right_dummy;
					end
					else if (I2S_counter >= (BIT_DEPTH + VOLUME_SHIFT - 1)) begin
						I2S_count_next = 0;
						I2S_nextstate = left_pad;
					end
				end
				left_pad : begin	// Should pad regardless of volume shift.
					I2S_count_next = 0;
					I2S_DIN = saved_sign_bit;
					if(I2S_LRCLK & (~LRCLK_saved)) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = right_data;
					end
				end
				right_dummy : begin
					I2S_DIN = 1'b0;
					I2S_nextstate = right_data;
				end
				right_data : begin
					I2S_DIN = BITQUEUE[47];
					if(I2S_counter >= VOLUME_SHIFT) begin
						shiftsig_next = I2S_SCLK; 	// This should end up shifting right on time.
						// Only shift if we are above the volume.
					end
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter == 0) begin
						next_sign_bit = BITQUEUE[47];
					end
					else if(I2S_counter >= 31) begin
						I2S_count_next = 0;
						I2S_nextstate = left_dummy;
					end
					else if (I2S_counter >= (BIT_DEPTH + VOLUME_SHIFT - 1)) begin
						I2S_count_next = 0;
						I2S_nextstate = right_pad;
					end
				end
				right_pad : begin
					I2S_count_next = 0;
					I2S_DIN = saved_sign_bit;
					if((~I2S_LRCLK) & LRCLK_saved) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = left_data;
					end
				end
				default: ;
			endcase
		end
	end

	always_ff @ (posedge I2S_SCLK or posedge reset) begin
		if(reset) begin
			LRCLK_saved <= 1'b0;
			I2S_counter <= 9'b0;
			saved_sign_bit <= 1'b0;
			// I2S_go <= 1'b0;
		end
		else begin
			// I2S_go <= I2S_go_next;
			LRCLK_saved <= I2S_LRCLK;
			I2S_counter <= I2S_count_next;
			saved_sign_bit <= next_sign_bit;
		end
	end

	// Attempt to make the logic more robust by having the go signal persist on a counter. 
	logic [5:0] go_counter;

	always_ff @ (posedge clk50 or posedge reset) begin
		if (reset) begin
			I2S_go <= 1'b0;
			go_counter <= 6'd0;
		end
		else if (I2S_go_next) begin
			go_counter <= 6'd32;
			I2S_go <= 1'b1;
		end
		else begin
			if(go_counter > 0) begin
				I2S_go <= 1'b1;
				go_counter <= go_counter - 1;
			end
			else begin
				I2S_go <= 1'b0;
			end
		end
	end

	always_ff @ (negedge I2S_SCLK or posedge reset) begin
		if(reset) begin
			// LRCLK_saved <= 1'b0;
			// I2S_DIN <= 1'b0;
			I2S_STATE <= start_determine_type;
		end
		else if(Q_RDY & I2S_enable) begin
			// LRCLK_saved <= LRCLK_next;
			I2S_STATE <= I2S_nextstate;
			// I2S_DIN <= I2S_DIN_next;
		end
	end

	
endmodule