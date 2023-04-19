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

//=======================================================
//  Structural coding
//=======================================================
	// assign ARDUINO_IO[10] = SPI0_CS_N;	// THIS IS FOR USB, MAX3421E
	assign ARDUINO_IO[6] = SPI0_CS_N;	// this assignment is for SD CARD!
	assign ARDUINO_IO[13] = SPI0_SCLK;
	assign ARDUINO_IO[11] = SPI0_MOSI;
//	assign ARDUINO_IO[12] = 1'bZ;
	assign SPI0_MISO = ARDUINO_IO[12];
	
//	assign ARDUINO_IO[9] = 1'bZ;
//	assign USB_IRQ = ARDUINO_IO[9];
	
	//Assignments specific to Sparkfun USBHostShield-v13
	//assign ARDUINO_IO[7] = USB_RST;
	//assign ARDUINO_IO[8] = 1'bZ;
	//assign USB_GPX = ARDUINO_IO[8];
		
	//Assignments specific to Circuits At Home UHS_20
//	assign ARDUINO_RESET_N = USB_RST;
//	assign ARDUINO_IO[8] = 1'bZ;
//	//GPX is unconnected to shield, not needed for standard USB host - set to 0 to prevent interrupt
//	assign USB_GPX = 1'b0;
	
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
	
	//fill in the hundreds digit as well as the negative sign
//	assign HEX5 = {1'b1, ~signs[1], 3'b111, ~hundreds[1], ~hundreds[1], 1'b1};
//	assign HEX2 = {1'b1, ~signs[0], 3'b111, ~hundreds[0], ~hundreds[0], 1'b1};
	
	
	assign {Reset_h}=~ (KEY[0]); 

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
			.reset_reset_n             (KEY[0]),             		//.reset.reset_n
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
			.switch_input_export       (SW)        					//.switch_input.export
	);
	 
	// assign LEDR[8] = RAM_INIT_DONE_SIG;
	logic WRITE_OVERRIDE_STATE;
	assign LEDR[8] = WRITE_OVERRIDE_STATE;
	always_ff @ (posedge MAX10_CLK1_50 or posedge Reset_h) begin
		if (Reset_h) begin
			WRITE_OVERRIDE_STATE <= 1;
		end
		else if (WRITE_OVERRIDE_STATE) begin
			WRITE_OVERRIDE_STATE <= ~RAM_INIT_DONE_SIG;
		end
	end
	 
	sdcard_init sdtest(
			.clk50(MAX10_CLK1_50),
			.reset(Reset_h),          //starts as soon reset is deasserted
			.ram_we(SD_MODULE_WE),         //RAM interface pins
			.ram_address(SD_MODULE_ADDR),
			.ram_data(SD_MODULE_DATA),
			.ram_op_begun(SD_MODULE_ACK),   //acknowledge from RAM to move to next word
			.ram_status_light(),
			.ram_init_error(LEDR[9]), //error initializing
			.ram_init_done(RAM_INIT_DONE_SIG),  //done with reading all MAX_RAM_ADDRESS words
			.cs_bo(SPI0_CS_N), //SD card pins (also make sure to disable USB CS if using DE10-Lite)
			.sclk_o(SPI0_SCLK),
			.mosi_o(SPI0_MOSI),
			.miso_i(SPI0_MISO)
			// .hex_out_4(HEX_NUM_4),
			// .hex_out_3(HEX_NUM_3),
			// .hex_out_2(HEX_NUM_2),
			// .hex_out_1(HEX_NUM_1),
			// .hex_out_0(HEX_NUM_0),
	);

	sdram_access_ctl sdram_bus_arbit(
			.clk50(MAX10_CLK1_50),
			.sw_write_override(WRITE_OVERRIDE_STATE),      // literal switch signal for write to take precedence
			.sw_rd_1en(SW9_SYNC),              // switch signal for '1' to read
    // signals for the avl bus master (to SDRAM controller)
    		.addr_out_toavl(AVL_BR_ADDR),
    		.read_out_toavl(AVL_BR_RDEN),
    		.write_out_toavl(AVL_BR_WREN),
    		.rddata_in_toavl(AVL_BR_RDDATA),
    		.ack_in_toavl(AVL_BR_ACK),

    // signals for the peripherals
       		.addr_in_1(VIDASIC_ADDR << 1),
    		.addr_in_2(AUDASIC_ADDR << 1),
    		.addr_in_write(SD_MODULE_ADDR << 1),	//Lshift due to avalon bus specs!
    		.read_in_1(VIDASIC_RDEN),
    		.read_in_2(AUDASIC_RDEN),
    		.write_in(SD_MODULE_WE),   				// just 1 writing device

    		.ack_out_1(VIDASIC_ACK),
    		.ack_out_2(AUDASIC_ACK),
    		.ack_out_write(SD_MODULE_ACK),
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
    		.red(VGA_R),
    		.green(VGA_G),
    		.blue(VGA_B),
    		.hsync(VGA_HS),
    		.vsync(VGA_VS),
			// temp hex connections
			.hex_out_5(HEX_NUM_5),
			.hex_out_4(HEX_NUM_4),
			.hex_out_3(HEX_NUM_3),
			.hex_out_2(HEX_NUM_2),
			.hex_out_1(HEX_NUM_1),
			.hex_out_0(HEX_NUM_0)
);


endmodule
