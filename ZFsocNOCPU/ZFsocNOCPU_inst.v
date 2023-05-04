	ZFsocNOCPU u0 (
		.avalon_bridge_address     (<connected-to-avalon_bridge_address>),     // avalon_bridge.address
		.avalon_bridge_byte_enable (<connected-to-avalon_bridge_byte_enable>), //              .byte_enable
		.avalon_bridge_read        (<connected-to-avalon_bridge_read>),        //              .read
		.avalon_bridge_write       (<connected-to-avalon_bridge_write>),       //              .write
		.avalon_bridge_write_data  (<connected-to-avalon_bridge_write_data>),  //              .write_data
		.avalon_bridge_acknowledge (<connected-to-avalon_bridge_acknowledge>), //              .acknowledge
		.avalon_bridge_read_data   (<connected-to-avalon_bridge_read_data>),   //              .read_data
		.clk_clk                   (<connected-to-clk_clk>),                   //           clk.clk
		.reset_reset_n             (<connected-to-reset_reset_n>),             //         reset.reset_n
		.sdram_clk_clk             (<connected-to-sdram_clk_clk>),             //     sdram_clk.clk
		.sdram_clk_100_clk         (<connected-to-sdram_clk_100_clk>),         // sdram_clk_100.clk
		.sdram_wire_addr           (<connected-to-sdram_wire_addr>),           //    sdram_wire.addr
		.sdram_wire_ba             (<connected-to-sdram_wire_ba>),             //              .ba
		.sdram_wire_cas_n          (<connected-to-sdram_wire_cas_n>),          //              .cas_n
		.sdram_wire_cke            (<connected-to-sdram_wire_cke>),            //              .cke
		.sdram_wire_cs_n           (<connected-to-sdram_wire_cs_n>),           //              .cs_n
		.sdram_wire_dq             (<connected-to-sdram_wire_dq>),             //              .dq
		.sdram_wire_dqm            (<connected-to-sdram_wire_dqm>),            //              .dqm
		.sdram_wire_ras_n          (<connected-to-sdram_wire_ras_n>),          //              .ras_n
		.sdram_wire_we_n           (<connected-to-sdram_wire_we_n>)            //              .we_n
	);

