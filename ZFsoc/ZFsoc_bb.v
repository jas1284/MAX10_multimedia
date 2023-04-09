
module ZFsoc (
	avalon_bridge_address,
	avalon_bridge_byte_enable,
	avalon_bridge_read,
	avalon_bridge_write,
	avalon_bridge_write_data,
	avalon_bridge_acknowledge,
	avalon_bridge_read_data,
	clk_clk,
	key_input_export,
	led_wire_export,
	reset_reset_n,
	sdram_clk_clk,
	sdram_wire_addr,
	sdram_wire_ba,
	sdram_wire_cas_n,
	sdram_wire_cke,
	sdram_wire_cs_n,
	sdram_wire_dq,
	sdram_wire_dqm,
	sdram_wire_ras_n,
	sdram_wire_we_n,
	switch_input_export);	

	input	[25:0]	avalon_bridge_address;
	input	[1:0]	avalon_bridge_byte_enable;
	input		avalon_bridge_read;
	input		avalon_bridge_write;
	input	[15:0]	avalon_bridge_write_data;
	output		avalon_bridge_acknowledge;
	output	[15:0]	avalon_bridge_read_data;
	input		clk_clk;
	input		key_input_export;
	output	[5:0]	led_wire_export;
	input		reset_reset_n;
	output		sdram_clk_clk;
	output	[12:0]	sdram_wire_addr;
	output	[1:0]	sdram_wire_ba;
	output		sdram_wire_cas_n;
	output		sdram_wire_cke;
	output		sdram_wire_cs_n;
	inout	[15:0]	sdram_wire_dq;
	output	[1:0]	sdram_wire_dqm;
	output		sdram_wire_ras_n;
	output		sdram_wire_we_n;
	input	[9:0]	switch_input_export;
endmodule
