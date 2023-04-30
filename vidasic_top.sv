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

// logic slowclk;

// always_ff @ (posedge clk50 or posedge reset)
// begin
//     if(reset)
//         slowclk <= 1'b0;
//     else
//         slowclk <= ~slowclk;
// end

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
    piclayer_skipTR,
    piclayer_readPTYPE,
    piclayer_skipPTYPE,
    piclayer_readGBSC,
    piclayer_skipGBSC,
    piclayer_readGN,
    piclayer_skipGN,
    piclayer_readGQUANT,
    piclayer_skipGQUANT,
    piclayer_readMBA,
    piclayer_skipMBA,
    piclayer_readMTYPE,
    piclayer_skipMTYPE,
    piclayer_readMQUANT,
    piclayer_skipMQUANT,
    piclayer_readMVD,
    piclayer_skipMVD,
    piclayer_readCBP,
    piclayer_skipCBP,
    piclayer_readTCOEFF,
    piclayer_skipTCOEFF,
    goblayer,
    mblayer
}   cur_layer, next_layer;
logic [5:0] countdown, countdown_next;
logic shiftsig, shiftsig_next;
logic [4:0] saved_TR, next_TR;
logic [3:0] saved_GN, next_GN;
logic [4:0] saved_QUANT, next_QUANT;
logic [5:0] saved_MBA, next_MBA;
logic [3:0] saved_MTYPE_vec, next_MTYPE_vec;
// logic [5:0] saved_TCOEFF_count, next_TCOEFF_count;
logic [2:0] saved_block_layer, next_block_layer;
logic [7:0] saved_TCOEFF_table [64];
logic [7:0] next_TCOEFF_table_entry;
logic [5:0] saved_TCOEFF_zigzag, next_TCOEFF_zigzag;
logic next_TCOEFF_table_WREN; // write-enable to this crazy regfile

// FF Logic for the big-bloody-state-machine!
always_ff @( posedge clk50 or posedge reset ) begin
    if(reset) begin
        for(int i = 0; i < 64; i++)
            saved_TCOEFF_table[i] <= 8'b0;
        saved_TCOEFF_zigzag <= 0;
        saved_block_layer <= 0;
        // saved_TCOEFF_count <= 0;
        saved_MTYPE_vec <= 0;
        saved_MBA <= 0;
        saved_QUANT <= 0;
        saved_GN <= 0;
        saved_TR <= 0;
        cur_layer <= piclayer_readPSC;  // first thing is to always read PSC.
        countdown <= 0;
    end
    else if (Q_RDY & run) begin   // Only run if the queue is ready-to-go!
        if(next_TCOEFF_table_WREN)
            saved_TCOEFF_table[dezigzag_raster_out] <= next_TCOEFF_table_entry;
        saved_TCOEFF_zigzag <= next_TCOEFF_zigzag;
        saved_block_layer <= next_block_layer;
        // saved_TCOEFF_count <= next_TCOEFF_count;
        saved_MTYPE_vec <= next_MTYPE_vec;
        saved_MBA <= next_MBA;
        saved_QUANT <= next_QUANT;
        saved_GN <= next_GN;
        saved_TR <= next_TR;
        cur_layer <= next_layer;
        countdown <= countdown_next;
    end
end

// Need to run the shift signal on a slower clock...? lol oops no we don't
always_ff @(posedge clk50 or posedge reset) begin
    if(reset)
        shiftsig <= 0;
    else 
        shiftsig <= shiftsig_next;
end

