// sdram access arbiter for 2 reading and 1 writing device
// in this case, the video playback and audio playback both contend for reading
// and the SDcard readout is the 1 writing device.
module sdram_access_ctl(
    input   clk50,
    input   reset,

    input   sw_write_override,      // literal switch signal for write to take precedence
    input   sw_rd_1en,              // switch signal for '1' to read
    // signals for the avl bus master (to SDRAM controller)
    output logic sd_write_resume,
    output logic [25:0]   addr_out_toavl,
    output logic read_out_toavl,
    output logic write_out_toavl,
    input [15:0]    rddata_in_toavl,
    input   ack_in_toavl,

    // signals for the peripherals
    input [25:0]    addr_in_1,
    input [25:0]    addr_in_2,
    input [25:0]    addr_in_write,
    input   read_in_1,
    input   read_in_2,
    input   write_in,   // just 1 writing device

    output logic ack_out_1,
    output logic ack_out_2,
    output logic ack_out_write_o,
    output logic [15:0]   readdata_out_1,
    output logic [15:0]   readdata_out_2
);

logic saved_rden, next_rden;
logic op_wr_override, next_op_wr_override;
logic saved_read_half, next_read_half;
logic ack_out_write;

always_ff @( posedge clk50 or posedge reset) begin
    if(reset) begin
        saved_rden <= 1'b0;
        op_wr_override <= 1'b0;
        saved_read_half <= 1'b1;    // Start at "top half" so that resume triggers on start.
        sd_write_resume <= 1'b1;
    end
    else begin
        saved_rden = next_rden;
        op_wr_override <= next_op_wr_override;
        saved_read_half <= next_read_half;
        sd_write_resume <= (saved_read_half == (~next_read_half));
    end
end

always_comb
begin
    //default vals:
    read_out_toavl = 1'b0;
    write_out_toavl = 1'b0;
    addr_out_toavl = 25'h0;
    ack_out_1 = 1'b0;
    ack_out_2 = 1'b0;
    ack_out_write = 1'b0;
    readdata_out_1 = 16'h0;
    readdata_out_2 = 16'h0;
    next_rden = 1'b0;
    next_op_wr_override = op_wr_override;
    next_read_half = saved_read_half;

    case (op_wr_override)
        1'b1 :  begin
            addr_out_toavl  = addr_in_write;
            write_out_toavl = write_in;
            ack_out_write   = ack_in_toavl;
            next_rden = 1'b0;
            if(ack_in_toavl) begin
                next_op_wr_override = 1'b0;
                write_out_toavl = 1'b0;
            end
        end
        1'b0 : begin
            case (sw_write_override)
                1'b1    :   
                    begin   // writing peripheral controls bus
                        addr_out_toavl  = addr_in_write;
                        write_out_toavl = write_in;
                        ack_out_write   = ack_in_toavl;
                        next_rden = 1'b0;
                    end
                1'b0    :
                    begin   // 1 of the 2 read peripherals controls bus
                        case (sw_rd_1en)
                            1'b1    :   // override read control to peripheral "1"
                            begin
                                addr_out_toavl  = addr_in_1;
                                next_read_half = addr_in_1[23];
                                read_out_toavl  = read_in_1;
                                next_rden = read_in_1;
                                readdata_out_1  = rddata_in_toavl;
                                ack_out_1       = ack_in_toavl;
                            end
                            1'b0    :   // otherwise, it's peripheral "2"'s turn
                            begin
                                addr_out_toavl  = addr_in_2;
                                next_read_half = addr_in_2[23];
                                read_out_toavl  = read_in_2;
                                next_rden = read_in_2;
                                readdata_out_2  = rddata_in_toavl;
                                ack_out_2       = ack_in_toavl;
                            end
                        endcase
                    end
            endcase
        end
        default: ;
    endcase

    if((!next_rden) & saved_rden) begin // If RDEN just got de-asserted
        if(write_in)begin   // if there's a pending write
            addr_out_toavl = addr_in_write;
            read_out_toavl = 1'b0;
            write_out_toavl = 1'b1;
            next_op_wr_override = 1'b1;
        end
    end
end

assign ack_out_write_o = ack_out_write_reg;

logic ack_out_write_reg, ack_out_write_reg_next;
logic [2:0] ack_out_write_counter, ack_out_write_counter_next;

always_ff @( posedge clk50 or posedge reset) begin
    if(reset) begin
        ack_out_write_reg <= 1'b0;
        ack_out_write_counter <= 1'b0;
    end
    else begin
        ack_out_write_reg <= ack_out_write_reg_next;
        ack_out_write_counter <= ack_out_write_counter_next;
    end
end

always_comb begin
    ack_out_write_counter_next = ack_out_write_counter;
    ack_out_write_reg_next = ack_out_write_reg;
    if(ack_out_write) begin
        ack_out_write_reg_next = 1'b1;
        ack_out_write_counter_next = ack_out_write_counter + 1;
    end
    if(ack_out_write_counter >= 5)begin
        ack_out_write_reg_next = 1'b0;
        ack_out_write_counter_next = 0;
    end
end


endmodule
