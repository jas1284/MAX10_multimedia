// sdram access arbiter for 2 reading and 1 writing device
// in this case, the video playback and audio playback both contend for reading
// and the SDcard readout is the 1 writing device.
module sdram_access_ctl(
    input   clk50,

    input   sw_write_override,      // literal switch signal for write to take precedence
    input   sw_rd_1en,              // switch signal for '1' to read
    // signals for the avl bus master (to SDRAM controller)
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
    output logic ack_out_write,
    output logic [15:0]   readdata_out_1,
    output logic [15:0]   readdata_out_2
);

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

    case (sw_write_override)
        1'b1    :   
            begin   // writing peripheral controls bus
                addr_out_toavl  = addr_in_write;
                write_out_toavl = write_in;
                ack_out_write   = ack_in_toavl;
            end
        1'b0    :
            begin   // 1 of the 2 read peripherals controls bus
                case (sw_rd_1en)
                    1'b1    :   // override read control to peripheral "1"
                    begin
                        addr_out_toavl  = addr_in_1;
                        read_out_toavl  = read_in_1;
                        readdata_out_1  = rddata_in_toavl;
                        ack_out_1       = ack_in_toavl;
                    end
                    1'b0    :   // otherwise, it's peripheral "2"'s turn
                    begin
                        addr_out_toavl  = addr_in_2;
                        read_out_toavl  = read_in_2;
                        readdata_out_2  = rddata_in_toavl;
                        ack_out_2       = ack_in_toavl;
                    end
                endcase
            end
    endcase
end

endmodule
