//Zuofu Cheng (2020) for ECE 385, wrapper for VHDL XESS SDCard driver
//
//State machine to load (RAW) SD Card blocks into memory
//memory is assumed to by 32Mx16 (for now)
//loads up to MAX_RAM_ADDRESS parameter from SD card
//
//Note that your SD Card must be written with RAW binary data (e.g. no filesystem)
//On *nix you can use the dd (direct disk) command to write a binary file directly
//to the SD block device; on Windows, you can try using: http://www.chrysocome.net/dd
//Note that dd is a *dangerous program*, you can easily overwrite your boot 
//disk and brick your computer. Triple check your output device is the SD Card (and not your boot drive!)
//
//By default tested using old 1GB SD micro SD cards, should work with SDHC, but you will
//need to change both the parameter in this module, and the default generic in the VHDL 
//code (SDCard.VHD)


module sdcard_init (
	input  logic clk50,
	input  logic reset,          //starts as soon reset is deasserted
	output logic ram_we,         //RAM interface pins
	output logic [24:0] ram_address,
	output logic [15:0] ram_data,
	input  logic ram_op_begun,   //acknowledge from RAM to move to next word
	output logic ram_status_light,
	output logic [3:0] hex_out_5,
	output logic [3:0] hex_out_4,
	output logic [3:0] hex_out_3,
	output logic [3:0] hex_out_2,
	output logic [3:0] hex_out_1,
	output logic [3:0] hex_out_0,
	output logic ram_init_error, //error initializing
	output logic ram_init_done,  //done with reading all MAX_RAM_ADDRESS words
	output logic cs_bo, //SD card pins (also make sure to disable USB CS if using DE10-Lite)
	output logic sclk_o,
	output logic mosi_o,
	input  logic miso_i  
);

parameter 			MAX_RAM_ADDRESS = 25'h0FFFFFF;	// 32mill addrs, ideally 64MB?
parameter			SDHC 				 = 1'b1;

logic 				sd_read_block;
logic				sd_busy;
logic				sd_data_rdy;
logic				sd_data_next;
logic				sd_continue;
logic	[15:0]		sd_error;
logic [7:0] 		sd_output_data;
logic [31:0] 		sd_block_addr;

//registers written in 2-always method
enum logic [8:0]	{RESET, READBLOCK, READL_0, READL_1, READH_0, READH_1, WRITE, ERROR, DONE} state_r, state_x;
logic [24:0]		ram_addr_r, ram_addr_x;  //word address for memory initialization
logic [15:0]		data_r, data_x;

//assign primary outputs to correct registers
assign ram_address = ram_addr_r;
assign ram_data = data_r; 

SdCardCtrl m_sdcard ( .clk_i(clk50),
							 .reset_i(reset),
							 .rd_i(sd_read_block),
							 .wr_i(1'b0), //never write
							 .continue_i(sd_continue), //FSM keeps track of address
							 .addr_i(sd_block_addr),
							 .data_i(), //never write
							 .data_o(sd_output_data),
							 .busy_o(sd_busy),
							 .hndShk_o(sd_data_rdy),
							 .hndShk_i(sd_data_next),		
							 .error_o(sd_error),
							 .cs_bo(cs_bo),
							 .sclk_o(sclk_o),
							 .mosi_o(mosi_o),
							 .miso_i(miso_i));
							 

always_ff @ (posedge clk50) 
begin
	if (reset) begin
		state_r <= RESET;
		ram_addr_r <= 25'h0000000;
		data_r <= 16'h0000;
		ram_status_light <= 0;
	end
	else begin
		ram_status_light <= ram_status_light^1'b1;
		state_r <= state_x;
		data_r <= data_x;
		ram_addr_r <= ram_addr_x;
		hex_out_5 <= ram_addr_x[23:20];
		hex_out_4 <= ram_addr_x[19:16];
		hex_out_3 <= ram_addr_x[15:12];
		hex_out_2 <= ram_addr_x[11:8];
		hex_out_1 <= ram_addr_x[7:4];
		hex_out_0 <= ram_addr_x[3:0];
	end
end


always_comb 
begin
	//default combinational assignments
	sd_read_block = 1'b0;
	sd_continue = 1'b0;
	sd_data_next = 1'b0;
	ram_we = 1'b0;
	if (SDHC)//if SDHC mode, then this is block address (note that you need to change VHDL generic)
		sd_block_addr = ram_addr_r >> 8;
	else
		sd_block_addr = ram_addr_r << 1; //in SD mode, this is the *byte* address, change for SDHC 
	state_x = state_r;
	data_x = data_r;
	ram_addr_x = ram_addr_r;
	ram_init_error = 1'b0;
	ram_init_done = 1'b0;

	unique case (state_r)
		RESET: begin //reset state, wait for SD initialization - if failed for any reason, go into ERROR state
			if ((sd_busy == 1'b0) && (sd_error == 16'h0000))
				state_x = READBLOCK;//properly initialized
			else if ((sd_busy == 1'b0) && (sd_error != 16'h0000))
				state_x = ERROR;
		end
		READBLOCK: begin //send enable to start block read
			if (ram_addr_r >= MAX_RAM_ADDRESS) //done with the whole range
				state_x = DONE;
			else begin
				sd_read_block = 1'b1; //start block read
				if (sd_block_addr != 32'h00000000)
					sd_continue = 1'b1;
				if (sd_busy == 1'b1)
					state_x = READH_0;
			end
		end
		READH_0: begin //read first byte (higher byte)
			if (sd_busy == 1'b0) //busy going low signals end of block, read next block
				state_x = READBLOCK;
			else if (sd_data_rdy == 1'b1) begin//still have more data in this block, read more bytes
				data_x[7:0] = sd_output_data;	// ROUGHLY HACKED TO SWITCH LOW/HIGH! @jas1284
				state_x = READH_1;
			end
		end
		READH_1: begin //ack first byte
			sd_data_next = 1'b1;
			if (sd_data_rdy == 1'b0)//moved on to next byte
				state_x = READL_0;
		end
		READL_0: begin //read second byte (lower byte)
			if (sd_data_rdy == 1'b1) begin
				data_x[15:8] = sd_output_data;	// ROUGHLY HACKED TO SWITCH LOW/HIGH! @jas1284
				state_x = READL_1;
			end
		end
		READL_1: begin //ack second byte
			sd_data_next = 1'b1;
			if (sd_data_rdy == 1'b0)//move on to next byte/write word
				state_x = WRITE;
		end
		WRITE: begin //write 16-bit word, WE=1 and increment ram address for next word
			ram_we = 1'b1;
			if (ram_op_begun == 1'b1) begin//RAM as responded
				ram_addr_x = ram_addr_r + 1;
				state_x = READH_0;
			end
		end
		ERROR: begin
			ram_init_error = 1'b1;
		end
		DONE: begin
			ram_init_done = 1'b1;
		end
	endcase 
end //end comb
	
endmodule
