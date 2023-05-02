//-------------------------------------------------------------------------
//      ECE 385 - Summer 2021 Lab 7 Top-level                            --
//                                                                       --
//      Updated Fall 2021 as Lab 7                                       --
//      For use with ECE 385                                             --
//      UIUC ECE Department                                              --
//-------------------------------------------------------------------------

module player_toplevel (

      ///////// Clocks /////////
      input    MAX10_CLK1_50,

      ///////// KEY /////////
      input    [ 1: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LEDR /////////
      output   [ 9: 0]   LEDR,

      ///////// HEX /////////
      output   [ 7: 0]   HEX0,
      output   [ 7: 0]   HEX1,
      output   [ 7: 0]   HEX2,
      output   [ 7: 0]   HEX3,
      output   [ 7: 0]   HEX4,
      output   [ 7: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [15: 0]   DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_CS_N,
      output             DRAM_WE_N,
      output             DRAM_CAS_N,
      output             DRAM_RAS_N,

      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output   [ 3: 0]   VGA_R,
      output   [ 3: 0]   VGA_G,
      output   [ 3: 0]   VGA_B,





      ///////// ARDUINO /////////
      inout    [15: 0]   ARDUINO_IO,
      inout              ARDUINO_RESET_N 

);

//=======================================================
//  REG/WIRE declarations
//=======================================================
	logic SPI0_CS_N, SPI0_SCLK, SPI0_MISO, SPI0_MOSI, USB_GPX, USB_IRQ, USB_RST;
	logic Reset_h;
	logic [3:0] HEX_NUM_5, HEX_NUM_4, HEX_NUM_3, HEX_NUM_2, HEX_NUM_1, HEX_NUM_0; //4 bit input hex digits
	logic [3:0] HEX_NUM_5_AUD, HEX_NUM_4_AUD, HEX_NUM_3_AUD, HEX_NUM_2_AUD, HEX_NUM_1_AUD, HEX_NUM_0_AUD;
	logic [3:0] HEX_NUM_5_VID, HEX_NUM_4_VID, HEX_NUM_3_VID, HEX_NUM_2_VID, HEX_NUM_1_VID, HEX_NUM_0_VID;
	logic [3:0] HEX_NUM_5_LOAD, HEX_NUM_4_LOAD, HEX_NUM_3_LOAD, HEX_NUM_2_LOAD, HEX_NUM_1_LOAD, HEX_NUM_0_LOAD;
	logic [1:0] signs;
	logic [1:0] hundreds;
//	logic [7:0] keycode;
	logic [24:0] SD_MODULE_ADDR, VIDASIC_ADDR, AUDASIC_ADDR;
	logic [25:0] AVL_BR_ADDR;
	logic [15:0] AVL_BR_RDDATA, VIDASIC_RDDATA, AUDASIC_RDDATA, SD_MODULE_DATA;
	logic AVL_BR_ACK, SD_MODULE_ACK, VIDASIC_ACK, AUDASIC_ACK;		//acknowledge from RAM to move to next word
	logic SD_RAM_DONE;	//done with reading all MAX_RAM_ADDRESS words
	logic SD_RAM_ERR;		//error initializing
	logic AVL_BR_WREN, SD_MODULE_WE;		//write-enable?
	logic AVL_BR_RDEN, VIDASIC_RDEN, AUDASIC_RDEN;	// read-enables
	logic RAM_INIT_DONE_SIG;
	logic RAM_INIT_HALF;


//=======================================================
//  Modification: I2C variables
//=======================================================
	
	logic i2c_serial_sda_in;         //    i2c_serial.sda_in
	logic i2c_serial_scl_in;         //              .scl_in
	logic i2c_serial_sda_oe;         //              .sda_oe
	logic i2c_serial_scl_oe;         //              .scl_oe
	logic [1:0] aud_mclk_ctr = 2'b00;
	
//=======================================================
//  Modification: I2S variables
//=======================================================
	
	logic i2s_dout;
	logic i2s_din;
	logic i2s_sclk;
	logic i2s_lrclk;

//=======================================================
//  Structural coding
//=======================================================
	// assign ARDUINO_IO[10] = SPI0_CS_N;	// THIS IS FOR USB, MAX3421E
	assign ARDUINO_IO[6] = SPI0_CS_N;	// this assignment is for SD CARD!
	assign ARDUINO_IO[13] = SPI0_SCLK;
	assign ARDUINO_IO[11] = SPI0_MOSI;
//	assign ARDUINO_IO[12] = 1'bZ;
	assign SPI0_MISO = ARDUINO_IO[12];
	
	//generate 12.5MHz CODEC mclk
	always_ff @(posedge MAX10_CLK1_50) begin
		aud_mclk_ctr <= aud_mclk_ctr + 1;
	end
	assign i2c_serial_sda_in = ARDUINO_IO[14];
	assign i2c_serial_scl_in = ARDUINO_IO[15];
	assign ARDUINO_IO[14] = i2c_serial_sda_oe ? 1'b0 : 1'bz; //pulled directly from intel recommendation 
	assign ARDUINO_IO[15] = i2c_serial_scl_oe ? 1'b0 : 1'bz;
	
	//note that ARDUINO_IO15 is SCL, and ARDUINO_IO14 is SDA
	//assign the scl and sda with tristate buffers:
	assign ARDUINO_IO[3] = aud_mclk_ctr[1];
	
	
	assign i2s_dout = ARDUINO_IO[1];

	// These may be necessary to prevent stupid.
	assign ARDUINO_IO[1] = 1'bZ;
	assign ARDUINO_IO[4] = 1'bZ;
	assign ARDUINO_IO[5] = 1'bZ;

	always_comb begin
		case (SW1_SYNC)
			1'b1 : ARDUINO_IO[2] = i2s_din;
			1'b0 : ARDUINO_IO[2] = ARDUINO_IO[1];
			default: ;
		endcase
	end
	// assign ARDUINO_IO[2] = i2s_din;
	// assign ARDUINO_IO[2] = ARDUINO_IO[1];
	assign i2s_sclk = ARDUINO_IO[5];
	assign i2s_lrclk = ARDUINO_IO[4];


	always_comb begin // Select between the HEX output
		if(WRITE_OVERRIDE_STATE)begin
			HEX_NUM_0 = HEX_NUM_0_LOAD;
			HEX_NUM_1 = HEX_NUM_1_LOAD;
			HEX_NUM_2 = HEX_NUM_2_LOAD;
			HEX_NUM_3 = HEX_NUM_3_LOAD;
			HEX_NUM_4 = HEX_NUM_4_LOAD;
			HEX_NUM_5 = HEX_NUM_5_LOAD;
		end
		else begin
			case (SW9_SYNC)
			1'b1 :  begin // assign VIDEO
				HEX_NUM_0 = HEX_NUM_0_VID;
				HEX_NUM_1 = HEX_NUM_1_VID;
				HEX_NUM_2 = HEX_NUM_2_VID;
				HEX_NUM_3 = HEX_NUM_3_VID;
				HEX_NUM_4 = HEX_NUM_4_VID;
				HEX_NUM_5 = HEX_NUM_5_VID;
			end
			1'b0 : 	begin // assign AUDIO
				HEX_NUM_0 = HEX_NUM_0_AUD;
				HEX_NUM_1 = HEX_NUM_1_AUD;
				HEX_NUM_2 = HEX_NUM_2_AUD;
				HEX_NUM_3 = HEX_NUM_3_AUD;
				HEX_NUM_4 = HEX_NUM_4_AUD;
				HEX_NUM_5 = HEX_NUM_5_AUD;
			end
			default: ;
			endcase
		end
	end
	
	//HEX drivers to convert numbers to HEX output
	HexDriver hex_driver5 (HEX_NUM_5, HEX5[6:0]);
	assign HEX5[7] = 1'b1;

	HexDriver hex_driver4 (HEX_NUM_4, HEX4[6:0]);
	assign HEX4[7] = 1'b1;
	
	HexDriver hex_driver3 (HEX_NUM_3, HEX3[6:0]);
	assign HEX3[7] = 1'b1;
	
	HexDriver hex_driver2 (HEX_NUM_2, HEX2[6:0]);
	assign HEX2[7] = 1'b1;
	
	HexDriver hex_driver1 (HEX_NUM_1, HEX1[6:0]);
	assign HEX1[7] = 1'b1;
	
	HexDriver hex_driver0 (HEX_NUM_0, HEX0[6:0]);
	assign HEX0[7] = 1'b1;

	// debouncybois. 
	logic SW9_SYNC, SW8_SYNC, SW7_SYNC, SW6_SYNC, SW5_SYNC, SW4_SYNC, SW3_SYNC, SW2_SYNC, SW1_SYNC, SW0_SYNC;
	sync sync_9(.Clk(MAX10_CLK1_50), .d(SW[9]), .q(SW9_SYNC));
	sync sync_8(.Clk(MAX10_CLK1_50), .d(SW[8]), .q(SW8_SYNC));
	sync sync_7(.Clk(MAX10_CLK1_50), .d(SW[7]), .q(SW7_SYNC));
	sync sync_6(.Clk(MAX10_CLK1_50), .d(SW[6]), .q(SW6_SYNC));
	sync sync_5(.Clk(MAX10_CLK1_50), .d(SW[5]), .q(SW5_SYNC));
	sync sync_4(.Clk(MAX10_CLK1_50), .d(SW[4]), .q(SW4_SYNC));
	sync sync_3(.Clk(MAX10_CLK1_50), .d(SW[3]), .q(SW3_SYNC));
	sync sync_2(.Clk(MAX10_CLK1_50), .d(SW[2]), .q(SW2_SYNC));
	sync sync_1(.Clk(MAX10_CLK1_50), .d(SW[1]), .q(SW1_SYNC));
	sync sync_0(.Clk(MAX10_CLK1_50), .d(SW[0]), .q(SW0_SYNC));	
	logic KEY0_SYNC;
	sync sync_rst(.Clk(MAX10_CLK1_50), .d(KEY[0]), .q(KEY0_SYNC));	
	
	assign {Reset_h}=~ (KEY0_SYNC); 

	assign signs = 2'b00;
//	assign HEX_NUM_4 = 4'h4;
//	assign HEX_NUM_3 = 4'h3;
//	assign HEX_NUM_1 = 4'h1;
//	assign HEX_NUM_0 = 4'h0;
	
	//remember to rename the SOC as necessary
	
    ZFsoc u0 (
			.avalon_bridge_address     (AVL_BR_ADDR),     		//.avalon_bridge.address
			.avalon_bridge_byte_enable (2'b11), 					//.byte_enable
			.avalon_bridge_read        (AVL_BR_RDEN),        		//.read
			.avalon_bridge_write       (AVL_BR_WREN),       		//.write
			.avalon_bridge_write_data  (SD_MODULE_DATA),  			//.write_data
			.avalon_bridge_acknowledge (AVL_BR_ACK), 				//.acknowledge
			.avalon_bridge_read_data   (AVL_BR_RDDATA),   			//.read_data
			.clk_clk                   (MAX10_CLK1_50),             //.clk_clk
			.key_input_export          (KEY[1]),         			//.key_input.export
			.led_wire_export           (LEDR[5:0]),           		//.led_wire.export
			.reset_reset_n             (KEY0_SYNC),             		//.reset.reset_n
			//SDRAM
			.sdram_clk_100_clk			(DRAM_CLK),					//100mhz SDRAM clock! FAST BOI
			.sdram_wire_addr			(DRAM_ADDR),               	//sdram_wire.addr
			.sdram_wire_ba				(DRAM_BA),                	//.ba
			.sdram_wire_cas_n			(DRAM_CAS_N),              	//.cas_n
			.sdram_wire_cke				(DRAM_CKE),                 //.cke
			.sdram_wire_cs_n			(DRAM_CS_N),                //.cs_n
			.sdram_wire_dq				(DRAM_DQ),                  //.dq
			.sdram_wire_dqm				({DRAM_UDQM,DRAM_LDQM}),    //.dqm
			.sdram_wire_ras_n			(DRAM_RAS_N),              	//.ras_n
			.sdram_wire_we_n			(DRAM_WE_N),                //.we_n
			.switch_input_export       	(SW),        					//.switch_input.export
			.i2c_serial_sda_in(i2c_serial_sda_in),
			.i2c_serial_scl_in(i2c_serial_scl_in),
			.i2c_serial_sda_oe(i2c_serial_sda_oe),
			.i2c_serial_scl_oe(i2c_serial_scl_oe)
	);
	 
	// assign LEDR[8] = RAM_INIT_DONE_SIG;
	logic WRITE_OVERRIDE_STATE;
	// assign LEDR[8] = WRITE_OVERRIDE_STATE;
	always_ff @ (posedge MAX10_CLK1_50 or posedge Reset_h) begin
		if (Reset_h) begin
			WRITE_OVERRIDE_STATE <= 1;
		end
		else if (WRITE_OVERRIDE_STATE) begin
			WRITE_OVERRIDE_STATE <= ~RAM_INIT_DONE_SIG;
		end
	end

	logic [3:0] VGA_R_VID, VGA_G_VID, VGA_B_VID;
	logic [3:0] VGA_R_AUD, VGA_G_AUD, VGA_B_AUD;
	logic VGA_HS_VID, VGA_VS_VID;
	logic VGA_HS_AUD, VGA_VS_AUD;

	always_comb begin 
		case (SW9_SYNC)
			1'b1 : begin	// Video playback
				VGA_R = VGA_R_VID;
				VGA_G = VGA_G_VID;
				VGA_B = VGA_B_VID;
				VGA_HS = VGA_HS_VID;
				VGA_VS = VGA_VS_VID;
			end
			1'b0 : begin	// Audio playback - show graphics
				VGA_R = VGA_R_AUD;
				VGA_G = VGA_G_AUD;
				VGA_B = VGA_B_AUD;
				VGA_HS = VGA_HS_AUD;
				VGA_VS = VGA_VS_AUD;
			end
			default: ;
		endcase
	end


	 
	sdcard_init sdtest(
			.clk50(MAX10_CLK1_50),
			.reset(Reset_h),          //starts as soon reset is deasserted
			.ram_we(SD_MODULE_WE),         //RAM interface pins
			.ram_address(SD_MODULE_ADDR),
			.ram_data(SD_MODULE_DATA),
			.ram_op_begun(SD_MODULE_ACK),   //acknowledge from RAM to move to next word
			.ram_status_light(),
			.ram_init_error(LEDR[9]), 	// error initializing or paused
			.ram_init_paused(LEDR[8]),	// paused for reason of finished loading the half (no big deal)
			.ram_init_done(RAM_INIT_DONE_SIG),  //done with reading all MAX_RAM_ADDRESS words
			.ram_init_half(RAM_INIT_HALF),
			.cs_bo(SPI0_CS_N), //SD card pins (also make sure to disable USB CS if using DE10-Lite)
			.sclk_o(SPI0_SCLK),
			.mosi_o(SPI0_MOSI),
			.miso_i(SPI0_MISO),
			.hex_out_5(HEX_NUM_5_LOAD),
			.hex_out_4(HEX_NUM_4_LOAD),
			.hex_out_3(HEX_NUM_3_LOAD),
			.hex_out_2(HEX_NUM_2_LOAD),
			.hex_out_1(HEX_NUM_1_LOAD),
			.hex_out_0(HEX_NUM_0_LOAD)
	);

	sdram_access_ctl_contload sdram_bus_arbit(
			.clk50(MAX10_CLK1_50),
			.reset(Reset_h),
			.sw_write_override(WRITE_OVERRIDE_STATE),      // literal switch signal for write to take precedence
			.sd_write_half(RAM_INIT_HALF),
			.sw_rd_1en(SW9_SYNC),              // switch signal for '1' to read
    // signals for the avl bus master (to SDRAM controller)
    		.addr_out_toavl(AVL_BR_ADDR),
    		.read_out_toavl(AVL_BR_RDEN),
    		.write_out_toavl(AVL_BR_WREN),
    		.rddata_in_toavl(AVL_BR_RDDATA),
    		.ack_in_toavl(AVL_BR_ACK),

    // signals for the peripherals
       		.addr_in_1(VIDASIC_ADDR << 1),
    		.addr_in_2(AUDASIC_ADDR << 1), //  << 1), According to all known laws of avalon bus
			// this left shift should be here, but benjacode works in mysterious ways.
    		.addr_in_write(SD_MODULE_ADDR << 1),	//Lshift due to avalon bus specs!
    		.read_in_1(VIDASIC_RDEN),
    		.read_in_2(AUDASIC_RDEN),
    		.write_in(SD_MODULE_WE),   				// just 1 writing device

    		.ack_out_1(VIDASIC_ACK),
    		.ack_out_2(AUDASIC_ACK),
    		.ack_out_write_o(SD_MODULE_ACK),
    		.readdata_out_1(VIDASIC_RDDATA),
    		.readdata_out_2(AUDASIC_RDDATA)
	);

	vidasic_top vidasic(
    		.clk50(MAX10_CLK1_50),
    		.run(SW9_SYNC),  // enable-run, or halts
    		.reset(Reset_h),
			.key(SW0_SYNC),	// SW0_SYNC
    		// SDRAM connections
    		.ram_rden(VIDASIC_RDEN),
    		.ram_addr(VIDASIC_ADDR),
    		.ram_data(VIDASIC_RDDATA),
    		.ram_ack(VIDASIC_ACK),
    		.status_1(LEDR[7]),
    		.status_2(LEDR[6]),   
    		// VGA connections
    		.red(VGA_R_VID),
    		.green(VGA_G_VID),
    		.blue(VGA_B_VID),
    		.hsync(VGA_HS_VID),
    		.vsync(VGA_VS_VID),
			// temp hex connections
			.hex_out_5(HEX_NUM_5_VID),
			.hex_out_4(HEX_NUM_4_VID),
			.hex_out_3(HEX_NUM_3_VID),
			.hex_out_2(HEX_NUM_2_VID),
			.hex_out_1(HEX_NUM_1_VID),
			.hex_out_0(HEX_NUM_0_VID)
	);
	I2S_interface_R2 audasic(
			.clk50(MAX10_CLK1_50),
			.reset(Reset_h),
			.ADDR_PRGM(AUDASIC_ADDR),
			.RDdata_PRGM(AUDASIC_RDDATA), //output
			.RDen(AUDASIC_RDEN), //input
			.avalon_bridge_acknowledge(AUDASIC_ACK),
			.I2S_DIN(i2s_din),
			.I2S_LRCLK(i2s_lrclk),
			.I2S_SCLK(i2s_sclk),
			// .ADDR_load(KEY[0]), //just load 0 for now at start
			.I2S_enable((~SW9_SYNC) & (~WRITE_OVERRIDE_STATE)),
			.ADDR_start(0),//0 for now
			.hex_out_5(HEX_NUM_5_AUD),
			.hex_out_4(HEX_NUM_4_AUD),
			.hex_out_3(HEX_NUM_3_AUD),
			.hex_out_2(HEX_NUM_2_AUD),
			.hex_out_1(HEX_NUM_1_AUD),
			.hex_out_0(HEX_NUM_0_AUD),
			// VGA connections
    		.red(VGA_R_AUD),
    		.green(VGA_G_AUD),
    		.blue(VGA_B_AUD),
    		.hsync(VGA_HS_AUD),
    		.vsync(VGA_VS_AUD)
	 );


endmodule