always_comb begin
    // default values... part of the 2-always M.O.
    status_2 = 1'b0;
    next_layer = cur_layer;
    countdown_next = countdown;
    shiftsig_next = shiftsig;
    next_TR = saved_TR;
    next_GN = saved_GN;
    next_QUANT = saved_QUANT;
    next_MBA = saved_MBA;
    next_MTYPE_vec = saved_MTYPE_vec;
    // next_TCOEFF_count = saved_TCOEFF_count;
    next_block_layer = saved_block_layer;
    next_TCOEFF_zigzag = saved_TCOEFF_zigzag;
    next_TCOEFF_table_WREN = 0; // don't write to TCOEFF TABLE unless AUTHORIZED !
    next_TCOEFF_table_entry = 0;
    case (cur_layer)
        wait_for_it:    // Consider this an ERROR STATE!
            status_2 = 1'b1;
        piclayer_readPSC : begin
            if(PSC) begin
                countdown_next = 6'd20;
                next_layer = piclayer_skipPSC;
            end
            else // we SHOULD see a PSC, or something screwed up!
                next_layer = wait_for_it;
        end
        piclayer_skipPSC : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                next_layer = piclayer_readTR;
        end
        piclayer_readTR : begin
            next_TR = TR;
            countdown_next = 6'd5;
            next_layer = piclayer_skipTR;
        end
        piclayer_skipTR : begin
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
                next_layer = piclayer_readPTYPE;
        end
        piclayer_readPTYPE : begin
            if(PTYPE) begin
                countdown_next = 6'd7;  // PTYPE is only 6, but we'll also skip PEI.
                next_layer = piclayer_skipPTYPE;
            end
            else 
                next_layer = wait_for_it;
        end
        piclayer_skipPTYPE : begin
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
                next_layer = piclayer_readGBSC;
        end
        piclayer_readGBSC : begin
            if(GBSC) begin
                countdown_next = 6'd16;
                next_layer = piclayer_skipGBSC;
            end
            else // we SHOULD see a GBSC, or something screwed up! (PEI was set)
                next_layer = wait_for_it;
        end
        piclayer_skipGBSC : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                next_layer = piclayer_readGN;
        end
        piclayer_readGN : begin
            next_GN = GN;
            countdown_next = 6'd4;
            next_layer = piclayer_skipGN;
        end
        piclayer_skipGN : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                next_layer = piclayer_readGQUANT;
        end
        piclayer_readGQUANT : begin
            next_QUANT = GQUANT;
            countdown_next = 6'd6;  // Skip 5 + GEI.
            next_layer = piclayer_skipGQUANT;
        end
        piclayer_skipGQUANT : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                next_layer = piclayer_readMBA;
        end
        piclayer_readMBA : begin
            next_MBA = saved_MBA + MBA; // Equal to previous MBA + coded MBA value
            countdown_next = MBA_SKIP;
            next_layer = piclayer_skipMBA;
            if(MTYPE_SKIP > 10)
                next_layer = wait_for_it;   // Error!
        end
        piclayer_skipMBA : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                next_layer = piclayer_readMTYPE;
        end
        piclayer_readMTYPE : begin
            next_MTYPE_vec = {MTYPE_MQUANT_PRESENT, 
                            MTYPE_MVD_PRESENT,
                            MTYPE_CBP_PRESENT,
                            MTYPE_TCOEFF_PRESENT};
            countdown_next = MTYPE_SKIP;
            next_layer = piclayer_skipMTYPE;
            if(MTYPE_SKIP > 10)
                next_layer = wait_for_it;   // Error!
        end
        piclayer_skipMTYPE : begin
            if(countdown > 0) begin // make 20 shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, onwards to TR.
                if(saved_MTYPE_vec[3])  // if MQUANT present
                    next_layer = piclayer_readMQUANT;
                else if(saved_MTYPE_vec[2]) // if MVD present
                    next_layer = piclayer_readMVD;
                else if(saved_MTYPE_vec[1]) // if CBP present
                    next_layer = piclayer_readCBP;
                else // if(saved_MTYPE_vec[0])  // finaly if somehow TCOEFF
                    next_layer = piclayer_readTCOEFF;
                    next_TCOEFF_zigzag = 0; // Up to 64 TCOEFFS per block
                    // next_TCOEFF_count = 0; // up to 64 TCOEFFS per block
                    next_block_layer = 0;  // up to 6 blocks per macroblock
                    // there is no MTYPE where NONE are present.
        end
        piclayer_readTCOEFF : begin // We're in the block-layer now
            next_layer = piclayer_skipTCOEFF;
            if(TCOEFF_EOB) begin
                countdown_next = 2; // Skip EOB
                next_layer = piclayer_skipTCOEFF;
                // next_TCOEFF_count = 0;
                next_TCOEFF_zigzag = 0;
                next_block_layer = saved_block_layer + 1;
            end
            else if(TCOEFF_ESC) begin   // We have a Fixed-Length code on our hands... special protocols!
                case (saved_QUANT[0])
                    1'b1 :  begin   // Quant ODD
                        case (BITQUEUE[35]) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * (((BITQUEUE[35:28])<< 1)+1); // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((BITQUEUE[35:28])<< 1)-1); // set CODE, signed
                            end
                        endcase
                    end
                    1'b0 :  begin   // QUANT EVEN
                        case (BITQUEUE[35]) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * (((BITQUEUE[35:28])<< 1)+1) - 1; // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((BITQUEUE[35:28])<< 1)-1) + 1; // set CODE, signed
                            end
                        endcase
                    end
                endcase
                next_TCOEFF_zigzag = saved_TCOEFF_zigzag + BITQUEUE[41:36] + 1; // RUN
                next_TCOEFF_table_WREN = 1'b1;
                countdown_next = 20;    // Skip everything since we just did the whole ass FLC
            end 
            else begin  // Not end, nor FLC, so interpret using the VLC table
                case (saved_QUANT[0])
                    1'b1 :  begin   // Quant ODD
                        case (TCOEFF_SIGN) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * ((TCOEFF_LEVEL << 1)+1); // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((0 - TCOEFF_LEVEL)<< 1)-1); // set CODE, signed
                            end
                        endcase
                    end
                    1'b0 :  begin   // QUANT EVEN
                        case (TCOEFF_SIGN) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * ((TCOEFF_LEVEL << 1)+1) - 1; // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((0 - TCOEFF_LEVEL)<< 1)-1) + 1; // set CODE, signed
                            end
                        endcase
                    end
                endcase
                next_TCOEFF_zigzag = saved_TCOEFF_zigzag + TCOEFF_RUN + 1; // RUN
                next_TCOEFF_table_WREN = 1'b1;
                countdown_next = TCOEFF_skip;
            end
        end
        piclayer_skipTCOEFF : begin
            if(countdown > 0) begin
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else begin  // done? ok, decision time
                next_layer = piclayer_readTCOEFF;
                if(saved_block_layer >= 6) begin // If we just finished the last block...
                    next_layer = piclayer_readMBA;
                    if(saved_MBA >= 33) begin    // If we just finished the last MBA...
                        next_layer = piclayer_readGBSC;
                        if(saved_GN >= 5) begin // If we just finished the last GOB...
                            next_layer = piclayer_readPSC;
                        end
                    end
                end
            end
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

