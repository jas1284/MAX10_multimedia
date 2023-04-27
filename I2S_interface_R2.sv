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
	
	// assign hex_out_0 = READ_ADDR[3:0];
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
			READ_ADDR <= 25'h00;    // 0x0A gets us to byte d20, which determines datatype
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
    {start_check_RIFF,
	start_skip_RIFF,
	start_determine_type,
	pcm_start_wait,
	pcm_start_wait_zerocount,	// Extra states for properly zeroing out the I2S_counter.
	left_dummy,
	left_data,
	left_pad,
	right_dummy,
	right_data,
	right_pad,
	IMA_ADPCM_start_wait,
	IMA_ADPCM_start_wait_zerocount,
	IMA_ADPCM_left,
	IMA_ADPCM_left_zerocount,
	IMA_ADPCM_right,
	IMA_ADPCM_right_zerocount,
	g711_start_wait,
	g711_start_wait_zerocount,
	g711_left,
	g711_left_zerocount,
	g711_right,
	g711_right_zerocount
    } I2S_STATE, I2S_nextstate;

	logic shiftsig, shiftsig_next;
	logic saved_sign_bit, next_sign_bit;
	logic LRCLK_saved, LRCLK_next;
	logic I2S_go, I2S_go_next;
	logic [8:0] I2S_counter, I2S_count_next;
	logic [5:0] index_counter, index_counter_next;
	logic ADPCM_CALC_L, ADPCM_CALC_R;
	logic [3:0] playback_type, playback_type_next;
	logic g711_law_type, g711_law_type_next;	// 1 indicates u-law

	assign hex_out_0 = playback_type;

	always_comb begin
		// default values;
		I2S_DIN = 1'b0;
		// shiftsig_next = 1'b0;
		I2S_count_next = I2S_counter;
		I2S_nextstate = I2S_STATE;
		next_sign_bit = saved_sign_bit;
		shiftsig_next = 1'b0;
		I2S_go_next = 1'b0;
		ADPCM_CALC_L = 1'b0;
		ADPCM_CALC_R = 1'b0;
		g711_calc = 1'b0;
		playback_type_next = playback_type;
		g711_law_type_next = g711_law_type;
		index_counter_next = index_counter;
		if(Q_RDY & I2S_enable) begin
			case (I2S_STATE)
				start_check_RIFF : begin
					I2S_count_next = 0;
					case (BITQUEUE[47:16])	// These are endian-ness flipped due to wav stupidity.
						32'h49524646 : begin 	// RIFF
							I2S_nextstate = start_skip_RIFF;	// Go on and check type!
							// playback_type_next = 4'h1;	// Playback type display: 1 for basic PCM
						end
						default : begin
							playback_type_next = 4'hA;	// "A" for ADPCM!
							I2S_nextstate = IMA_ADPCM_start_wait_zerocount;	// If anything else, assume is VOX ADPCM
						end
					endcase		
				end
				start_skip_RIFF : begin
					shiftsig_next = I2S_SCLK;
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter >= 9'd160) begin	// 160 bit-shifts to get to format, check if PCM
						I2S_count_next = 0;
						I2S_nextstate = start_determine_type;
					end
				end
				start_determine_type : begin
					I2S_count_next = 0;
					case (BITQUEUE[47:32])	// These are endian-ness flipped due to wav stupidity.
						16'h0001 : begin 
							I2S_nextstate = pcm_start_wait;
							playback_type_next = 4'h1;	// Playback type display: 1 for basic PCM
						end
						16'h0006 : begin
							I2S_nextstate = g711_start_wait;
							playback_type_next = 4'hA;	// "A" for Alaw
							g711_law_type_next = 1'b0;	// Alaw is default.
						end
						16'h0007 : begin
							I2S_nextstate = g711_start_wait;
							playback_type_next = 4'h2;	// "2" rhymes "mu"
							g711_law_type_next = 1'b1; 	// Remember that we're u-law!
						end
						// 16'h0011 : begin 
						// 	I2S_nextstate = IMA_ADPCM_start_wait;
						// 	playback_type_next = 4'hA;	// "A" for ADPCM!
						// end
						default :;
						// default: I2S_nextstate = pcm_start_wait_zerocount;
					endcase			
				end
				pcm_start_wait : begin
					shiftsig_next = I2S_SCLK;
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter >= 9'd192) begin	// 192 bit-shifts to get into starting position.
						I2S_count_next = 0;
						I2S_nextstate = pcm_start_wait_zerocount;
					end
				end
				pcm_start_wait_zerocount : begin
					I2S_count_next = 0;
					if(~I2S_LRCLK & LRCLK_saved) begin	// If just changed to right from left
						I2S_go_next = 1'b1;
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
				g711_start_wait : begin
					shiftsig_next = I2S_SCLK;
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter >= 9'd192) begin	// 192 bit-shifts to get into starting position.
						I2S_count_next = 0;
						I2S_nextstate = g711_start_wait_zerocount;
					end
				end
				g711_start_wait_zerocount : begin
					I2S_count_next = 0;
					if(~I2S_LRCLK & LRCLK_saved) begin	// If just changed to right from left
						I2S_go_next = 1'b1;
					end				
					if(I2S_go) begin	// this is necessary due to the above condition failing to persist...
						I2S_count_next = 0;
						I2S_nextstate = g711_left;
						g711_calc = 1'b1;
					end
				end
				g711_left : begin
					// I2S_DIN = g711_sample[13];
					// if((I2S_counter >= VOLUME_SHIFT) & (I2S_counter < (14 + VOLUME_SHIFT - 1))) begin
					// 	I2S_DIN = g711_sample[(13 + VOLUME_SHIFT) - I2S_counter];
					// 	// shiftsig_next = I2S_SCLK; 	// This should end up shifting right on time.
					// 	// Only shift if we are above the volume.
					// 	// Should also nicely sign-extend when reducing amplitude.
					// end
					// if(index_counter < 9) begin	// Allow for 8 shifts - to dump the compressed sample.
					// 	shiftsig_next = I2S_SCLK;
					// end
					// index_counter_next = index_counter + 1;
					// I2S_count_next = I2S_counter + 1;
					// if(index_counter >= (14 + VOLUME_SHIFT - 1)) begin
					// 	I2S_nextstate = g711_left_zerocount;
					// end
					// if (index_counter != 0) begin
					if(index_counter >= VOLUME_SHIFT) begin
						I2S_DIN = g711_sample[(13 + VOLUME_SHIFT) - index_counter];
					end
					else
						I2S_DIN = g711_sample[13];
					index_counter_next = index_counter + 1;
					if(index_counter < 8) begin	// Allow for 8 shifts - to dump the compressed sample.
						shiftsig_next = I2S_SCLK;
					end
					if(index_counter >= (13 + VOLUME_SHIFT)) begin
						I2S_nextstate = g711_left_zerocount;
					end
				end
				g711_left_zerocount : begin
					I2S_DIN = g711_sample[13];
					index_counter_next = 0;
					I2S_count_next = 0;
					if(I2S_LRCLK & (~LRCLK_saved)) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = g711_right;
						g711_calc = 1'b1;
					end
				end
				g711_right : begin
					// I2S_DIN = g711_sample[13];
					// if((I2S_counter >= VOLUME_SHIFT) & (I2S_counter < (14 + VOLUME_SHIFT - 1))) begin
					// 	I2S_DIN = g711_sample[(13 + VOLUME_SHIFT) - I2S_counter];
					// 	// shiftsig_next = I2S_SCLK; 	// This should end up shifting right on time.
					// 	// Only shift if we are above the volume.
					// 	// Should also nicely sign-extend when reducing amplitude.
					// end
					// if(index_counter < 9) begin	// 8 bits of shift
					// 	shiftsig_next = I2S_SCLK;
					// end
					// index_counter_next = index_counter + 1;
					// I2S_count_next = I2S_counter + 1;
					// if(index_counter >= (14 + VOLUME_SHIFT - 1)) begin
					// 	I2S_nextstate = g711_right_zerocount;
					// end
					if(index_counter >= VOLUME_SHIFT) begin
						I2S_DIN = g711_sample[(13 + VOLUME_SHIFT) - index_counter];
					end
					else
						I2S_DIN = g711_sample[13];
					index_counter_next = index_counter + 1;
					if(index_counter < 8) begin	// Allow for 8 shifts - to dump the compressed sample.
						shiftsig_next = I2S_SCLK;
					end
					if(index_counter >= (13 + VOLUME_SHIFT)) begin
						I2S_nextstate = g711_right_zerocount;
					end
				end
				g711_right_zerocount : begin
					I2S_DIN = g711_sample[13];
					I2S_count_next = 0;
					index_counter_next = 0;
					if((~I2S_LRCLK) & LRCLK_saved) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = g711_left;
						g711_calc = 1'b1;
					end
				end
				IMA_ADPCM_start_wait : begin
					shiftsig_next = I2S_SCLK;
					I2S_count_next = I2S_counter + 1;
					if(I2S_counter >= 9'd192) begin	// 192 bit-shifts to get into starting position.
						I2S_count_next = 0;
						I2S_nextstate = IMA_ADPCM_start_wait_zerocount;
					end
				end
				IMA_ADPCM_start_wait_zerocount : begin
					I2S_count_next = 0;
					if(~I2S_LRCLK & LRCLK_saved) begin	// If just changed to right from left
						I2S_go_next = 1'b1;
					end				
					if(I2S_go) begin	// this is necessary due to the above condition failing to persist...
						I2S_count_next = 0;
						index_counter_next = 0;
						ADPCM_CALC_L = 1'b1;
						I2S_nextstate = IMA_ADPCM_left;
					end
				end
				IMA_ADPCM_left : begin
					if(index_counter >= VOLUME_SHIFT) begin
						I2S_DIN = ADPCM_L_READOUT[(11 + VOLUME_SHIFT) - index_counter];
					end
					else
						I2S_DIN = ADPCM_L_READOUT[11];
					index_counter_next = index_counter + 1;
					if(index_counter < 4) begin	// Allow for 8 shifts - to dump the compressed sample.
						shiftsig_next = I2S_SCLK;
					end
					if(index_counter >= 11 + VOLUME_SHIFT) begin
						I2S_nextstate = IMA_ADPCM_left_zerocount;
					end
					// I2S_DIN = ADPCM_L_READOUT[11];
					// if((I2S_counter >= VOLUME_SHIFT) & (I2S_counter < (12 + VOLUME_SHIFT - 1))) begin
					// 	I2S_DIN = ADPCM_L_READOUT[(11 + VOLUME_SHIFT) - I2S_counter];
						// shiftsig_next = I2S_SCLK; 	// This should end up shifting right on time.
						// Only shift if we are above the volume.
						// Should also nicely sign-extend when reducing amplitude.
					// end
					// if(I2S_counter < 5) begin
					// 	shiftsig_next = I2S_SCLK;
					// end
					// I2S_count_next = I2S_counter + 1;
					// if(I2S_counter >= (12 + VOLUME_SHIFT - 1)) begin
					// 	I2S_nextstate = IMA_ADPCM_left_zerocount;
					// end
				end
				IMA_ADPCM_left_zerocount : begin
					I2S_DIN = ADPCM_SAMPLE_L[11];
					I2S_count_next = 0;
					index_counter_next = 0;
					if(I2S_LRCLK & (~LRCLK_saved)) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = IMA_ADPCM_right;
						// ADPCM_CALC_R = 1'b1;
					end
				end
				IMA_ADPCM_right : begin
					if(index_counter >= VOLUME_SHIFT) begin
						I2S_DIN = ADPCM_L_READOUT[(11 + VOLUME_SHIFT) - index_counter];
					end
					else
						I2S_DIN = ADPCM_L_READOUT[11];
					index_counter_next = index_counter + 1;
					// Do not shift again, since it's MONO!
					// if(index_counter < 4) begin	// Allow for 8 shifts - to dump the compressed sample.
					// 	shiftsig_next = I2S_SCLK;
					// end	
					if(index_counter >= 11 + VOLUME_SHIFT) begin
						I2S_nextstate = IMA_ADPCM_right_zerocount;
					end
				end
				IMA_ADPCM_right_zerocount : begin
					I2S_DIN = ADPCM_SAMPLE_L[11];
					I2S_count_next = 0;
					index_counter_next = 0;
					if((~I2S_LRCLK) & LRCLK_saved) begin
						I2S_go_next = 1'b1;
					end
					if(I2S_go) begin
						I2S_nextstate = IMA_ADPCM_left;
						ADPCM_CALC_L = 1'b1;
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
			playback_type <= 1'b0;	// Default to 0
			// I2S_go <= 1'b0;
			g711_law_type <= 1'b0;
			
		end
		else begin
			// I2S_go <= I2S_go_next;
			LRCLK_saved <= I2S_LRCLK;
			I2S_counter <= I2S_count_next;
			saved_sign_bit <= next_sign_bit;
			playback_type <= playback_type_next;
			g711_law_type <= g711_law_type_next;
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
			I2S_STATE <= start_check_RIFF;
			index_counter <= 6'h0;
		end
		else if(Q_RDY & I2S_enable) begin
			// LRCLK_saved <= LRCLK_next;
			I2S_STATE <= I2S_nextstate;
			// I2S_DIN <= I2S_DIN_next;
			index_counter <= index_counter_next;
		end
	end


	// g711 calculation
	logic unsigned [13:0] g711_sample, g711_sample_next;		// u-law is 14, larger of the two.
	logic g711_CALC_STATE, g711_CALC_STATE_next;	// This is the state
	logic [3:0] bottom_nibble;
	assign bottom_nibble	= BITQUEUE[43:40];
	logic g711_calc;

	always_comb begin
		g711_sample_next = g711_sample;
		g711_CALC_STATE_next = g711_CALC_STATE;
		case (g711_CALC_STATE) 
			1'b1 : begin	// Wait for signal to deassert.
				if(~g711_calc)begin
					g711_CALC_STATE_next = 1'b0;	// Arm to wait for next assert
				end
			end
			1'b0 : 	begin	// Await activation
				if(g711_calc)	begin	// if called upon
					case (g711_law_type)
						1'b1 : begin	// u-law
							casez (BITQUEUE[46:44]) // Check the top byte
								3'b000 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:5] = 8'h1;
									g711_sample_next[4:1] = bottom_nibble;
									g711_sample_next[0] = 1'b1;
								end
								3'b001 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:6] = 7'h1;
									g711_sample_next[5:2] = bottom_nibble;
									g711_sample_next[1:0] = 2'b10;
								end
								3'b010 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:7] = 6'h1;
									g711_sample_next[6:3] = bottom_nibble;
									g711_sample_next[2:0] = 3'b100;
								end
								3'b011 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:8] = 5'h1;
									g711_sample_next[7:4] = bottom_nibble;
									g711_sample_next[3:0] = 4'b1000;
								end
								3'b100 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:9] = 4'h1;
									g711_sample_next[8:5] = bottom_nibble;
									g711_sample_next[4:0] = 5'b10000;
								end
								3'b101 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:10] = 3'h1;
									g711_sample_next[9:6] = bottom_nibble;
									g711_sample_next[5:0] = 6'b100000;
								end
								3'b110 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12:11] = 2'h1;
									g711_sample_next[10:7] = bottom_nibble;
									g711_sample_next[6:0] = 7'b1000000;
								end
								3'b111 : begin
									g711_sample_next[13] = sign;
									g711_sample_next[12] = 1'h1;
									g711_sample_next[11:8] = bottom_nibble;
									g711_sample_next[7:0] = 8'b10000000;
								end
								default: ;
							endcase
							g711_sample_next[12:0] = (g711_sample_next[12:0] - 33);
							if(sign) begin	// Change from signed-magnitude to 2s-complement
								g711_sample_next = (14'b10000000000000 - g711_sample_next);
							end
						end
						1'b0 : begin	// A-law
							casez (BITQUEUE[46:44]) // Check the top byte
								3'b000 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:6] = 7'h0;
									g711_sample_next[5:2] = bottom_nibble;
									g711_sample_next[1:0] = 2'b10;
								end
								3'b001 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:6] = 7'h1;
									g711_sample_next[5:2] = bottom_nibble;
									g711_sample_next[1:0] = 2'b10;
								end
								3'b010 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:7] = 6'h1;
									g711_sample_next[6:3] = bottom_nibble;
									g711_sample_next[2:0] = 3'b100;
								end
								3'b011 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:8] = 5'h1;
									g711_sample_next[7:4] = bottom_nibble;
									g711_sample_next[3:0] = 4'b1000;
								end
								3'b100 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:9] = 4'h1;
									g711_sample_next[8:5] = bottom_nibble;
									g711_sample_next[4:0] = 5'b10000;
								end
								3'b101 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:10] = 3'h1;
									g711_sample_next[9:6] = bottom_nibble;
									g711_sample_next[5:0] = 6'b100000;
								end
								3'b110 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12:11] = 2'h1;
									g711_sample_next[10:7] = bottom_nibble;
									g711_sample_next[6:0] = 7'b1000000;
								end
								3'b111 : begin
									g711_sample_next[13] = ~sign;
									g711_sample_next[12] = 1'h1;
									g711_sample_next[11:8] = bottom_nibble;
									g711_sample_next[7:0] = 8'b10000000;
								end
								default: ;
							endcase
							if(sign) begin	// Change from signed-magnitude to 2s-complement
								g711_sample_next = (14'b10000000000000 - g711_sample_next);
							end
							g711_sample_next[0] = g711_sample_next[13];
						end
						default: ;
					endcase
				end
			end
			default: ;
		endcase
	end

	always_ff @ (posedge clk50 or posedge reset) begin
		if (reset) begin
			g711_sample <= 14'h0;
			g711_CALC_STATE <= 1'b0;
		end
		else begin
			g711_sample <= g711_sample_next;
			g711_CALC_STATE <= g711_CALC_STATE_next;
		end
	end


	// ADPCM calculating stuff for Left-side
	shortint ADPCM_SAMPLE_L; // , ADPCM_PREVSAMPLE_L, ADPCM_PREVSAMPLE_L_next;
	shortint ADPCM_SAMPLE_L_next;
	logic [11:0] ADPCM_L_READOUT;
	assign ADPCM_L_READOUT = ADPCM_SAMPLE_L[11:0];
	logic ADPCM_CALC_L_STATE, ADPCM_CALC_L_STATE_next;	// This is the state
	shortint step_index_L, step_index_L_next;
	shortint diff_L;
	logic sign;

	logic [3:0] nibble;
	assign nibble = BITQUEUE[47:44];
	assign sign = BITQUEUE[47];

	shortint step_L, step_L_next;

	always_comb begin
		diff_L = 0;
		ADPCM_CALC_L_STATE_next = ADPCM_CALC_L_STATE;
		step_L_next = step_L;
		// ADPCM_PREVSAMPLE_L_next = ADPCM_PREVSAMPLE_L;
		ADPCM_SAMPLE_L_next = ADPCM_SAMPLE_L;
		// ADPCM_SAMPLE_L_next[15:0] = ADPCM_SAMPLE_L;
		// ADPCM_SAMPLE_L_next[31:16] = 16'h0;
		step_index_L_next = step_index_L;
		// predictor_next = predictor_saved;
		case (ADPCM_CALC_L_STATE) 
			1'b1 : begin	// Wait for signal to deassert.
				if(~ADPCM_CALC_L)begin
					ADPCM_CALC_L_STATE_next = 1'b0;	// Arm to wait for next assert
				end
			end
			1'b0 : 	begin	// Await activation
				if(ADPCM_CALC_L)	begin	// if called upon
					ADPCM_CALC_L_STATE_next = 1'b1;
					step_index_L_next = step_index_L + ima_index_table[nibble];
					// ADPCM_PREVSAMPLE_L_next = ADPCM_SAMPLE_L;
					diff_L = step_L >> 3;
					if(nibble[2])
						diff_L = diff_L + step_L;
					if(nibble[1])
						diff_L = diff_L + (step_L >> 1);
					if(nibble[0])
						diff_L = diff_L + (step_L >> 2);
					case (sign)
						1'b1 : ADPCM_SAMPLE_L_next = ADPCM_SAMPLE_L - diff_L;
						1'b0 : ADPCM_SAMPLE_L_next = ADPCM_SAMPLE_L + diff_L;
						default: ;
					endcase
					// ADPCM_SAMPLE_L_next = ADPCM_PREVSAMPLE_L + diff_L;
					if(ADPCM_SAMPLE_L_next > 2047) begin
						ADPCM_SAMPLE_L_next = 2047;
					end
					else if(ADPCM_SAMPLE_L_next < -2048) begin
						ADPCM_SAMPLE_L_next = -2048;
					end
					if(step_index_L_next >= 49) begin
						step_index_L_next = 48;
					end
					else if (step_index_L_next < 0) begin
						step_index_L_next = 0;
					end
					// step_L_next = step_L + ((11 * vox_ADPCM_step_table[step_index_L_next])/10);
					step_L_next = step_L + vox_ADPCM_step_table[step_index_L_next];
				end
			end
			default: ;
		endcase
	end

	always_ff @ (posedge clk50 or posedge reset) begin
		if (reset) begin
			ADPCM_SAMPLE_L <= 0;
			// ADPCM_PREVSAMPLE_L <= 0;
			ADPCM_CALC_L_STATE <= 0;
			step_index_L <= 16;
			step_L <= 16;
		end
		else begin
			// ADPCM_SAMPLE_L <= ADPCM_SAMPLE_L_next[15:0];
			ADPCM_SAMPLE_L <= ADPCM_SAMPLE_L_next;
			// ADPCM_PREVSAMPLE_L <= ADPCM_PREVSAMPLE_L_next;
			ADPCM_CALC_L_STATE <= ADPCM_CALC_L_STATE_next;
			step_index_L <= step_index_L_next;
			step_L <= step_L_next;
		end
	end

	// // ADPCM calculating stuff for R
	// shortint ADPCM_SAMPLE_R, ADPCM_PREVSAMPLE_R, ADPCM_PREVSAMPLE_R_next;
	// int ADPCM_SAMPLE_R_next;
	// logic ADPCM_CALC_R_STATE, ADPCM_CALC_R_STATE_next;	// This is the state
	// shortint step_index_R, step_index_R_next;
	// int diff_R;

	// shortint step_R;
	// assign step_R = ima_step_table[step_index_R];

	// always_comb begin
	// 	diff_R = step_R >> 3;
	// 	if(nibble[2])
	// 		diff_R = diff_R + step_R;
	// 	if(nibble[1])
	// 		diff_R = diff_R + (step_R >> 1);
	// 	if(nibble[0])
	// 		diff_R = diff_R + (step_R >> 2);
	// end

	// always_comb begin
	// 	ADPCM_CALC_R_STATE_next = ADPCM_CALC_R_STATE;
	// 	ADPCM_PREVSAMPLE_R_next = ADPCM_PREVSAMPLE_R;
	// 	ADPCM_SAMPLE_R_next[15:0] = ADPCM_SAMPLE_R;
	// 	ADPCM_SAMPLE_R_next[31:16] = 16'h0;
	// 	step_index_R_next = step_index_R;
	// 	// predictor_next = predictor_saved;
	// 	case (ADPCM_CALC_R_STATE) 
	// 		1'b1 : begin	// Wait for signal to deassert.
	// 			if(~ADPCM_CALC_R)begin
	// 				ADPCM_CALC_R_STATE_next = 1'b0;	// Arm to wait for next assert
	// 			end
	// 		end
	// 		1'b0 : 	begin	// Await activation
	// 			if(ADPCM_CALC_R)	begin	// if called upon
	// 				ADPCM_CALC_R_STATE_next = 1'b1;
	// 				ADPCM_PREVSAMPLE_R_next = ADPCM_SAMPLE_R;
	// 				case (sign)
	// 					1'b1 : ADPCM_SAMPLE_R_next = ADPCM_SAMPLE_R_next - diff_R;
	// 					1'b0 : ADPCM_SAMPLE_R_next = ADPCM_SAMPLE_R_next + diff_R;
	// 					default: ;
	// 				endcase
	// 				// ADPCM_SAMPLE_R_next = ADPCM_PREVSAMPLE_R + diff_R;
	// 				if(ADPCM_SAMPLE_R_next > 32767) begin
	// 					ADPCM_SAMPLE_R_next = 32767;
	// 				end
	// 				else if(ADPCM_SAMPLE_R_next < -32768) begin
	// 					ADPCM_SAMPLE_R_next = -32768;
	// 				end

	// 				step_index_R_next = step_index_R + ima_index_table[nibble];
	// 				if(step_index_R_next >= 89) begin
	// 					step_index_R_next = 88;
	// 				end
	// 				else if (step_index_R_next < 0) begin
	// 					step_index_R_next = 0;
	// 				end
					
	// 			end
	// 		end
	// 		default: ;
	// 	endcase
	// end

	// always_ff @ (posedge clk50 or posedge reset) begin
	// 	if (reset) begin
	// 		ADPCM_SAMPLE_R <= 0;
	// 		ADPCM_PREVSAMPLE_R <= 0;
	// 		ADPCM_CALC_R_STATE <= 0;
	// 		step_index_R <= 0;
	// 	end
	// 	else begin
	// 		ADPCM_SAMPLE_R <= ADPCM_SAMPLE_R_next;
	// 		ADPCM_PREVSAMPLE_R <= ADPCM_PREVSAMPLE_R_next;
	// 		ADPCM_CALC_R_STATE <= ADPCM_CALC_R_STATE_next;
	// 		step_index_R <= step_index_R_next;
	// 	end
	// end

	shortint ima_index_table[16] = '{
			-1, -1, -1, -1, 2, 4, 6, 8,
			-1, -1, -1, -1, 2, 4, 6, 8
			};
	// shortint ima_step_table[89] = '{ 
	// 	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 
	// 	19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 
	// 	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 
	// 	130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
	// 	337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
	// 	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 
	// 	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
	// 	5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 
	// 	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767 
	// 	}; 
	shortint vox_ADPCM_step_table[49] = '{ 
		16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 
		50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
		157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 
		494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552 
		};
	
endmodule