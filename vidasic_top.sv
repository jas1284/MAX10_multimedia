module vidasic_top (
    input clk50,
    input run,  // enable-run, or halts
    input reset,
    input key,
    // SDRAM connections
    output logic ram_rden,
    output logic [24:0] ram_addr,
    input  [15:0] ram_data,
    input  ram_ack,
    output logic status_1,
    output logic status_2,   
    // VGA connections
    output [3:0] red,
    output [3:0] green,
    output [3:0] blue,
    output hsync,
    output vsync,
    output logic [3:0] hex_out_5,
    output logic [3:0] hex_out_4,
	output logic [3:0] hex_out_3,
	output logic [3:0] hex_out_2,
	output logic [3:0] hex_out_1,
	output logic [3:0] hex_out_0
);

logic [24:0]    READ_ADDR, READ_ADDR_NEXT;  // current address of read from buffer.
logic [15:0]    READ_WORD;  // word to load into queue
logic [5:0]     SHIFTCOUNT, SHIFTCOUNT_NEXT; // keeps track of how many shifts happened.
logic [47:0]    BITQUEUE, BITQ_NEXT;    // queue of bits coming in
logic Q_RDY; // Is the queue safe to read from? 

// Values for Ram buffering logic
logic RAM_DATA_BUFFER_EN; // Flag for enabling the RAM_DATA_BUFFER.
logic RAM_DATA_BUFFER_STATE; // Buffered state for operation of RAM data buffer. 
logic [15:0]    RAM_BUFFERED_READBACK;

// 47:32 31:16 15:0
// assuming shift left, and read from left to right. Don't know if this is actually accurate. 

enum logic [12:0] 
    {q_shift, 
    q_shift_release, 
    q_prefetch,
    q_prefetch_release,
    q_load1, 
    q_load1_wait, 
    q_load2, 
    q_load2_wait, 
    q_load3, 
    q_load3_wait
    } queue_state, q_nextstate;

assign hex_out_5 = BITQUEUE[47:44];
assign hex_out_4 = BITQUEUE[43:40];
assign hex_out_3 = BITQUEUE[39:36];
assign hex_out_2 = BITQUEUE[35:32];
assign hex_out_1 = BITQUEUE[31:28];
assign hex_out_0 = BITQUEUE[27:24];

logic slowclk;

always_ff @ (posedge clk50 or posedge reset)
begin
    if(reset)
        slowclk <= 1'b0;
    else
        slowclk <= ~slowclk;
end

always_ff @ (posedge clk50 or posedge reset)
begin
    if(reset)
    begin
        BITQUEUE <= 48'h0;
        SHIFTCOUNT <= 6'h0;
        queue_state <= q_load3;
        READ_ADDR <= 25'h00;    // temp test starting addr of 08, but should start from 0
    end
    else if(run)
    begin
        BITQUEUE <= BITQ_NEXT;
        SHIFTCOUNT <= SHIFTCOUNT_NEXT;
        queue_state <= q_nextstate;
        READ_ADDR <= READ_ADDR_NEXT;
    end
end

// Ram readback buffering mechanism - makes sure we don't miss data.
always_ff @ (posedge clk50 or posedge reset)
begin
    if(reset)
    begin
        RAM_BUFFERED_READBACK <= 16'h0;
        RAM_DATA_BUFFER_STATE <= 1'b0;  // state: inactive
    end
    else if(RAM_DATA_BUFFER_STATE)  // If active state...
    begin
        if(ram_ack) begin
            RAM_BUFFERED_READBACK <= ram_data;
            RAM_DATA_BUFFER_STATE <= 0; // go back to inactive/unarmed state.
        end
    end
    else
        RAM_DATA_BUFFER_STATE <= RAM_DATA_BUFFER_EN;    // Wait to be activated.
end