logic TCOEFF_EOB;           // Boolean, output of LUT: Is it end-of-block?
logic TCOEFF_FIRSTCOEFF;     // Boolean, INPUT of LUT: Is it the first coefficient in the block?
logic [4:0] TCOEFF_RUN;     // Magnitude, output, of RUN
logic TCOEFF_SIGN;          // Boolean, output, Sign of the output value
logic [3:0] TCOEFF_LEVEL;   // Magnitude, output, of LEVEL
logic TCOEFF_ESC;           // Boolean, Escape? (indicates 20-bit encoding to follow.)
logic [3:0] TCOEFF_skip;    // output of LUT, How many bits to skip? 

assign TCOEFF_FIRSTCOEFF = (saved_TCOEFF_zigzag == 0);  // If filling (0,0) then it's gotta be firstCOEFF.

always_comb begin
    TCOEFF_EOB = 0;
    TCOEFF_ESC = 0;
    TCOEFF_SIGN = 0;
    TCOEFF_RUN = 5'd31;     // Set to unreachable value, interpret as ERROR!
    TCOEFF_LEVEL = 4'd0;    // Leval cannot be zero, interpret as ERROR!
    TCOEFF_skip = 0;        // Shouldn't be zero - again, interpret as ERROR!
    casez (BITQUEUE[47:34])
        14'b0100?????????? : begin
            TCOEFF_SIGN = BITQUEUE[43];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd5;
        end
        14'b00101????????? : begin
            TCOEFF_SIGN = BITQUEUE[42];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd6;
        end
        14'b0000110??????? : begin
            TCOEFF_SIGN = BITQUEUE[40];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd4;
            TCOEFF_skip = 4'd8;
        end
        14'b00100110?????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd5;
            TCOEFF_skip = 4'd9;
        end
        14'b00100001?????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd6;
            TCOEFF_skip = 4'd9;
        end
        14'b0000001010???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd7;
            TCOEFF_skip = 4'd11;
        end
        14'b000000011101?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd8;
            TCOEFF_skip = 4'd13;
        end
        14'b000000011000?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd9;
            TCOEFF_skip = 4'd13;
        end
        14'b000000010011?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd10;
            TCOEFF_skip = 4'd13;
        end
        14'b000000010000?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd11;
            TCOEFF_skip = 4'd13;
        end
        14'b0000000011010? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd12;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011001? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd13;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011000? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd14;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000010111? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd15;
            TCOEFF_skip = 4'd14;
        end
        14'b011??????????? : begin
            TCOEFF_SIGN = BITQUEUE[44];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd04;
        end
        14'b000110???????? : begin
            TCOEFF_SIGN = BITQUEUE[41];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd07;
        end
        14'b00100101?????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd09;
        end
        14'b0000001100???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd4;
            TCOEFF_skip = 4'd11;
        end
        14'b000000011011?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd5;
            TCOEFF_skip = 4'd13;
        end
        14'b0000000010110? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd6;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000010101? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd1;
            TCOEFF_LEVEL = 4'd7;
            TCOEFF_skip = 4'd14;
        end
        14'b0101?????????? : begin
            TCOEFF_SIGN = BITQUEUE[43];
            TCOEFF_RUN = 5'd2;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd5;
        end
        14'b0000100??????? : begin
            TCOEFF_SIGN = BITQUEUE[40];
            TCOEFF_RUN = 5'd2;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd8;
        end
        14'b0000001011???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd2;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd11;
        end
        14'b000000010100?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd2;
            TCOEFF_LEVEL = 4'd4;
            TCOEFF_skip = 4'd13;
        end
        14'b0000000010100? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd2;
            TCOEFF_LEVEL = 4'd5;
            TCOEFF_skip = 4'd14;
        end
        14'b00111????????? : begin
            TCOEFF_SIGN = BITQUEUE[42];
            TCOEFF_RUN = 5'd3;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd6;
        end
        14'b00100100?????? : begin
            TCOEFF_SIGN = BITQUEUE[41];
            TCOEFF_RUN = 5'd3;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd9;
        end
        14'b000000011100?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd3;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd13;
        end
        14'b0000000010011? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd3;
            TCOEFF_LEVEL = 4'd4;
            TCOEFF_skip = 4'd14;
        end
        14'b00110????????? : begin
            TCOEFF_SIGN = BITQUEUE[42];
            TCOEFF_RUN = 5'd4;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd6;
        end
        14'b0000001111???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd4;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd11;
        end
        14'b000000010010?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd4;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd13;
        end
        14'b000111???????? : begin
            TCOEFF_SIGN = BITQUEUE[41];
            TCOEFF_RUN = 5'd5;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd7;
        end
        14'b0000001001???? : begin
            TCOEFF_SIGN = BITQUEUE[47];
            TCOEFF_RUN = 5'd5;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd11;
        end
        14'b0000000010010? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd5;
            TCOEFF_LEVEL = 4'd3;
            TCOEFF_skip = 4'd14;
        end
        14'b000101???????? : begin
            TCOEFF_SIGN = BITQUEUE[41];
            TCOEFF_RUN = 5'd6;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd7;
        end
        14'b000000011110?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd6;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd13;
        end
        14'b000100???????? : begin
            TCOEFF_SIGN = BITQUEUE[41];
            TCOEFF_RUN = 5'd7;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd7;
        end
        14'b000000010101?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd7;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd13;
        end
        14'b0000111??????? : begin
            TCOEFF_SIGN = BITQUEUE[40];
            TCOEFF_RUN = 5'd8;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd8;
        end
        14'b000000010001?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd8;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd13;
        end
        14'b0000101??????? : begin
            TCOEFF_SIGN = BITQUEUE[40];
            TCOEFF_RUN = 5'd9;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd8;
        end
        14'b0000000010001? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd9;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd14;
        end
        14'b00100111?????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd10;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd9;
        end
        14'b0000000010000? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd10;
            TCOEFF_LEVEL = 4'd2;
            TCOEFF_skip = 4'd14;
        end
        14'b00100011??????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd11;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd9;
        end
        14'b00100010??????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd12;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd9;
        end
        14'b00100000??????? : begin
            TCOEFF_SIGN = BITQUEUE[39];
            TCOEFF_RUN = 5'd13;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd9;
        end
        14'b0000001110???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd14;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd11;
        end
        14'b0000001101????  : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd15;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd11;
        end
        14'b0000001000???? : begin
            TCOEFF_SIGN = BITQUEUE[37];
            TCOEFF_RUN = 5'd16;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd11;
        end
        14'b000000011111?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd17;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd13;
        end
        14'b000000011010?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd18;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd13;
        end
        14'b000000011001?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd19;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd13;
        end
        14'b000000010111?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd20;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd13;
        end
        14'b000000010110?? : begin
            TCOEFF_SIGN = BITQUEUE[35];
            TCOEFF_RUN = 5'd21;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd13;
        end
        14'b0000000011111? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd22;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011110? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd23;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011101? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd24;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011100? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd25;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd14;
        end
        14'b0000000011011? : begin
            TCOEFF_SIGN = BITQUEUE[34];
            TCOEFF_RUN = 5'd22;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd14;
        end
        default: ;
    endcase
    if(TCOEFF_FIRSTCOEFF) begin
        if(BITQUEUE[47]) begin
            TCOEFF_SIGN = BITQUEUE[46];
            TCOEFF_RUN = 5'd0;
            TCOEFF_LEVEL = 4'd1;
            TCOEFF_skip = 4'd2;
        end
    end
    else begin
        case (BITQUEUE[47:46])
            2'b11: begin
                TCOEFF_SIGN = BITQUEUE[45];
                TCOEFF_RUN = 5'd0;
                TCOEFF_LEVEL = 4'd1;
                TCOEFF_skip = 4'd3;
            end
            2'b10: begin
                TCOEFF_EOB = 1'b1;
                TCOEFF_skip = 4'd2;
            end
            default: ;
        endcase
    end
