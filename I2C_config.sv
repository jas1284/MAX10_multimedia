// Module for storing and writing the intial configurations for the audio registers on the SGTL5000 and continually updating volume
// Takes input of clk, reset, an acknowledge from the I2C_interface, and a switch or button. Upon program startup or reset, it will
// write to the registers so that audio is outputting from I2S to HP out, and it will continue to loop, updating volume through switch
// input and writing it to the register on the SGTL5000.

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
	
	logic SW1_state = 1;
	logic ack_state = 0;
	
	logic [5:0] clk50_counter = 0;
	logic [5:0] pulselength = 50;
	logic [6:0] volume = 0;
	
	//just trigger 
	always_ff @ (posedge clk50) begin
		counter_state <= counter_state;
		interface_enable <= 1'b0;
		volume <= volume;
		//need rising edge of interface_acknowledge and being within correct range to increment/output data
		if(interface_acknowledge == 1'b1 && interface_acknowledge_state == 1'b0 && counter_state < 12) begin
			interface_acknowledge_state <= 1'b1;
			interface_enable <= 1'b1;
		end
		//cycle through all the states (each state is just data to output for config
		if(interface_acknowledge == 1'b0 && interface_acknowledge_state == 1'b1) begin
			if(counter_state < 11) begin
				counter_state <= counter_state + 1;
			end//last state loops and constantly writes the value of volume to the I2C config
			interface_acknowledge_state <= 1'b0;
		end
		
		if(reset) begin //resets state to 0 and restarts the config cycle
			interface_acknowledge_state <= 1'b0;
			counter_state <= 0;
			interface_enable <= 1'b0;
		end
		
		if(SW1 == 1 && SW1_state == 0) begin //switch edge detection for volume value update
			SW1_state <= 1;
			if(volume >= 120) begin
				volume <= 0;
			end
			else begin
				volume <= volume + 20;
			end
		end
		
		if(SW1 == 0 && SW1_state == 1) begin
			SW1_state <= 0;
		end
	end
	
	
	
	//i2c_address and i2c_data output
	//See datasheet and report for specifics of what each write does, for the most part it is the same as provided code
	//except changing a few minor values like # of bits per cycle
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
			11: begin//volume, continuously write at this address
				i2c_address = 16'h0022; 
				i2c_data = {1'b0, volume, 1'b0, volume};
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
