module I2C_interface (
	input  logic clk50,
	input  logic reset_interface,
	input  logic [15:0] i2c_addr,
	input  logic [15:0] i2c_data,
	input  logic enable, //sends current contents of i2c_addr and i2c_data upon recieving enable
	output logic acknowledge, //1 if in reset state
	
	output logic i2c_scl,
	output logic i2c_sda,	
	input  logic sda_in
	);
	
	logic [8:0] scl_period; //amount of clk50 cycles for each SCL clock period
	logic [8:0] scl_high = 320; //amount of clk50cycles for each SCL high clock period 310
	logic [8:0] scl_low = 210; //amount of clk50cycles for each SCL low clock period 190
	
	assign scl_period = scl_high + scl_low;
	
	logic [17:0] clk50_count = 0;
	logic [5:0] bit_addr = 0;
	
	logic scl_state = 1;
	logic acknowledge_recieved = 0;
	
	logic [39:0] writedata;
	
	logic firstinit = 0;
	
	enum logic [12:0] 
    {reset,
	 delay_0,
    init_high, 
    init_low,
    high,
    low, 
    ack_high, 
    ack_low, 
    stop,
	 delay
    } state, nextstate = reset;
	 
	 logic [7:0] dest_address = 8'b00010100;
	 
	 //logic i2c_scl;
	 //logic i2c_sda;
	 
	 //assign i2c_scl_out = i2c_scl + 1; //invert for correct output
	 //assign i2c_sda_out = i2c_sda + 1; //invert for correct output
	 
	 assign writedata = {dest_address, i2c_addr, i2c_data};
	 
	 
	 
	always_ff @ (posedge clk50) begin
		state <= nextstate;
		if(state != nextstate || state == reset) clk50_count <= 0;
		else clk50_count <= clk50_count + 1;
		acknowledge_recieved <= acknowledge_recieved;
		
		//edge detection
		if(i2c_scl == 1) begin
			scl_state <= 1;
		end
		else if(i2c_scl == 0 && scl_state == 1 && state == low && clk50_count == scl_low / 2) begin //rising scl edge and writing a bit
			bit_addr <= bit_addr + 1;
			scl_state <= 0;
		end
		if(sda_in == 1 && (state == ack_high || state == ack_low)) begin //recieved ack signal from slave
			acknowledge_recieved <= 1;
		end
		else if(state == stop) begin
			acknowledge_recieved <= 0;
			bit_addr <= 0;
		end
		
		if(reset_interface) begin
			state <= reset;
			clk50_count <= 0;
			bit_addr <= 0;
			acknowledge_recieved <= 0;
			firstinit <= 0;
		end
		
		if(state == delay_0) begin
			firstinit <= 1;
		end
	
		
	end
	 
	//combinational logic for states
	always_comb begin
		nextstate = state;
		if(state == reset) acknowledge = 1;
		else acknowledge = 0;
		
		case (state)
			reset : begin
				if(enable) begin //edge detection for enable
					if(firstinit == 0) begin
						nextstate = delay_0;
					end
					else if(firstinit == 1) begin
						nextstate = init_high;
					end
				end
			end
			delay_0 : begin
				if(clk50_count >= 120000) begin
					nextstate = init_high;
				end
			end
			init_high : begin
				if(clk50_count >= scl_high) begin
					nextstate = init_low;
				end
			end
			init_low : begin
				if(clk50_count >= scl_low) begin
					nextstate = high;
				end
			end
			high : begin
				if(clk50_count >= scl_high) begin
					nextstate = low;
				end
			end
			low : begin
				if(clk50_count >= scl_low) begin
					if(bit_addr == 8 || bit_addr == 16 || bit_addr == 24 || bit_addr == 32 || bit_addr == 40) begin
						nextstate = ack_high;
					end
					else begin
						nextstate = high;
					end
					
				end
			end
			ack_high : begin
				if(clk50_count >= scl_high) begin
					nextstate = ack_low;
				end
			end
			ack_low : begin
				if(clk50_count >= scl_low) begin
					if(acknowledge_recieved == 1 || acknowledge_recieved == 0) begin //TODO remove for testing, needs to check for ack
						if(bit_addr == 40) begin
							nextstate = stop;
						end
						else begin
							nextstate = high;
						end
					end
					else begin
						nextstate = ack_high;
					end
				end
			end
			stop : begin
				if(clk50_count >= scl_high) begin
					nextstate = delay;
				end
			end
			delay : begin
				if(clk50_count >= scl_period) begin
					nextstate = reset;
				end
			end
			default: ;
		endcase
			
		i2c_scl = 1'b1;
		i2c_sda = 1'b1;
		case (state)
			reset : begin
				i2c_scl = 1'b1;
				i2c_sda = 1'b1;
			end
			init_high : begin
				i2c_scl = 1'b1;
				i2c_sda = 1'b0;
			end
			init_low : begin
				i2c_scl = 1'b0;
				i2c_sda = 1'b0;
			end
			high : begin
				i2c_scl = 1'b1;
				i2c_sda = writedata[39 - bit_addr];
			end
			low : begin
				i2c_scl = 1'b0;
				i2c_sda = writedata[39 - bit_addr];
				if(clk50_count > scl_low / 2) begin
					if(bit_addr == 8 || bit_addr == 16 || bit_addr == 24 || bit_addr == 32 || bit_addr == 40) begin
						//nextstate = ack_high;
						i2c_sda = 1'b1;
					end
				end
			end
			ack_high : begin
				i2c_scl = 1'b1;
				i2c_sda = 1'b1;
			end
			ack_low : begin
				i2c_scl = 1'b0;
				if(clk50_count <= scl_low / 2) begin
					i2c_sda = 1'b1;
				end
				else begin
					i2c_sda = writedata[39 - bit_addr];
				end
			end
			stop : begin
				i2c_scl = 1'b1;
				i2c_sda = 1'b0;
			end
			delay : begin
				i2c_scl = 1'b1;
				i2c_sda = 1'b1;
			end
			default: ;
		endcase
	end
	 
endmodule