end

logic [5:0] dezigzag_input;
logic [5:0] dezigzag_raster_out;

assign dezigzag_input = next_TCOEFF_zigzag;

always_comb begin
    case (dezigzag_input)
        6'd0: dezigzag_raster_out = 6'd0;
        6'd1: dezigzag_raster_out = 6'd1;
        6'd2: dezigzag_raster_out = 6'd8;
        6'd3: dezigzag_raster_out = 6'd16;
        6'd4: dezigzag_raster_out = 6'd9;
        6'd5: dezigzag_raster_out = 6'd2;
        6'd6: dezigzag_raster_out = 6'd3;
        6'd7: dezigzag_raster_out = 6'd10;
        6'd8: dezigzag_raster_out = 6'd17;
        6'd9: dezigzag_raster_out = 6'd24;
        6'd10: dezigzag_raster_out = 6'd32;
        6'd11: dezigzag_raster_out = 6'd25;
        6'd12: dezigzag_raster_out = 6'd18;
        6'd13: dezigzag_raster_out = 6'd11;
        6'd14: dezigzag_raster_out = 6'd4;
        6'd15: dezigzag_raster_out = 6'd5;
        6'd16: dezigzag_raster_out = 6'd12;
        6'd17: dezigzag_raster_out = 6'd19;
        6'd18: dezigzag_raster_out = 6'd26;
        6'd19: dezigzag_raster_out = 6'd33;
        6'd20: dezigzag_raster_out = 6'd40;
        6'd21: dezigzag_raster_out = 6'd48;
        6'd22: dezigzag_raster_out = 6'd41;
        6'd23: dezigzag_raster_out = 6'd34;
        6'd24: dezigzag_raster_out = 6'd27;
        6'd25: dezigzag_raster_out = 6'd20;
        6'd26: dezigzag_raster_out = 6'd13;
        6'd27: dezigzag_raster_out = 6'd6;
        6'd28: dezigzag_raster_out = 6'd7;
        6'd29: dezigzag_raster_out = 6'd14;
        6'd30: dezigzag_raster_out = 6'd21;
        6'd31: dezigzag_raster_out = 6'd28;
        6'd32: dezigzag_raster_out = 6'd35;
        6'd33: dezigzag_raster_out = 6'd42;
        6'd34: dezigzag_raster_out = 6'd49;
        6'd35: dezigzag_raster_out = 6'd56;
        6'd36: dezigzag_raster_out = 6'd57;
        6'd37: dezigzag_raster_out = 6'd50;
        6'd38: dezigzag_raster_out = 6'd43;
        6'd39: dezigzag_raster_out = 6'd36;
        6'd40: dezigzag_raster_out = 6'd29;
        6'd41: dezigzag_raster_out = 6'd22;
        6'd42: dezigzag_raster_out = 6'd15;
        6'd43: dezigzag_raster_out = 6'd23;
        6'd44: dezigzag_raster_out = 6'd30;
        6'd45: dezigzag_raster_out = 6'd37;
        6'd46: dezigzag_raster_out = 6'd44;
        6'd47: dezigzag_raster_out = 6'd51;
        6'd48: dezigzag_raster_out = 6'd58;
        6'd49: dezigzag_raster_out = 6'd59;
        6'd50: dezigzag_raster_out = 6'd52;
        6'd51: dezigzag_raster_out = 6'd45;
        6'd52: dezigzag_raster_out = 6'd38;
        6'd53: dezigzag_raster_out = 6'd31;
        6'd54: dezigzag_raster_out = 6'd39;
        6'd55: dezigzag_raster_out = 6'd46;
        6'd56: dezigzag_raster_out = 6'd53;
        6'd57: dezigzag_raster_out = 6'd60;
        6'd58: dezigzag_raster_out = 6'd61;
        6'd59: dezigzag_raster_out = 6'd54;
        6'd60: dezigzag_raster_out = 6'd47;
        6'd61: dezigzag_raster_out = 6'd55;
        6'd62: dezigzag_raster_out = 6'd62;
        default: dezigzag_raster_out = 6'd63; 
    endcase
