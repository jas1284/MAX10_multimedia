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
parameter YUV_STALLCYCLES = 6'h18;
// NOTE: WHEN PLAYING Y4M FILES, MAKE SURE "F" OF FIRST "FRAME" IS AT 0x59. 
// FOR SOME BLOODY REASON, IF THIS CONDITION ISN'T MET, THE PING-PONG BUFFER
// WILL BE TOO SLOW TO REPLENISH.

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

always_ff @ (posedge clk50 or posedge reset) begin : bitqueue_ff;
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
always_ff @ (posedge clk50 or posedge reset) begin : rambuffer_ff;

    if(reset)
    begin
        // RAM_DATA_RDEN <= 1'b0;
        RAM_BUFFERED_READBACK <= 16'h0;
        RAM_DATA_BUFFER_STATE <= 1'b0;  // state: inactive
    end
    else if(RAM_DATA_BUFFER_STATE)  // If active state...
    begin
        // RAM_DATA_RDEN <= 1'b1;
        if(ram_ack) begin
            RAM_BUFFERED_READBACK <= ram_data;
            RAM_DATA_BUFFER_STATE <= 1'b0; // go back to inactive/unarmed state.
        end
    end
    else	// Inactive state
        // RAM_DATA_RDEN <= 1'b0;
        RAM_DATA_BUFFER_STATE <= RAM_DATA_BUFFER_EN;    // Wait to be activated.
end

logic RDEN_override;
// assign RAM_DATA_RDEN = RAM_DATA_BUFFER_STATE;
assign ram_rden = (RAM_DATA_BUFFER_STATE |RDEN_override);

always_comb begin : bitqueue_comb;
    // default values: 
    BITQ_NEXT = BITQUEUE;       // queue doesnt move
    READ_ADDR_NEXT = READ_ADDR; // addr doesnt change
    SHIFTCOUNT_NEXT = SHIFTCOUNT;   // shift-counter stays
    ram_addr = READ_ADDR;       // Pre-set the ram address
    RDEN_override = 1'b0; 
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
                SHIFTCOUNT_NEXT = SHIFTCOUNT + 6'h1;   // shift count increments, should be 1 (4 to test)
                if(SHIFTCOUNT_NEXT >= 1) begin     // Note that since we're in a COMB thus must use shiftcount_next!
                    q_nextstate = q_prefetch;  // we need to top up the queue. 
                    // ram_rden = 1'b1;        // Call upon RAM to send data.
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
            // ram_rden = 1'b1;
            status_1 = 1'b1;
            if(shiftsig)
                q_nextstate = q_prefetch_release;
        end
        q_prefetch_release: begin
            Q_RDY = 1'b1;
            // ram_rden = 1'b1;
            status_1 = 1'b1;
            if(~shiftsig)
            begin
                q_nextstate = q_prefetch;              // TESTING PURPOSE!
                BITQ_NEXT = BITQUEUE << 1;          // shift the bitqueue, should be 1, 4 to test
                SHIFTCOUNT_NEXT = SHIFTCOUNT + 6'h1;   // shift count increments, should be 1 (4 to test)
                if(SHIFTCOUNT_NEXT >= 16) begin // If the buffer has disarmed, it must have caught data
                    q_nextstate = q_shift;  // we should be clear to return to normal operation.
                    // ram_rden = 1'b0;    // let the RAM rest
                    BITQ_NEXT[15:8] = RAM_BUFFERED_READBACK[7:0];    // little-vs-big-endian tomfoolery
                    BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
                    READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
                    SHIFTCOUNT_NEXT = 6'h0;    // reset the shift-count
                end
            end

        end
        q_load1 : begin // load 1st word - most common
            // ram_rden = 1'b1;        // Call upon RAM to send data.
            // ram_addr = READ_ADDR;
            RAM_DATA_BUFFER_EN = 1'b1;  // Arm the RAM readback data buffer
            status_1 = 1'b1;
            q_nextstate = q_load1_wait;
        end
        q_load1_wait : begin
            // ram_rden = 1'b1;        // Call upon RAM to send data.
            // ram_addr = READ_ADDR;
            if(RAM_DATA_BUFFER_STATE == 1'b0) begin // If the buffer has disarmed, it must have caught data
                q_nextstate = q_shift;  // we should be clear to return to normal operation.
                // ram_rden = 1'b0;    // let the RAM rest
                BITQ_NEXT[15:8] = RAM_BUFFERED_READBACK[7:0];    // little-vs-big-endian tomfoolery
                BITQ_NEXT[7:0] = RAM_BUFFERED_READBACK[15:8];
                READ_ADDR_NEXT = READ_ADDR + 1;     // increment to next ram addr for next time.
            end
            // otherwise, we keep waiting, lol.
        end
        q_load3 : begin // load 3rd word
            RDEN_override = 1'b1;
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
            RDEN_override = 1'b1;
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
    mblayer,
    // YUV playback states... one giant bastard state machine
    YUV4START,
    YUV4FRAME, 
    YUV4FRAME_skip,
    YUV4FRAME_search_skip,
    YUV4FRAME_U,
    YUV4FRAME_U_skip,
    YUV4FRAME_V,
    YUV4FRAME_V_skip,
    YUV4FRAME_Y,
    YUV4FRAME_Y_skip
}   cur_layer, next_layer;
logic unsigned [6:0] countdown, countdown_next;
logic shiftsig, shiftsig_next;
logic [4:0] saved_TR, next_TR;
logic [3:0] saved_GN, next_GN;
logic [4:0] saved_QUANT, next_QUANT;
logic [5:0] saved_MBA, next_MBA;
logic [3:0] saved_MTYPE_vec, next_MTYPE_vec;
// logic [5:0] saved_TCOEFF_count, next_TCOEFF_count;
logic [2:0] saved_block_layer, next_block_layer;
logic [5:0] saved_TCOEFF_zigzag, next_TCOEFF_zigzag;
logic signed [7:0] FLC_level;
assign FLC_level = BITQUEUE[35:28];