always_comb 
begin
    // default values: 
    BITQ_NEXT = BITQUEUE;       // queue doesnt move
    READ_ADDR_NEXT = READ_ADDR; // addr doesnt change
    SHIFTCOUNT_NEXT = SHIFTCOUNT;   // shift-counter stays
    ram_addr = READ_ADDR;       // Pre-set the ram address
    ram_rden = 1'b0; 
    q_nextstate = queue_state;  // stay in current state
    status_1 = 1'b0;    // lights - blank em 
    // status_2 = 1'b0;
    Q_RDY = 1'b0;   // Assume the queue's NOT READY unless otherwise stated.
    RAM_DATA_BUFFER_EN = 1'b0;  // Ram buffering mechanism assumes no incoming data.


    case (queue_state)
        q_shift: begin
            Q_RDY = 1'b1;
            if(shiftsig)
                q_nextstate = q_shift_release;
        end
        q_shift_release :   // TEMP STATE release for testing, should be q_shift_load
        begin
            Q_RDY = 1'b1;
            if(~shiftsig)
            begin
                q_nextstate = q_shift;              // TESTING PURPOSE!
                BITQ_NEXT = BITQUEUE << 1;          // shift the bitqueue, should be 1, 4 to test
                SHIFTCOUNT_NEXT = SHIFTCOUNT + 1;   // shift count increments, should be 1 (4 to test)
                // if (SHIFTCOUNT_NEXT >= 16) begin
                //     ram_rden = 1'b1;        // Call upon RAM to send data.
                //     // ram_addr = READ_ADDR;
                //     if(RAM_DATA_BUFFER_STATE == 1'b0) begin // If the buffer has disarmed, it must have caught data
                //         // q_nextstate = q_shift;  // we should be clear to return to normal operation.
                //         ram_rden = 1'b0;    // let the RAM rest
                //         BITQ_NEXT[15:8] = RAM_BUFFERED_READBACK[7:0];    // little-vs-big-endian tomfoolery
                //         BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
                //         READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
                //         SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
                //     end
                // end
                if(SHIFTCOUNT_NEXT >= 7) begin     // Note that since we're in a COMB thus must use shiftcount_next!
                    q_nextstate = q_prefetch;  // we need to top up the queue. 
                    ram_rden = 1'b1;        // Call upon RAM to send data.
                    // ram_addr = READ_ADDR;
                    RAM_DATA_BUFFER_EN = 1'b1;  // Arm the RAM readback data buffer
                    status_1 = 1'b1;
                    // SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
                    // Q_RDY = 1'b0;  // Un-ready the queue!
                end
            end
        end
        q_prefetch: begin
            Q_RDY = 1'b1;
            ram_rden = 1'b1;
            status_1 = 1'b1;
            if(shiftsig)
                q_nextstate = q_prefetch_release;
        end
        q_prefetch_release: begin
            Q_RDY = 1'b1;
            ram_rden = 1'b1;
            status_1 = 1'b1;
            if(~shiftsig)
            begin
                q_nextstate = q_prefetch;              // TESTING PURPOSE!
                BITQ_NEXT = BITQUEUE << 1;          // shift the bitqueue, should be 1, 4 to test
                SHIFTCOUNT_NEXT = SHIFTCOUNT + 1;   // shift count increments, should be 1 (4 to test)
                if(SHIFTCOUNT_NEXT >= 16) begin // If the buffer has disarmed, it must have caught data
                    q_nextstate = q_shift;  // we should be clear to return to normal operation.
                    ram_rden = 1'b0;    // let the RAM rest
                    BITQ_NEXT[15:8] = RAM_BUFFERED_READBACK[7:0];    // little-vs-big-endian tomfoolery
                    BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
                    READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
                    SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
                end
            end

        end
        // q_prefetch  :   // should be just like normal, but also sends out rden/addr
        // begin
        //     ram_rden = 1'b1;
        //     ram_addr = READ_ADDR;
        //     BITQ_NEXT = BITQUEUE << 1;  // shift the bitqueue
        //     SHIFTCOUNT_NEXT = SHIFTCOUNT + 1;
        //     if(SHIFTCOUNT >= 16) begin   // little early for prefetch on 50mhz, but dont bother by hand
        //         q_nextstate = q_load1;
        //         SHIFTCOUNT_NEXT = 0;
        //     end
        // end
        q_load1 : begin // load 1st word - most common
            ram_rden = 1'b1;        // Call upon RAM to send data.
            // ram_addr = READ_ADDR;
            RAM_DATA_BUFFER_EN = 1'b1;  // Arm the RAM readback data buffer
            status_1 = 1'b1;
            q_nextstate = q_load1_wait;
        end
        q_load1_wait : begin
            ram_rden = 1'b1;        // Call upon RAM to send data.
            // ram_addr = READ_ADDR;
            if(RAM_DATA_BUFFER_STATE == 1'b0) begin // If the buffer has disarmed, it must have caught data
                q_nextstate = q_shift;  // we should be clear to return to normal operation.
                ram_rden = 1'b0;    // let the RAM rest
                BITQ_NEXT[15:8] = RAM_BUFFERED_READBACK[7:0];    // little-vs-big-endian tomfoolery
                BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
                READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
            end
            // otherwise, we keep waiting, lol.
        end
        q_load3 : begin // load 3rd word
            ram_rden = 1'b1;
            // ram_addr = READ_ADDR;
            if(ram_ack) begin
                q_nextstate = q_load3_wait;
                BITQ_NEXT[47:40] = ram_data[7:0];    // little-vs-big-endian tomfoolery
                BITQ_NEXT[39:32] = ram_data[15:8];
                READ_ADDR_NEXT = READ_ADDR + 1;
            end
            // status_2 = 1'b1;
            status_1 = 1'b1;
        end
        q_load3_wait    : begin // wait for bus to settle
            if(ram_ack == 1'b0)begin
                q_nextstate = q_load2;
            end
            // status_2 = 1'b1;
            status_1 = 1'b1;
        end
        q_load2  :  // load 2nd word
        begin
            ram_rden = 1'b1;
            // ram_addr = READ_ADDR;
            if(ram_ack) begin
                q_nextstate = q_load2_wait;
                BITQ_NEXT[31:24] = ram_data[7:0];
                BITQ_NEXT[23:16] = ram_data[15:8];
                READ_ADDR_NEXT = READ_ADDR + 1;
            end
            // status_2 = 1'b1;
        end
        q_load2_wait    : begin // wait for bus to settle
            if(ram_ack == 1'b0)begin
                q_nextstate = q_load1;
            end
            // status_2 = 1'b1;
        end
        default: ;
    endcase
end

// states for current layer being decoded
enum logic [10:0]
{
    wait_for_it,
    piclayer_readPSC,
    piclayer_skipPSC,
    piclayer_readTR,
    piclayer_readPTYPE,
    goblayer,
    mblayer
}   cur_layer, next_layer;
logic [5:0] countdown, countdown_next;
logic shiftsig, shiftsig_next;
logic [4:0] saved_TR, next_TR;

// FF Logic for the big-bloody-state-machine!
always_ff @( posedge clk50 or posedge reset ) begin
    if(reset) begin
        saved_TR <= 0;
        cur_layer <= piclayer_readPSC;  // first thing is to always read PSC.
        countdown <= 0;
    end
    else if (Q_RDY) begin   // Only run if the queue is ready-to-go!
        saved_TR <= next_TR;
        cur_layer <= next_layer;
        countdown <= countdown_next;
    end
end

// Need to run the shift signal on a slower clock...? lol oops
always_ff @(posedge clk50 or posedge reset) begin
    if(reset)
        shiftsig <= 0;
    else 
        shiftsig <= shiftsig_next;
end

always_comb begin
    status_2 = 1'b0;
    next_layer = cur_layer;
    countdown_next = countdown;
    shiftsig_next = shiftsig;
    next_TR = saved_TR;
    case (cur_layer)
        piclayer_readPSC : begin
            if(PSC) begin
                status_2 = 1'b1;
                countdown_next = 6'd20;
                next_layer = piclayer_skipPSC;
            end
        end
        piclayer_skipPSC : begin
            if(countdown > 0) begin
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else 
                next_layer = piclayer_readTR;
        end
        piclayer_readTR : begin
            next_TR = TR;
        end
        default: ;
    endcase
end

logic [5:0] skipcount;  // counter - How many bits to skip?

// Values related to picture layer, from bitqueue.
logic PSC;      // boolean value - is the left 20 bits a PSC? (dump the data, skipcount)
logic [4:0] TR; // Temporal Reference, read back from the bitqueue.
logic PTYPE;    // boolean value - is the PTYPE as expected?
logic PEI;      // boolean value - is there extra info? (dump if present, setting skipcount)

assign PSC = (BITQUEUE[47:28] == 20'h00010);    // Boolean value 
assign TR = BITQUEUE[47:43];    // 5-bits of Temporal Reference.
// Should be value in previous picture header + 1 + however many skipped frames (ideally 0)
assign PTYPE = (BITQUEUE[47:42] == 6'b001011);  // PTYPE sanity check
// Should always be 001011; No split screen, No document camera, Freeze picture is released, QCIF, Reservedx2.
assign PEI = BITQUEUE[47];   // PEI - if spare info is available
// We won't handle this, and AFAIK this was never expanded upon. We will dump any PSPARE info if somehow present.

// Values for the Group Block layer
logic GBSC;     // boolean value - is the left 16 bits a GBSC?
logic GN;       // Group Number, read back from bitqueue
logic [4:0] GQUANT; // Quantizer Information - cryptic, 5 bits.
// I should figure out wtf quantizer information even does for us. 
// Something about a natural binary representation of quantizer values?
logic GEI;      // boolean value - is there extra info? (dump if present, just like PEI.)

assign GBSC = (BITQUEUE[47:32] == 20'h0001);
assign GN = BITQUEUE[47:44];    // 4 bit value
assign GQUANT = TR; // 5 bits - 5 is 5 i guess.
assign GEI = PEI;   // indeed, just the same, but out of order and renamed for convenience

// Values for the Macroblock layer
logic [5:0] MBA;        // 0-33, translated value for the Macroblock Address
logic [3:0] MBA_SKIP;   // 1-11, how many bits to skip to clear the MBA from queue.
logic MTYPE_MQUANT_PRESENT; // boolean - according to MTYPE, is MQUANT present?
logic MTYPE_MVD_PRESENT;    // boolean - according to MTYPE, is MVD present?
logic MTYPE_CBP_PRESENT;    // boolean - according to MTYPE, is CBP present?
logic MTYPE_TCOEFF_PRESENT; // boolean - according to MTYPE, is TCOEFF present?
logic [3:0] MTYPE_SKIP;     // 1-10, how many bits to skip to clear the MTYPE from queue?

// Define MBA and MBA_SKIP values:
always_comb begin
    casez (BITQUEUE[47:37]) // just check 11 bits
        11'b1??????????:   begin
            MBA = 6'd1;
            MBA_SKIP = 4'd1;
        end
        11'b011????????:    begin
            MBA = 6'd2;
            MBA_SKIP = 4'd3;
        end
        11'b010????????:    begin
            MBA = 6'd3;
            MBA_SKIP = 4'd3;
        end
        11'b0011???????:    begin
            MBA = 6'd4;
            MBA_SKIP = 4'd4;
        end
        11'b0010???????:    begin
            MBA = 6'd5;
            MBA_SKIP = 4'd4;
        end
        11'b00011??????:    begin
            MBA = 6'd6;
            MBA_SKIP = 4'd5;
        end
        11'b00010??????:    begin
            MBA = 6'd7;
            MBA_SKIP = 4'd5;
        end
        11'b0000111????:    begin
            MBA = 6'd8;
            MBA_SKIP = 4'd7;
        end
        11'b0000110????:    begin
            MBA = 6'd9;
            MBA_SKIP = 4'd7;
        end
        11'b00001011???:    begin
            MBA = 6'd10;
            MBA_SKIP = 4'd8;
        end
        11'b00001010???:    begin
            MBA = 6'd11;
            MBA_SKIP = 4'd8;
        end
        11'b00001001???:    begin
            MBA = 6'd12;
            MBA_SKIP = 4'd8;
        end
        11'b00001000???:    begin
            MBA = 6'd13;
            MBA_SKIP = 4'd8;
        end
        11'b00000111???:    begin
            MBA = 6'd14;
            MBA_SKIP = 4'd8;
        end
        11'b00000110???:    begin
            MBA = 6'd15;
            MBA_SKIP = 4'd8;
        end
        11'b0000010111?:    begin
            MBA = 6'd16;
            MBA_SKIP = 4'd10;
        end
        11'b0000010110?:    begin
            MBA = 6'd17;
            MBA_SKIP = 4'd10;
        end
        11'b0000010101?:    begin
            MBA = 6'd18;
            MBA_SKIP = 4'd10;
        end
        11'b0000010100?:    begin
            MBA = 6'd19;
            MBA_SKIP = 4'd10;
        end
        11'b0000010011?:    begin
            MBA = 6'd20;
            MBA_SKIP = 4'd10;
        end
        11'b0000010010?:    begin
            MBA = 6'd21;
            MBA_SKIP = 4'd10;
        end
        11'b00000100011:    begin
            MBA = 6'd22;
            MBA_SKIP = 4'd11;
        end
        11'b00000100010:    begin
            MBA = 6'd23;
            MBA_SKIP = 4'd11;
        end
        11'b00000100001:    begin
            MBA = 6'd24;
            MBA_SKIP = 4'd11;
        end
        11'b00000100000:    begin
            MBA = 6'd25;
            MBA_SKIP = 4'd11;
        end
        11'b00000011111:    begin
            MBA = 6'd26;
            MBA_SKIP = 4'd11;
        end
        11'b00000011110:    begin
            MBA = 6'd27;
            MBA_SKIP = 4'd11;
        end
        11'b00000011101:    begin
            MBA = 6'd28;
            MBA_SKIP = 4'd11;
        end
        11'b00000011100:    begin
            MBA = 6'd29;
            MBA_SKIP = 4'd11;
        end
        11'b00000011011:    begin
            MBA = 6'd30;
            MBA_SKIP = 4'd11;
        end
        11'b00000011010:    begin
            MBA = 6'd31;
            MBA_SKIP = 4'd11;
        end
        11'b00000011001:    begin
            MBA = 6'd32;
            MBA_SKIP = 4'd11;
        end
        11'b00000011000:    begin
            MBA = 6'd33;
            MBA_SKIP = 4'd11;
        end
        11'b00000001111:    begin
            MBA = 6'd34;    // STUFFING, but we will call it 6'd34.
            MBA_SKIP = 4'd11;
        end
        default: begin
            MBA = 6'd35;   // Consider this an error.
            MBA_SKIP = 4'd15;
        end
    endcase
end

// Define MTYPE values:
always_comb begin
    // default values: all 0
    MTYPE_MQUANT_PRESENT = 1'b0;
    MTYPE_MVD_PRESENT = 1'b0;
    MTYPE_CBP_PRESENT = 1'b0;
    MTYPE_TCOEFF_PRESENT = 1'b0;
    casez (BITQUEUE[47:38]) // just check 10 bits
        10'b1?????????:   begin    // Inter
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd1;
        end
        10'b01????????:   begin    // Inter + MC + FIL
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd2;
        end
        10'b001???????:   begin    // Inter + MC + FIL
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd3;
        end
        10'b0001??????:   begin    // Intra
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd4;
        end
        10'b00001?????:   begin    // Inter
            MTYPE_MQUANT_PRESENT = 1'b1;
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd5;
        end
        10'b000001????:   begin    // Inter + MC + FIL
            MTYPE_MQUANT_PRESENT = 1'b1;
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd6;
        end
        10'b0000001???:   begin    // Intra
            MTYPE_MQUANT_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd7;
        end
        10'b00000001??:   begin    // Inter + MC
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd8;
        end
        10'b000000001?:   begin    // Inter + MC
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd9;
        end
        10'b0000000001:   begin    // Inter + MC
            MTYPE_MQUANT_PRESENT = 1'b1;
            MTYPE_MVD_PRESENT = 1'b1;
            MTYPE_CBP_PRESENT = 1'b1;
            MTYPE_TCOEFF_PRESENT = 1'b1;
            MTYPE_SKIP = 4'd10;
        end
        default: begin
            MTYPE_SKIP = 4'd15; // Consider this an ERROR
        end 
    endcase
end

// Since targeting I-frames only - that is, intra-frames so far as I understand -
// should be safe to skip inter-frame handling. I will find out soon, i suppose, lol. 
    
endmodule