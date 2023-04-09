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
	logic [3:0] hex_num_4, hex_num_3, hex_num_2, hex_num_1, hex_num_0; //4 bit input hex digits
	logic [1:0] signs;
	logic [1:0] hundreds;
//	logic [7:0] keycode;
	logic [24:0] SD_MODULE_ADDR;
	logic [15:0] SD_MODULE_DATA;
	logic SD_RAM_ACK;		//acknowledge from RAM to move to next word
	logic SD_RAM_DONE;	//done with reading all MAX_RAM_ADDRESS words
	logic SD_RAM_ERR;		//error initializing
	logic SD_RAM_WE;		//write-enable?

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
	HexDriver hex_driver4 (hex_num_4, HEX4[6:0]);
	assign HEX4[7] = 1'b1;
	
	HexDriver hex_driver3 (hex_num_3, HEX3[6:0]);
	assign HEX3[7] = 1'b1;
	
	HexDriver hex_driver2 (hex_num_3, HEX2[6:0]);
	assign HEX2[7] = 1'b1;
	
	HexDriver hex_driver1 (hex_num_1, HEX1[6:0]);
	assign HEX1[7] = 1'b1;
	
	HexDriver hex_driver0 (hex_num_0, HEX0[6:0]);
	assign HEX0[7] = 1'b1;
	
	//fill in the hundreds digit as well as the negative sign
	assign HEX5 = {1'b1, ~signs[1], 3'b111, ~hundreds[1], ~hundreds[1], 1'b1};
//	assign HEX2 = {1'b1, ~signs[0], 3'b111, ~hundreds[0], ~hundreds[0], 1'b1};
	
	
	assign {Reset_h}=~ (KEY[0]); 

	assign signs = 2'b00;
//	assign hex_num_4 = 4'h4;
//	assign hex_num_3 = 4'h3;
//	assign hex_num_1 = 4'h1;
//	assign hex_num_0 = 4'h0;
	
	//remember to rename the SOC as necessary
	
    ZFsoc u0 (
        .avalon_bridge_address     (SD_MODULE_ADDR << 1),     // avalon_bridge.address
        .avalon_bridge_byte_enable (2'b11), 			//              .byte_enable
        .avalon_bridge_read        (1'b0),        //              .read
        .avalon_bridge_write       (SD_RAM_WE),       //              .write
        .avalon_bridge_write_data  (SD_MODULE_DATA),  //              .write_data
        .avalon_bridge_acknowledge (SD_RAM_ACK), //              .acknowledge
        .avalon_bridge_read_data   (),   //              .read_data
        .clk_clk                   (MAX10_CLK1_50),                   //           clk.clk
        .key_input_export          (KEY[1]),          //     key_input.export
        .led_wire_export           (LEDR[5:0]),           //      led_wire.export
        .reset_reset_n             (KEY[0]),             //         reset.reset_n
        //SDRAM
			.sdram_clk_clk(DRAM_CLK),            				   //clk_sdram.clk
			.sdram_wire_addr(DRAM_ADDR),               			   //sdram_wire.addr
			.sdram_wire_ba(DRAM_BA),                			   //.ba
			.sdram_wire_cas_n(DRAM_CAS_N),              		   //.cas_n
			.sdram_wire_cke(DRAM_CKE),                 			   //.cke
			.sdram_wire_cs_n(DRAM_CS_N),                		   //.cs_n
			.sdram_wire_dq(DRAM_DQ),                  			   //.dq
			.sdram_wire_dqm({DRAM_UDQM,DRAM_LDQM}),                //.dqm
			.sdram_wire_ras_n(DRAM_RAS_N),              		   //.ras_n
			.sdram_wire_we_n(DRAM_WE_N),                		   //.we_n
			.switch_input_export       (SW)        //  switch_input.export
	 );
	 
	 
	 sdcard_init sdtest(
			.clk50(MAX10_CLK1_50),
			.reset(KEY[1]),          //starts as soon reset is deasserted
			.ram_we(SD_RAM_WE),         //RAM interface pins
			.ram_address(SD_MODULE_ADDR),
			.ram_data(SD_MODULE_DATA),
			.ram_op_begun(SD_RAM_ACK),   //acknowledge from RAM to move to next word
			.ram_status_light(LEDR[7]),
			.ram_init_error(LEDR[9]), //error initializing
			.ram_init_done(LEDR[8]),  //done with reading all MAX_RAM_ADDRESS words
			.cs_bo(SPI0_CS_N), //SD card pins (also make sure to disable USB CS if using DE10-Lite)
			.sclk_o(SPI0_SCLK),
			.mosi_o(SPI0_MOSI),
			.miso_i(SPI0_MISO),
			.hex_out_4(hex_num_4),
			.hex_out_3(hex_num_3),
			.hex_out_2(hex_num_2),
			.hex_out_1(hex_num_1),
			.hex_out_0(hex_num_0),
);


endmodule