logic [3:0] idct_cur_block_layer, idct_cur_block_layer_next;    // Which block layer is the IDCT currently working on?
logic WAIT_IDCT, WAIT_IDCT_next, WAIT_IDCT_set, WAIT_IDCT_clear;    // Flag determining if waiting for IDCT. Set by decode FSM, cleared by IDCT output.
always_comb begin : WAIT_IDCT_logic
    if(WAIT_IDCT_set)
        WAIT_IDCT_next = 1'b1;
    else if (WAIT_IDCT_clear)
        WAIT_IDCT_next = 1'b0;
    else
        WAIT_IDCT_next = WAIT_IDCT;
end

logic [3:0] playback_type_next, playback_type; // Keep track of the type of playback
// logic [7:0] SRAM_WRDATA, SRAM_WRDATA_next;   // the input should already be buffered... sus.
logic [5:0] stalltime, stalltime_next;  // Stall some time - we're playing too fast and not letting writes interleave.

assign hex_out_0 = playback_type;

// FF Logic for the big-bloody-state-machine!
always_ff @( posedge clk50 or posedge reset ) begin : decode_FSM_ff
    if(reset) begin
        saved_TCOEFF_zigzag <= 6'h0;
        saved_block_layer <= 3'h0;
        // saved_TCOEFF_count <= 0;
        saved_MTYPE_vec <= 4'h0;
        saved_MBA <= 6'h0;
        saved_QUANT <= 5'h0;
        saved_GN <= 4'h0;
        saved_TR <= 5'h0;
        cur_layer <= piclayer_readPSC;  // first thing is to always read PSC.
        countdown <= 6'h0;

        idct_cur_block_layer <= 3'h0;
        WAIT_IDCT <= 1'b0;

        playback_type <= 4'h0;
        Y_raster_order_counter <= 16'h0;
        YUVwrite_Y_x <= 8'h0;
        YUVwrite_Y_y <= 8'h0;
        U_raster_order_counter <= 16'h0;
        YUVwrite_U_x <= 8'h0;
        YUVwrite_U_y <= 8'h0;
        stalltime <= 5'h0;
    end
    else if (Q_RDY & run) begin   // Only run if the queue is ready-to-go!
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
        
        idct_cur_block_layer <= idct_cur_block_layer_next;
        WAIT_IDCT <= WAIT_IDCT_next;

        playback_type <= playback_type_next;
        Y_raster_order_counter <= Y_raster_order_counter_next;
        YUVwrite_Y_x <= YUVwrite_Y_x_next;
        YUVwrite_Y_y <= YUVwrite_Y_y_next;
        U_raster_order_counter <= U_raster_order_counter_next;
        YUVwrite_U_x <= YUVwrite_U_x_next;
        YUVwrite_U_y <= YUVwrite_U_y_next;
        stalltime <= stalltime_next;
    end
end

// Need to run the shift signal on a slower clock...? lol oops no we don't
always_ff @(posedge clk50 or posedge reset) begin
    if(reset)
        shiftsig <= 1'b0;
    else 
        shiftsig <= shiftsig_next;
end

