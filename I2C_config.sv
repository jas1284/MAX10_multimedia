module I2C_config (
	input  logic clk50,
	input  logic reset,
	
	output logic [15:0] i2c_address,
	output logic [15:0] i2c_data,
	output logic interface_enable,
	
	input  logic interface_acknowledge,	
	
	//volume:
	input  logic SW1
	);
	
	
	logic [3:0] counter_state = 0;
	logic interface_acknowledge_state = 0;
	
	logic [7:0] volume = 90;
	logic SW1_state = 1;
	logic ack_state = 0;
	
	logic [5:0] clk50_counter = 0;
	logic [5:0] pulselength = 50;
	
	//just trigger 
	always_ff @ (posedge clk50) begin
		counter_state <= counter_state;
		interface_enable <= 1'b0;
		//need rising edge of interface_acknowledge and being within correct range to increment/output data
		if(interface_acknowledge == 1'b1 && interface_acknowledge_state == 1'b0 && counter_state < 11) begin
			interface_acknowledge_state <= 1'b1;
			interface_enable <= 1'b1;
		end
		
		if(interface_acknowledge == 1'b0 && interface_acknowledge_state == 1'b1) begin
			counter_state <= counter_state + 1;
			interface_acknowledge_state <= 1'b0;
		end
		
		if(reset) begin
			interface_acknowledge_state <= 1'b0;
			counter_state <= 0;
			interface_enable <= 1'b0;
		end
	end
	
	
	
	//i2c_address and i2c_data output
	always_comb begin
		i2c_address = 16'h0000;
		i2c_data = 16'h0000;
		case (counter_state) 
			1: begin
				//CHIP_PLL_CTRL register: 739b
				i2c_address = 16'h0032;
				i2c_data = 16'h739b;
				
			end
			2: begin
				//CHIP_ANA_POWER register: 45fe
				i2c_address = 16'h0030;
				i2c_data = 16'h45fe;
			end
			3: begin
				//CHIP_REF_CTRL register: 4e
				i2c_address = 16'h0028;
				i2c_data = 16'h004e;
			end
			4: begin
				//CHIP_DIG_POWER register: 63
				i2c_address = 16'h0002;
				i2c_data = 16'h0063;
			end
			5: begin
				//CHIP_CLK_CTRL register: 7
				i2c_address = 16'h0004;
				i2c_data = 16'h0007;
			end
			6: begin
				//CHIP_I2S_CTRL register: b0
				i2c_address = 16'h0006;
				i2c_data = 16'h00b0;
			end
			7: begin
				//CHIP_ANA_CTRL register: 4
				i2c_address = 16'h0024;
				i2c_data = 16'h0004;
			end
			8: begin
				//CHIP_SSS_CTRL register: 10
				i2c_address = 16'h000a;
				i2c_data = 16'h0010;
			end
			9: begin
				//CHIP_ADCDAC_CTRL register: 0
				i2c_address = 16'h000e;
				i2c_data = 16'h0000;
			end
			10: begin
				//CHIP_PAD_STRENGTH register: 555f
				i2c_address = 16'h0014;
				i2c_data = 16'h555f;
			end
			11: begin//ending
				i2c_address = 16'h0000;
				i2c_data = 16'h0000;
			end
			default: ;
		endcase
	end
	
	
	
/*
address <= 32'h0022;
				byte_enable <= 4'b1111;
				write <= 1'b1;
				write_data <= ((volume << 8) || volume);
*/
endmodule