end


// Since targeting I-frames only - that is, intra-frames so far as I understand -
// should be safe to skip inter-frame handling. I will find out soon, i suppose, lol. 
    


    logic vga_clk, vga_blank, vga_sync;
    logic [9:0] vga_x, vga_y;

    vga_controller vgac(.Clk(clk50),
                        .Reset(reset),
                        .hs(hsync),
                        .vs(vsync),
                        .pixel_clk(vga_clk),
                        .blank(vga_blank),
                        .sync(vga_sync),
                        .DrawX(vga_x),
                        .DrawY(vga_y)
    );

    logic [7:0] calc_red, calc_green, calc_blue;

    always_ff @( posedge vga_clk or posedge reset ) begin 
        if(reset) begin
            red <= 4'h0;
            green <= 4'h0;
            blue <= 4'h0;
        end
        else if (vga_blank) begin
            red <= calc_red[7:4];
            green <= calc_green[7:4];
            blue <= calc_blue[7:4];
        end
        else begin
            red <= 4'h0;
            green <= 4'h0;
            blue <= 4'h0;
        end
    end

    logic [14:0] calc_Y_MB_offset;
    // logic [7:0] calc_Y_sub;
    logic [8:0] Yscale_x, Yscale_y;
    logic [4:0] calc_Y_MB_col, calc_Y_MB_row;
    logic [3:0] calc_Y_MB_internal_col, calc_Y_MB_internal_row;

    assign Yscale_x = vga_x / 3; // scale-x should be 0-175, plus some
    assign Yscale_y = vga_y / 3; // scale-y should be 0-143, plus some

    always_comb begin    // scale down by 3x;
        // Macroblocks are in raster-order, with the pixels within each macroblock in raster-order.
        calc_Y_MB_col = Yscale_x >> 4;   // divide by 16;
        calc_Y_MB_row = Yscale_y >> 4;   
        calc_Y_MB_offset = ((calc_Y_MB_row* 11) << 8) + (calc_Y_MB_col << 8);
        calc_Y_MB_internal_col = Yscale_x[3:0];
        calc_Y_MB_internal_row = Yscale_y[3:0];
        VGA_Y_ADDR = calc_Y_MB_offset + (calc_Y_MB_internal_row << 4) + calc_Y_MB_internal_col;
    end

    logic [12:0] calc_C_MB_offset;
    // logic [7:0]  calc_Cb_sub, calc_Cr_sub;
    logic [7:0] Cscale_x, Cscale_y;
    logic [4:0] calc_C_MB_col, calc_C_MB_row;
    logic [2:0] calc_C_MB_internal_col, calc_C_MB_internal_row;

    assign Cscale_x = Yscale_x >> 1; // scale-x should be 0-87, plus some
    assign Cscale_y = Yscale_y >> 1; // scale-y should be 0-71, plus some

    always_comb begin
        calc_C_MB_col = Cscale_x >> 3;   // divide by 8
        calc_C_MB_row = Cscale_y >> 3;
        calc_C_MB_offset = ((calc_C_MB_row* 11) << 6) + (calc_C_MB_col << 6);
        calc_C_MB_internal_col = Cscale_x[2:0];
        calc_C_MB_internal_row = Cscale_y[2:0];
        VGA_C_ADDR = calc_C_MB_offset + (calc_C_MB_internal_row << 3) + calc_C_MB_internal_col;
    end



    always_comb begin
        if ((vga_x >= 527)|(vga_y >= 431)) begin // 527 = 176 * 3 -1, 431 = 144*3 - 1.
            calc_red = 8'h0;    // Basically zero it out if we're beyond the video box. 
            calc_green = 8'h0;
            calc_blue = 8'h0;
        end
        else begin  // rounding a lot here... rec.601 to RGB conversion, stolen from wikipedia wiki/YCbCr
            calc_red = ((298 * VGA_Y_RDDATA)>>8) + ((408*VGA_Cr_RDDATA)>>8) + 223;
            calc_green = ((298 * VGA_Y_RDDATA)>>8) - ((100*VGA_Cb_RDDATA)>>8) - ((208*VGA_Cr_RDDATA)>>8)+136;
            calc_blue = ((298 * VGA_Y_RDDATA)>>8) + ((516*VGA_Cb_RDDATA)>>8) - 277;
        end
    end

    logic [14:0] ASIC_Y_ADDR, ASIC_Y_OFFSET;    // offset is value to add to raster-order to get which one. 
    logic [7:0] ASIC_Y_WRDATA, ASIC_Y_RDDATA;
    logic ASIC_Y_RDEN, ASIC_Y_WREN;
    logic [14:0] VGA_Y_ADDR;
    logic [7:0] VGA_Y_RDDATA;

    // Assign the offset, that gets us to the current macroblock
    // such that raster-order within the macroblock should be sufficient from here. 
    // ((saved_gn - 1) * 16 + (saved_MBA -1))*256
    // assign ASIC_Y_OFFSET = ((saved_GN - 1) << 4)

    sram_15bit Y_sram(.address_a(ASIC_Y_ADDR),
                    .address_b(VGA_Y_ADDR),
                    .clock(clk50),
                    .data_a(ASIC_Y_WRDATA),
                    .data_b(8'b0),
                    .rden_a(ASIC_Y_RDEN),
                    .rden_b(1'b1),
                    .wren_a(ASIC_Y_WREN),
                    .wren_b(1'b0),
                    .q_a(ASIC_Y_RDDATA),
                    .q_b(VGA_Y_RDDATA)
                    );

    logic [12:0] ASIC_Cb_ADDR, ASIC_Cb_OFFSET;
    logic [7:0] ASIC_Cb_WRDATA, ASIC_Cb_RDDATA;
    logic ASIC_Cb_RDEN, ASIC_Cb_WREN;
    logic [12:0] VGA_C_ADDR;    // Unified VGA address for Cb/Cr
    logic [7:0] VGA_Cb_RDDATA;
    sram_13bit Cb_sram(.address_a(ASIC_Cb_ADDR),
                    .address_b(VGA_C_ADDR),
                    .clock(clk50),
                    .data_a(ASIC_Cb_WRDATA),
                    .data_b(8'b0),
                    .rden_a(ASIC_Cb_RDEN),
                    .rden_b(1'b1),
                    .wren_a(ASIC_Cb_WREN),
                    .wren_b(1'b0),
                    .q_a(ASIC_Cb_RDDATA),
                    .q_b(VGA_Cb_RDDATA)
                    );

    logic [12:0] ASIC_Cr_ADDR, ASIC_Cr_OFFSET;
    logic [7:0] ASIC_Cr_WRDATA, ASIC_Cr_RDDATA;
    logic ASIC_Cr_RDEN, ASIC_Cr_WREN;
    // logic [12:0] VGA_Cr_ADDR;
    logic [7:0] VGA_Cr_RDDATA;
    sram_13bit Cr_sram(.address_a(ASIC_Cr_ADDR),
                    .address_b(VGA_C_ADDR),
                    .clock(clk50),
                    .data_a(ASIC_Cr_WRDATA),
                    .data_b(8'b0),
                    .rden_a(ASIC_Cr_RDEN),
                    .rden_b(1'b1),
                    .wren_a(ASIC_Cr_WREN),
                    .wren_b(1'b0),
                    .q_a(ASIC_Cr_RDDATA),
                    .q_b(VGA_Cr_RDDATA)
                    );
    
endmodule