always_comb begin : decode_FSM_comb;
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
    next_TCOEFF_table_WREN = 1'b0; // don't write to TCOEFF TABLE unless AUTHORIZED !
    next_TCOEFF_table_entry = 12'sh0;

    // iquant_eob = 1'b0;
    idct_cur_block_layer_next = idct_cur_block_layer;
    WAIT_IDCT_set = 1'b0;

    playback_type_next = playback_type;
    Y_raster_order_counter_next = Y_raster_order_counter;
    YUVwrite_Y_x_next = YUVwrite_Y_x;
    YUVwrite_Y_y_next = YUVwrite_Y_y;
    U_raster_order_counter_next = U_raster_order_counter;
    YUVwrite_U_x_next = YUVwrite_U_x;
    YUVwrite_U_y_next = YUVwrite_U_y;
    YUVwrite_Cb_ADDR = 13'h0;
    YUVwrite_Cr_ADDR = 13'h0;
    YUVwrite_Y_WREN = 1'b0;
    YUVwrite_Cb_WREN = 1'b0;
    YUVwrite_Cr_WREN = 1'b0;
    YUVwrite_Y_WRDATA = 16'h0;
    YUVwrite_Cb_WRDATA = 16'h0;
    YUVwrite_Cr_WRDATA = 16'h0;
    stalltime_next = stalltime;
    case (cur_layer)
        wait_for_it:    // Consider this an ERROR STATE!
            status_2 = 1'b1;
        piclayer_readPSC : begin
            if(PSC) begin
                playback_type_next = 4'h1;   // 1 for "h.261"
                countdown_next = 7'd20;
                next_layer = piclayer_skipPSC;
            end
            else // we SHOULD see a PSC, or something screwed up!
                next_layer = YUV4START;
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
            countdown_next = 7'd5;
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
                countdown_next = 7'd7;  // PTYPE is only 6, but we'll also skip PEI.
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
                countdown_next = 7'd16;
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
            countdown_next = 7'd4;
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
            countdown_next = 7'd6;  // Skip 5 + GEI.
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
            else begin  // done? ok, onwards to TR.
                if(saved_MTYPE_vec[3])  // if MQUANT present
                    next_layer = piclayer_readMQUANT;
                else if(saved_MTYPE_vec[2]) // if MVD present
                    next_layer = piclayer_readMVD;
                else if(saved_MTYPE_vec[1]) // if CBP present
                    next_layer = piclayer_readCBP;
                else begin  // if(saved_MTYPE_vec[0])  // finaly if somehow TCOEFF
                    next_layer = piclayer_readTCOEFF;
                    next_TCOEFF_zigzag = 6'h0; // Up to 64 TCOEFFS per block
                    // next_TCOEFF_count = 0; // up to 64 TCOEFFS per block
                    next_block_layer = 3'h0;  // up to 6 blocks per macroblock
                    idct_cur_block_layer_next = 3'h0;   // just clear this too just to be sure
                    // there is no MTYPE where NONE are present.
                end
            end    
        end
        piclayer_readTCOEFF : begin // We're in the block-layer now
            next_layer = piclayer_skipTCOEFF;
            if(TCOEFF_EOB) begin
                countdown_next = 2; // Skip EOB
                next_layer = piclayer_skipTCOEFF;
                // next_TCOEFF_count = 0;
                next_TCOEFF_zigzag = 6'h0;
                next_block_layer = saved_block_layer + 3'h1;
                idct_cur_block_layer_next = saved_block_layer;  // Keep it one behind for the block layers...?
                WAIT_IDCT_set = 1'b1;  // Set the wait flag, since the table is now full for this block.
            end
            else if(TCOEFF_ESC) begin   // We have a Fixed-Length code on our hands... special protocols!
                case (saved_QUANT[0])
                    1'b1 :  begin   // Quant ODD
                        case (BITQUEUE[35]) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * ((FLC_level << 1)+1); // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * ((FLC_level << 1)-1); // set CODE, signed
                            end
                        endcase
                    end
                    1'b0 :  begin   // QUANT EVEN
                        case (BITQUEUE[35]) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = (saved_QUANT * ((FLC_level << 1)+1)) - 1; // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = (saved_QUANT * ((FLC_level<< 1)-1)) + 1; // set CODE, signed
                            end
                        endcase
                    end
                endcase
                next_TCOEFF_zigzag = saved_TCOEFF_zigzag + BITQUEUE[41:36] + 6'h1; // RUN
                next_TCOEFF_table_WREN = 1'b1;
                countdown_next = 7'd20;    // Skip everything since we just did the whole ass FLC
            end 
            else begin  // Not end, nor FLC, so interpret using the VLC table
                case (saved_QUANT[0])
                    1'b1 :  begin   // Quant ODD
                        case (TCOEFF_SIGN) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * ((TCOEFF_LEVEL << 1)+1); // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((4'sh0 - TCOEFF_LEVEL)<< 1)-1); // set CODE, signed
                            end
                        endcase
                    end
                    1'b0 :  begin   // QUANT EVEN
                        case (TCOEFF_SIGN) // Check sign
                            1'b0    :   begin   // LEVEL POSITIV
                                next_TCOEFF_table_entry = saved_QUANT * ((TCOEFF_LEVEL << 1)+1) - 1; // set CODE, signed
                            end
                            1'b1    :   begin   // LEVEL NEGATIVE
                                next_TCOEFF_table_entry = saved_QUANT * (((4'sh0 - TCOEFF_LEVEL)<< 1)-1) + 1; // set CODE, signed
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
                if(!WAIT_IDCT) begin    // If waiting for IDCT, then we do nothing at all - need IDCT to finish first!
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
        end
        YUV4START : begin
            if(BITQUEUE[47:16] == 32'h59555634) begin   // = "YUV4"
                next_layer = YUV4FRAME;
                playback_type_next = 4'h4;   // 4 for "YUV4"
            end
            else
                next_layer = wait_for_it;   // error state
        end
        YUV4FRAME : begin
            if (BITQUEUE[47:16] == 32'h4652414D) begin  // = "FRAM"
                countdown_next = 7'd48; // skip to beginning of first frame (48 bits, 6 bytes)
                next_layer = YUV4FRAME_skip;
            end
            else begin
                countdown_next = 7'h8;  // skip 8 bits (1 char) and try again
                next_layer = YUV4FRAME_search_skip;
            end
        end
        YUV4FRAME_search_skip : begin
            if(countdown > 0) begin // make N shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else    // done? ok, search for "FRAM" again.
                next_layer = YUV4FRAME;
        end
        YUV4FRAME_skip : begin
            if(countdown > 0) begin // make N shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else begin  // done? ok, onwards to Y decode
                if (next_frame_24fps) // This holds us at 24fps. Should allow SDcard to load.
                    next_layer = YUV4FRAME_Y;
                Y_raster_order_counter_next = 16'h0;
            end
        end
        YUV4FRAME_Y : begin
            YUVwrite_Y_WRDATA = BITQUEUE[47:40];    // load the value to memory
            YUVwrite_Y_WREN = 1'b1; // ask for that write
            countdown_next = 7'h8;  // Skip the value once written.
            stalltime_next = YUV_STALLCYCLES;  // Stall
            next_layer = YUV4FRAME_Y_skip;
        end
        YUV4FRAME_Y_skip : begin
            if(countdown > 0) begin // make N shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else if (stalltime > 0) begin   // try to let the writes interleave a bit
                stalltime_next = (stalltime - 1);
            end
            else  begin
                YUVwrite_Y_x_next = YUVwrite_Y_x + 9'h1;
                if(YUVwrite_Y_x_next >= 176) begin
                    YUVwrite_Y_x_next = 8'h0;
                    YUVwrite_Y_y_next = YUVwrite_Y_y + 9'h1;
                end
                if(Y_raster_order_counter >= 16'h62FF) begin   // 176*144 - 1
                    Y_raster_order_counter_next = 16'h0;    // reset the counter
                    U_raster_order_counter_next = 16'h0;
                    YUVwrite_Y_x_next = 8'h0;
                    YUVwrite_Y_y_next = 8'h0;
                    next_layer = YUV4FRAME_U;   // we're done with Ys... 
                end
                else begin
                    Y_raster_order_counter_next = Y_raster_order_counter + 16'h1;
                    next_layer = YUV4FRAME_Y;   // next Y
                end
            end
        end
        YUV4FRAME_U : begin
            YUVwrite_Cb_WRDATA = BITQUEUE[47:40];    // load the value to memory
            YUVwrite_Cb_ADDR = YUVwrite_U_ADDR;
            YUVwrite_Cb_WREN = 1'b1;
            countdown_next = 7'h8;
            stalltime_next = YUV_STALLCYCLES;  // Stall 24 cycles..?
            next_layer = YUV4FRAME_U_skip;
        end
        YUV4FRAME_U_skip : begin
            if(countdown > 0) begin // make N shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else if (stalltime > 0) begin   // try to let the writes interleave a bit
                stalltime_next = (stalltime - 1);
            end
            else  begin
                YUVwrite_U_x_next = YUVwrite_U_x + 9'h1;
                if(YUVwrite_U_x_next >= 88) begin
                    YUVwrite_U_x_next = 8'h0;
                    YUVwrite_U_y_next = YUVwrite_U_y + 9'h1;
                end
                if(U_raster_order_counter >= 16'h18BF) begin   // 88*72 - 1
                    U_raster_order_counter_next = 16'h0;    // reset the counter
                    YUVwrite_U_x_next = 8'h0;
                    YUVwrite_U_y_next = 8'h0;
                    next_layer = YUV4FRAME_V;   // we're done with Us... 
                end
                else begin
                    U_raster_order_counter_next = U_raster_order_counter + 16'h1;
                    next_layer = YUV4FRAME_U;   // next U
                end
            end
        end
        YUV4FRAME_V : begin
            YUVwrite_Cr_WRDATA = BITQUEUE[47:40];    // load the value to memory
            YUVwrite_Cr_ADDR = YUVwrite_U_ADDR;
            YUVwrite_Cr_WREN = 1'b1;
            countdown_next = 7'h8;
            stalltime_next = YUV_STALLCYCLES;  // Stall
            next_layer = YUV4FRAME_V_skip;
        end
        YUV4FRAME_V_skip : begin
            if(countdown > 0) begin // make N shifts
                if(shiftsig) begin
                    shiftsig_next = 1'b0;
                    countdown_next = (countdown - 1);
                end
                else begin
                    shiftsig_next = 1'b1;
                end
            end
            else if (stalltime > 0) begin   // try to let the writes interleave a bit
                stalltime_next = (stalltime - 1);
            end
            else  begin
                YUVwrite_U_x_next = YUVwrite_U_x + 9'h1;
                if(YUVwrite_U_x_next >= 88) begin
                    YUVwrite_U_x_next = 8'h0;
                    YUVwrite_U_y_next = YUVwrite_U_y + 9'h1;
                end
                if(U_raster_order_counter >= 16'h18BF) begin   // 88*72 - 1
                    U_raster_order_counter_next = 16'h0;    // reset the counter
                    YUVwrite_U_x_next = 8'h0;
                    YUVwrite_U_y_next = 8'h0;
                    next_layer = YUV4FRAME;   // we're done with Vs... 
                end
                else begin
                    U_raster_order_counter_next = U_raster_order_counter + 16'h1;   // reusing U counter for V..
                    next_layer = YUV4FRAME_V;   // next U
                end
            end
        end
        default: ;
    endcase
end
    logic signed [11:0] saved_TCOEFF_table [64];
    logic signed [11:0] next_TCOEFF_table_entry;
    logic next_TCOEFF_table_WREN; // write-enable to this crazy regfile
    logic [5:0] IDCT_load_index, IDCT_load_index_next;

    logic signed [11:0] iquant_level;   // Level to send into the IDCT, read out of the saved_TCOEFF_table.
    logic iquant_eob;   // Send this when we're done sending all the coeffs?
        // Assuming we send in raster-order?
    logic iquant_valid; // treat this as a wren?

    logic signed [8:0] idct_data;   // Output, 9bits (8 + 2scomplement) that should go straight to framebuffers?
    logic idct_eob;     // Output - a signal that we're now at the end of the block on the output too..?
    logic idct_valid;   // Output - a warning that data's coming! (RDEN for the receiving end, I suppose.)

    // 8x8 Sram to IDCT
    enum logic [5:0] {wait_VLC,
                    load_to_IDCT,
                    load_deassert,
                    clear_table} IDCT_load_state, IDCT_load_state_next;


    always_ff @( posedge clk50  or posedge reset ) begin : IDCT_Loader_FSM_ff;
        if(reset) begin
            for(int i = 0; i < 64; i++)
                saved_TCOEFF_table[i] <= 12'sh0;
            IDCT_load_state <= wait_VLC;
            IDCT_load_index <= 6'h0;
        end
        else if(Q_RDY & run) begin
            if(next_TCOEFF_table_WREN & (WAIT_IDCT == 1'b0))   // If we're not waiting to IDCT, then we're still writing.
                saved_TCOEFF_table[dezigzag_raster_out] <= next_TCOEFF_table_entry;
            else if(IDCT_load_state == clear_table) begin   // clear the whole 8x8 table
                for(int i = 0; i < 64; i++)
                    saved_TCOEFF_table[i] <= 12'sh0;
            end
            IDCT_load_state <= IDCT_load_state_next;
            IDCT_load_index <= IDCT_load_index_next;
        end
    end

    always_comb begin : IDCT_Loader_FSM_comb;
        IDCT_load_index_next = IDCT_load_index;
        IDCT_load_state_next = IDCT_load_state;
        iquant_level = 12'sh0;
        iquant_valid = 1'b0;    // effectively WREN - set as 0
        iquant_eob = 1'b0;  // Tells the IDCT if we sent the last in block or not. 
        case (IDCT_load_state)
            wait_VLC :  begin
                IDCT_load_index_next = 6'h0;
                if(WAIT_IDCT) begin     // Now waiting for US to run!
                    IDCT_load_state_next = load_to_IDCT;
                end
            end
            load_to_IDCT : begin
                IDCT_load_state_next = load_deassert;
                iquant_level = saved_TCOEFF_table[IDCT_load_index]; // send that one over
                iquant_valid = 1'b0;    // Set invalid, to hit set-up time requirement?
                if(IDCT_load_index == 6'd63)    // If we're loading the last one
                    iquant_eob = 1'b1;
            end
            load_deassert : begin
                iquant_level = saved_TCOEFF_table[IDCT_load_index]; // send that one over
                iquant_valid = 1'b1;    // Set valid after holding everything for 1 cycle, just to be sure?
                if(IDCT_load_index == 6'd63) begin    // If we're loading the last one
                    iquant_eob = 1'b1;
                    IDCT_load_index_next = 6'h0;    // clear that out
                    IDCT_load_state_next = clear_table;
                end
                else begin
                    IDCT_load_index_next = IDCT_load_index + 6'h1;  // Increment the load index
                    IDCT_load_state_next = load_to_IDCT;
                end
            end
            clear_table : begin
                IDCT_load_state_next = wait_VLC;
                IDCT_load_index_next = 6'h0;    // clear out the index, redundant but safe
            end
            default: ;
        endcase
    end

    idct idct(
    .clk(clk50), 
    .clk_en(1'b1),
    .rst(~reset), 
    .iquant_level(iquant_level),                             // from rld
    .iquant_eob(iquant_eob),                                 // from rld
    .iquant_valid(iquant_valid),                             // from rld
    .idct_data(idct_data),                                   // to idct_fifo
    .idct_eob(idct_eob),                                     // to idct_fifo
    .idct_valid(idct_valid)                                  // to idct_fifo
    );

    // 8x8 IDCT to FRAMEBUFFER
    enum logic [5:0] {wait_IDCT,
                    unload_to_buffer,
                    unload_deassert} IDCT_unload_state, IDCT_unload_state_next;
    logic [5:0] IDCT_unload_index, IDCT_unload_index_next;

    always_ff @( posedge clk50  or posedge reset ) begin : IDCT_UNLoader_FSM_ff;
        if(reset) begin
            IDCT_unload_state <= wait_IDCT;
            IDCT_unload_index <= 6'h0;
        end
        else if(Q_RDY & run) begin
            IDCT_unload_state <= IDCT_unload_state_next;
            IDCT_unload_index <= IDCT_unload_index_next;
        end
    end

    always_comb begin : IDCT_UNLoader_FSM_comb;
        IDCT_unload_index_next = IDCT_unload_index;
        IDCT_unload_state_next = IDCT_unload_state;
        // Idct_data, idct_eob, idct_valid
        H261_Y_WRDATA = 8'h0;
        H261_Cb_WRDATA = 8'h0;
        H261_Cr_WRDATA = 8'h0;
        H261_Y_WREN = 1'b0;
        H261_Cb_WREN = 1'b0;
        H261_Cr_WREN = 1'b0;
        case (IDCT_unload_state)
            wait_IDCT :  begin
                IDCT_unload_state_next = unload_to_buffer;  // not sure if this state even needs to exist
                if(idct_valid) begin     // Now waiting for US to run!
                    IDCT_unload_state_next = unload_to_buffer;
                end
            end
            unload_to_buffer : begin
                if(idct_valid) begin
                    IDCT_unload_index_next = IDCT_unload_index + 6'h1;  // increment the address
                    case(idct_cur_block_layer)
                        3'h0 : begin    // block #0 in the macroblock
                            H261_Y_WRDATA = idct_data[7:0];
                            H261_Y_WREN = 1'b1;
                        end
                        3'h1 : begin
                            H261_Y_WRDATA = idct_data[7:0];
                            H261_Y_WREN = 1'b1;
                        end
                        3'h2 : begin
                            H261_Y_WRDATA = idct_data[7:0];
                            H261_Y_WREN = 1'b1;
                        end
                        3'h3 : begin
                            H261_Y_WRDATA = idct_data[7:0];
                            H261_Y_WREN = 1'b1;
                        end
                        3'h4 : begin
                            H261_Cb_WRDATA = idct_data[7:0];
                            H261_Cb_WREN = 1'b1;
                        end
                        3'h5 : begin
                            H261_Cr_WRDATA = idct_data[7:0];
                            H261_Cr_WREN = 1'b1;
                        end
                        default : ;     // Should never be a default value...?
                    endcase
                end
                if(idct_eob) begin      // If we're un-loading the last one
                    IDCT_unload_state_next = unload_deassert;
                    IDCT_unload_index_next = 6'h0;
                end
            end
            unload_deassert : begin
                if(~idct_eob)
                    IDCT_unload_state_next = unload_to_buffer;
            end
            default: ;
        endcase
    end

    logic [6:0] H261_MBOFFSET;
    logic [2:0] bl_x, bl_y; // Within-8x8 blocklayer coords
    logic [3:0] Y_mb_x, Y_mb_y; // Y coords, within 16x16 Macroblock
    logic [14:0] H261_Y_ADDR_MBOFFSET;
    logic [11:0] H261_Cb_ADDR_MBOFFSET;
    logic [11:0] H261_Cr_ADDR_MBOFFSET;
    always_comb begin : write_MB_calculation;
        H261_MBOFFSET = (saved_MBA + (((saved_GN - 3'h1) >> 1) * 33));
        H261_Y_ADDR_MBOFFSET = H261_MBOFFSET << 8;
        H261_Cb_ADDR_MBOFFSET = H261_MBOFFSET << 6;
        H261_Cr_ADDR_MBOFFSET = H261_MBOFFSET << 6;
        bl_x = IDCT_unload_index[2:0];  // X within the 8x8 block
        bl_y = IDCT_unload_index >> 3;  // Y within the 8x8 block
        case(idct_cur_block_layer[1:0])
            2'h0 : begin
                Y_mb_x = bl_x;
                Y_mb_y = bl_y;
            end
            2'h1 : begin
                Y_mb_x = bl_x + 8;
                Y_mb_y = bl_y;
            end
            2'h2 : begin
                Y_mb_x = bl_x;
                Y_mb_y = bl_y + 8;
            end
            2'h3 : begin
                Y_mb_x = bl_x + 8;
                Y_mb_y = bl_y + 8;
            end
        endcase
        H261_Y_ADDR = H261_Y_ADDR_MBOFFSET + (Y_mb_y << 4) + Y_mb_x;
        H261_Cb_ADDR = H261_Cb_ADDR_MBOFFSET + (bl_y << 3) + bl_x;
        H261_Cr_ADDR = H261_Cr_ADDR_MBOFFSET + (bl_y << 3) + bl_x;
    end

    // YUV output calculation for this crap
    logic [15:0] Y_raster_order_counter, Y_raster_order_counter_next;   // which pixel, in raster-order.
    logic [8:0] YUVwrite_Y_x, YUVwrite_Y_y; // x and y values, scaled to be 176x144. 
    logic [8:0] YUVwrite_Y_x_next, YUVwrite_Y_y_next; // x and y values, scaled to be 176x144. 
    logic [4:0]  YUVwrite_Y_MB_row,  YUVwrite_Y_MB_col; // x and y values of the macroblock... necessary for computing block raster and index.
    logic [7:0]  Y_raster_order_MB; // which macroblock, in raster-order.
    logic [14:0] YUVwrite_Y_MB_offset;  // Offset in memory to get to the right Y macroblock (16x16)
    logic [14:0] YUVwrite_Y_ADDR;   // Address for YUV Y vals. selectable.
    // logic [7:0] YUVwrite_Y_sub;
    logic [3:0] YUVwrite_Y_MB_internal_col, YUVwrite_Y_MB_internal_row; // calculated rows and cols inside the macroblocks

    always_comb begin    // scale down by 3x;
        // Macroblocks are in raster-order, with the pixels within each macroblock in raster-order.
        // YUVwrite_Y_x = Y_raster_order_counter % 176;
        // YUVwrite_Y_y = Y_raster_order_counter / 176;
        YUVwrite_Y_MB_col = YUVwrite_Y_x >> 4;
        YUVwrite_Y_MB_row = YUVwrite_Y_y >> 4;
        YUVwrite_Y_MB_offset = ((YUVwrite_Y_MB_row* 11) << 8) + (YUVwrite_Y_MB_col << 8);
        YUVwrite_Y_MB_internal_col = YUVwrite_Y_x[3:0];
        YUVwrite_Y_MB_internal_row = YUVwrite_Y_y[3:0];
        YUVwrite_Y_ADDR = YUVwrite_Y_MB_offset + (YUVwrite_Y_MB_internal_row << 4) + YUVwrite_Y_MB_internal_col;
    end

    // YUV output calculation for this crap
    logic [15:0] U_raster_order_counter, U_raster_order_counter_next;   // which pixel, in raster-order.
    logic [8:0] YUVwrite_U_x, YUVwrite_U_y; // x and y values, scaled to be 176x144. 
    logic [8:0] YUVwrite_U_x_next, YUVwrite_U_y_next; // x and y values, scaled to be 88x72. 
    logic [4:0]  YUVwrite_U_MB_row,  YUVwrite_U_MB_col; // x and y values of the macroblock... necessary for computing block raster and index.
    logic [7:0]  U_raster_order_MB; // which macroblock, in raster-order.
    logic [12:0] YUVwrite_U_MB_offset;  // Offset in memory to get to the right U macroblock (8x8)
    logic [12:0] YUVwrite_U_ADDR;   // Address for YUV U vals. selectable.
    // logic [7:0] YUVwrite_U_sub;
    logic [2:0] YUVwrite_U_MB_internal_col, YUVwrite_U_MB_internal_row; // calculated rows and cols inside the macroblocks

    always_comb begin    // scale down by 3x;
        // Macroblocks are in raster-order, with the pixels within each macroblock in raster-order.
        // YUVwrite_U_x = U_raster_order_counter % 88;
        // YUVwrite_U_y = U_raster_order_counter / 88;  // These were too intensive to hit timing!
        YUVwrite_U_MB_col = YUVwrite_U_x >> 3;
        YUVwrite_U_MB_row = YUVwrite_U_y >> 3;
        YUVwrite_U_MB_offset = ((YUVwrite_U_MB_row* 11) << 6) + (YUVwrite_U_MB_col << 6);
        YUVwrite_U_MB_internal_col = YUVwrite_U_x[2:0];
        YUVwrite_U_MB_internal_row = YUVwrite_U_y[2:0];
        YUVwrite_U_ADDR = YUVwrite_U_MB_offset + (YUVwrite_U_MB_internal_row << 3) + YUVwrite_U_MB_internal_col;
    end

    logic [14:0] H261_Y_ADDR;
    logic [7:0] H261_Y_WRDATA, YUVwrite_Y_WRDATA;
    logic [7:0] H261_Y_RDDATA;   // as-of-yet-unused
    logic H261_Y_WREN, YUVwrite_Y_WREN;
    logic H261_Y_RDEN; // as-of-yet-unused

    logic [12:0] H261_Cb_ADDR, H261_Cr_ADDR, YUVwrite_Cb_ADDR, YUVwrite_Cr_ADDR;
    logic [7:0] H261_Cb_WRDATA, H261_Cr_WRDATA, YUVwrite_Cb_WRDATA, YUVwrite_Cr_WRDATA;
    logic [7:0] H261_Cb_RDDATA, H261_Cr_RDDATA;   // as-of-yet-unused
    logic H261_Cb_WREN, H261_Cr_WREN, YUVwrite_Cb_WREN, YUVwrite_Cr_WREN;
    logic H261_Cb_RDEN, H261_Cr_RDEN; // as-of-yet-unused
    always_comb begin : FrameBufferAccessSelector;
        ASIC_Y_ADDR = 15'h0;
        ASIC_Y_WRDATA = 8'h0;
        ASIC_Y_WREN = 1'b0;
        ASIC_Y_RDEN = 1'b0;
        ASIC_Cb_ADDR = 13'h0;
        ASIC_Cb_WRDATA = 8'h0;
        ASIC_Cb_WREN = 1'b0;
        ASIC_Cb_RDEN = 1'b0;
        ASIC_Cr_ADDR = 13'h0;
        ASIC_Cr_WRDATA = 8'h0;
        ASIC_Cr_WREN = 1'b0;
        ASIC_Cr_RDEN = 1'b0;
        
        H261_Y_RDDATA = 8'h0;
        H261_Cb_RDDATA = 8'h0;
        H261_Cr_RDDATA = 8'h0;
        case (playback_type)
            4'h1 : begin    // H261
                ASIC_Y_ADDR = H261_Y_ADDR;
                ASIC_Y_WRDATA = H261_Y_WRDATA;
                H261_Y_RDDATA = ASIC_Y_RDDATA;
                ASIC_Y_WREN = H261_Y_WREN;
                ASIC_Y_RDEN = H261_Y_RDEN;
                ASIC_Cb_ADDR = H261_Cb_ADDR;
                ASIC_Cb_WRDATA = H261_Cb_WRDATA;
                H261_Cb_RDDATA = ASIC_Cb_RDDATA;
                ASIC_Cb_WREN = H261_Cb_WREN;
                ASIC_Cb_RDEN = H261_Cb_RDEN;
                ASIC_Cr_ADDR = H261_Cr_ADDR;
                ASIC_Cr_WRDATA = H261_Cr_WRDATA;
                H261_Cr_RDDATA = ASIC_Cr_RDDATA;
                ASIC_Cr_WREN = H261_Cr_WREN;
                ASIC_Cr_RDEN = H261_Cr_RDEN;
            end
            4'h4 : begin    // YUV4
                ASIC_Y_ADDR = YUVwrite_Y_ADDR;
                ASIC_Y_WRDATA = YUVwrite_Y_WRDATA;
                ASIC_Y_WREN = YUVwrite_Y_WREN;
                ASIC_Cb_ADDR = YUVwrite_Cb_ADDR;
                ASIC_Cb_WRDATA = YUVwrite_Cb_WRDATA;
                ASIC_Cb_WREN = YUVwrite_Cb_WREN;
                ASIC_Cr_ADDR = YUVwrite_Cr_ADDR;
                ASIC_Cr_WRDATA = YUVwrite_Cr_WRDATA;
                ASIC_Cr_WREN = YUVwrite_Cr_WREN;
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
logic [3:0] GN;       // Group Number, read back from bitqueue
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

    // logic NTSC_clk, NTSC_prev;
    logic next_frame_24fps;
    // logic next_frame_NTSC;
    logic [20:0] counter_24fps, counter_24fps_next;
    // always_ff @ (negedge vsync or posedge reset) begin
    //     if (reset)
    //         NTSC_clk <= 1'b0;
	// 	else 
    //         NTSC_clk <= ~NTSC_clk;
    // end
    always_ff @ (posedge vga_clk or posedge reset) begin  // 25mhz clk
        if (reset) begin
            // NTSC_prev <= 1'b0;
            counter_24fps <= 21'h0;
        end
        else
            counter_24fps <= counter_24fps_next;
            // NTSC_prev <= NTSC_clk;
    end
    always_comb begin   // 2 cycles of assert just to be sure
        if (counter_24fps >= 21'd1041666) begin
            counter_24fps_next = 21'h0;
            next_frame_24fps = 1'b1;
        end
        // else if(counter_24fps >= 21'd1666665) begin
        //     counter_24fps_next = counter_24fps + 21'h1;
        //     next_frame_24fps = 1'b1;
        // end
        else begin
            counter_24fps_next = counter_24fps + 21'h1;
            next_frame_24fps = 1'b0;
        end
    end
    // assign next_frame_NTSC = ((~NTSC_clk) && (NTSC_prev));   // A quick pulse, every now and then.

    logic signed [9:0] calc_red, calc_green, calc_blue;
    logic [7:0] calc_red_clipped, calc_green_clipped, calc_blue_clipped;

    always_ff @( posedge vga_clk or posedge reset ) begin 
        if(reset) begin
            red <= 4'h0;
            green <= 4'h0;
            blue <= 4'h0;
        end
        else if (vga_blank) begin
            red <= calc_red_clipped[7:4];
            green <= calc_green_clipped[7:4];
            blue <= calc_blue_clipped[7:4];
        end
        else begin
            red <= 4'h0;
            green <= 4'h0;
            blue <= 4'h0;
        end
    end

    logic [14:0] calc_Y_MB_offset;  // Offset in memory to get to the right Y macroblock (16x16)
    // logic [7:0] calc_Y_sub;
    logic [8:0] Yscale_x, Yscale_y; // x and y values, scaled to be 176x144. 
    logic [4:0] calc_Y_MB_col, calc_Y_MB_row;   // calculated macroblock row and columns.
    logic [3:0] calc_Y_MB_internal_col, calc_Y_MB_internal_row; // calculated rows and cols inside the macroblocks

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



    always_comb begin : colorcalc;
        if ((vga_x >= 527)|(vga_y >= 431)) begin // 527 = 176 * 3 -1, 431 = 144*3 - 1.
            calc_red = 10'sh0;    // Basically zero it out if we're beyond the video box. 
            calc_green = 10'sh0;
            calc_blue = 10'sh0;
        end
        else begin  // rounding a lot here... rec.601 to RGB conversion, stolen from wikipedia wiki/YCbCr
            calc_red = ((149 * VGA_Y_RDDATA_minus16) >>> 7) + ((51*VGA_Cr_RDDATA_minus128) >>> 5);
            calc_green = ((149 * VGA_Y_RDDATA_minus16) >>> 7) - ((25 * VGA_Cb_RDDATA_minus128) >>> 6) - ((13*VGA_Cr_RDDATA_minus128) >>> 4);
            calc_blue = ((149 * VGA_Y_RDDATA_minus16) >>> 7) + ((129 * VGA_Cb_RDDATA_minus128) >>> 6);
        end
    end
    always_comb begin : colorclip;
        if(calc_red > 10'sd255)
            calc_red_clipped = 8'd255;
        else if (calc_red < 10'sd0) begin
            calc_red_clipped = 8'd0;
        end
        else begin
            calc_red_clipped = calc_red[7:0];
        end

        if(calc_green > 10'sd255)
            calc_green_clipped = 8'd255;
        else if (calc_green < 10'sd0) begin
            calc_green_clipped = 8'd0;
        end
        else begin
            calc_green_clipped = calc_green[7:0];
        end

        if(calc_blue > 10'sd255)
            calc_blue_clipped = 8'd255;
        else if (calc_blue < 10'sd0) begin
            calc_blue_clipped = 8'd0;
        end
        else begin
            calc_blue_clipped = calc_blue[7:0];
        end
    end

    logic [14:0] ASIC_Y_ADDR, ASIC_Y_OFFSET;    // offset is value to add to raster-order to get which one. 
    logic [7:0] ASIC_Y_WRDATA, ASIC_Y_RDDATA;
    logic ASIC_Y_RDEN, ASIC_Y_WREN;
    logic [14:0] VGA_Y_ADDR;
    logic [7:0] VGA_Y_RDDATA;
    logic signed [8:0] VGA_Y_RDDATA_minus16;
    assign VGA_Y_RDDATA_minus16 = VGA_Y_RDDATA - 9'sd16;

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
    logic signed [8:0] VGA_Cb_RDDATA_minus128;
    assign VGA_Cb_RDDATA_minus128 = VGA_Cb_RDDATA - 9'sd128;
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
    logic signed [8:0] VGA_Cr_RDDATA_minus128;
    assign VGA_Cr_RDDATA_minus128 = VGA_Cr_RDDATA - 9'sd128;
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