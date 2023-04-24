	component ZFsoc is
		port (
			avalon_bridge_address     : in    std_logic_vector(25 downto 0) := (others => 'X'); -- address
			avalon_bridge_byte_enable : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- byte_enable
			avalon_bridge_read        : in    std_logic                     := 'X';             -- read
			avalon_bridge_write       : in    std_logic                     := 'X';             -- write
			avalon_bridge_write_data  : in    std_logic_vector(15 downto 0) := (others => 'X'); -- write_data
			avalon_bridge_acknowledge : out   std_logic;                                        -- acknowledge
			avalon_bridge_read_data   : out   std_logic_vector(15 downto 0);                    -- read_data
			clk_clk                   : in    std_logic                     := 'X';             -- clk
			i2c_serial_sda_in         : in    std_logic                     := 'X';             -- sda_in
			i2c_serial_scl_in         : in    std_logic                     := 'X';             -- scl_in
			i2c_serial_sda_oe         : out   std_logic;                                        -- sda_oe
			i2c_serial_scl_oe         : out   std_logic;                                        -- scl_oe
			key_input_export          : in    std_logic                     := 'X';             -- export
			led_wire_export           : out   std_logic_vector(5 downto 0);                     -- export
			reset_reset_n             : in    std_logic                     := 'X';             -- reset_n
			sdram_clk_clk             : out   std_logic;                                        -- clk
			sdram_clk_100_clk         : out   std_logic;                                        -- clk
			sdram_wire_addr           : out   std_logic_vector(12 downto 0);                    -- addr
			sdram_wire_ba             : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_wire_cas_n          : out   std_logic;                                        -- cas_n
			sdram_wire_cke            : out   std_logic;                                        -- cke
			sdram_wire_cs_n           : out   std_logic;                                        -- cs_n
			sdram_wire_dq             : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
			sdram_wire_dqm            : out   std_logic_vector(1 downto 0);                     -- dqm
			sdram_wire_ras_n          : out   std_logic;                                        -- ras_n
			sdram_wire_we_n           : out   std_logic;                                        -- we_n
			switch_input_export       : in    std_logic_vector(9 downto 0)  := (others => 'X')  -- export
		);
	end component ZFsoc;

	u0 : component ZFsoc
		port map (
			avalon_bridge_address     => CONNECTED_TO_avalon_bridge_address,     -- avalon_bridge.address
			avalon_bridge_byte_enable => CONNECTED_TO_avalon_bridge_byte_enable, --              .byte_enable
			avalon_bridge_read        => CONNECTED_TO_avalon_bridge_read,        --              .read
			avalon_bridge_write       => CONNECTED_TO_avalon_bridge_write,       --              .write
			avalon_bridge_write_data  => CONNECTED_TO_avalon_bridge_write_data,  --              .write_data
			avalon_bridge_acknowledge => CONNECTED_TO_avalon_bridge_acknowledge, --              .acknowledge
			avalon_bridge_read_data   => CONNECTED_TO_avalon_bridge_read_data,   --              .read_data
			clk_clk                   => CONNECTED_TO_clk_clk,                   --           clk.clk
			i2c_serial_sda_in         => CONNECTED_TO_i2c_serial_sda_in,         --    i2c_serial.sda_in
			i2c_serial_scl_in         => CONNECTED_TO_i2c_serial_scl_in,         --              .scl_in
			i2c_serial_sda_oe         => CONNECTED_TO_i2c_serial_sda_oe,         --              .sda_oe
			i2c_serial_scl_oe         => CONNECTED_TO_i2c_serial_scl_oe,         --              .scl_oe
			key_input_export          => CONNECTED_TO_key_input_export,          --     key_input.export
			led_wire_export           => CONNECTED_TO_led_wire_export,           --      led_wire.export
			reset_reset_n             => CONNECTED_TO_reset_reset_n,             --         reset.reset_n
			sdram_clk_clk             => CONNECTED_TO_sdram_clk_clk,             --     sdram_clk.clk
			sdram_clk_100_clk         => CONNECTED_TO_sdram_clk_100_clk,         -- sdram_clk_100.clk
			sdram_wire_addr           => CONNECTED_TO_sdram_wire_addr,           --    sdram_wire.addr
			sdram_wire_ba             => CONNECTED_TO_sdram_wire_ba,             --              .ba
			sdram_wire_cas_n          => CONNECTED_TO_sdram_wire_cas_n,          --              .cas_n
			sdram_wire_cke            => CONNECTED_TO_sdram_wire_cke,            --              .cke
			sdram_wire_cs_n           => CONNECTED_TO_sdram_wire_cs_n,           --              .cs_n
			sdram_wire_dq             => CONNECTED_TO_sdram_wire_dq,             --              .dq
			sdram_wire_dqm            => CONNECTED_TO_sdram_wire_dqm,            --              .dqm
			sdram_wire_ras_n          => CONNECTED_TO_sdram_wire_ras_n,          --              .ras_n
			sdram_wire_we_n           => CONNECTED_TO_sdram_wire_we_n,           --              .we_n
			switch_input_export       => CONNECTED_TO_switch_input_export        --  switch_input.export
		);

