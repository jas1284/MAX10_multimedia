/************************************************************************
Avalon-MM Interface VGA SPECIAL display

Register Map:
0x000-0x0257 : VRAM, 80x30 (2400 byte, 600 word) raster order (first column then row)
0x258        : control register

VRAM Format:
X->
[ 31  30-24][ 23  22-16][ 15  14-8 ][ 7    6-0 ]
[IV3][CODE3][IV2][CODE2][IV1][CODE1][IV0][CODE0]

IVn = Draw inverse glyph
CODEn = Glyph code from IBM codepage 437

Control Register Format:
[[31-25][24-21][20-17][16-13][ 12-9][ 8-5 ][ 4-1 ][   0    ] 
[[RSVD ][FGD_R][FGD_G][FGD_B][BKG_R][BKG_G][BKG_B][RESERVED]

VSYNC signal = bit which flips on every Vsync (time for new frame), used to synchronize software
BKG_R/G/B = Background color, flipped with foreground when IVn bit is set
FGD_R/G/B = Foreground color, flipped with background when Inv bit is set

************************************************************************/
`define NUM_REGS 601 //80*30 characters / 4 characters per register
`define CTRL_REG 600 //index of control register

`define PALETTE_REGS 8	// 8 words of palette register

module vga_text_avl_interface (
	// Avalon Clock Input, note this clock is also used for VGA, so this must be 50Mhz
	// We can put a clock divider here in the future to make this IP more generalizable
	input logic CLK,
	
	// Avalon Reset Input
	input logic RESET,
	
	// Avalon-MM Slave Signals
	input  logic AVL_READ,					// Avalon-MM Read
	input  logic AVL_WRITE,					// Avalon-MM Write
	input  logic AVL_CS,					// Avalon-MM Chip Select
	input  logic [3:0] AVL_BYTE_EN,			// Avalon-MM Byte Enable
	input  logic [11:0] AVL_ADDR,			// Avalon-MM Address
	input  logic [31:0] AVL_WRITEDATA,		// Avalon-MM Write Data
	output logic [31:0] AVL_READDATA,		// Avalon-MM Read Data
	
	// Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
	output logic [3:0]  red, green, blue,	// VGA color channels (mapped to output pins in top-level)
	output logic hs, vs						// VGA HS/VS
);

// logic [31:0] LOCAL_REG       [`NUM_REGS]; // Registers
logic [31:0] PALETTE	[`PALETTE_REGS];
//put other local variables here
logic vga_clk;	// 25MHZ VGA boi
logic blank;	// blanking signal - set to black when this is active-low
logic [9:0] vga_x, vga_y, vgax_ahead;	// currently drawn coords
// logic [11:0]	vga_read_pos;	// 0-2399 of which character the VGA is trying to read from 
logic [11:0] vga_read_addr;	// address in LOCAL_REG that VGA needs to read from
// logic [1:0]	vga_read_bitmask;	// not quite a bitmask, but indicates which character at address
logic [10:0] f_rom_addr;	// address from the font_rom that we want to access
logic [7:0]	f_rom_row;		// values for the currently selected row
// logic [6:0] curr_char; 		// 7-bit representation of character to draw
logic [3:0] char_scanline;	// 0-15 of current character, indicates scanline
logic [2:0] char_col;		// 0-8 of current character, x
logic invert;	// font color - 1 for inverted black-on-white
logic [7:0] BYTE_0, BYTE_1, BYTE_2, BYTE_3, BYTE_X;	// logic for each of the 4 bytes in the word, X being one to show
logic [3:0] FGD_IDX, BKG_IDX;	// extracted values for fgd/bkg for 7.2
logic [3:0] FGD_R, FGD_G, FGD_B, BKG_R, BKG_G, BKG_B;	// color vals for fg/bg
logic [31:0] vga_ram_read;
// logic [31:0] local_ctrl_reg;

//Declare submodules..e.g. VGA controller, ROMS, etc

ram_12bit ram0(.address_a(AVL_ADDR), .address_b(vga_read_addr), .byteena_a(AVL_BYTE_EN), .clock(CLK),
	.data_a(AVL_WRITEDATA), .data_b(32'b0), .rden_a(AVL_READ), .rden_b(1'b1),.wren_a(AVL_WRITE),
	.wren_b(1'b0), .q_a(AVL_READDATA), .q_b(vga_ram_read));

vga_controller vgac(.Clk(CLK), .Reset(RESET), .hs(hs), .vs(vs),
	.pixel_clk(vga_clk), .blank(blank), .sync(), .DrawX(vga_x), .DrawY(vga_y));

font_rom f_rom(.addr(f_rom_addr), .data(f_rom_row));
   
// Read and write from AVL interface to register block, note that READ waitstate = 1, so this should be in always_ff
// always_ff @(posedge CLK or posedge RESET) begin
// 	if (RESET)
// 	begin
// 		for (int i = 0; i < `NUM_REGS; i++)
// 			LOCAL_REG[i] = 32'b0;
// 	end

// 	else if(AVL_CS)
// 	begin
// 		if(AVL_READ)
// 		begin
// 			AVL_READDATA <= LOCAL_REG[AVL_ADDR];
// 		end
// 		else if(AVL_WRITE)
// 		begin
// 			case (AVL_BYTE_EN)
// 				4'b1111 : 	begin
// 								LOCAL_REG[AVL_ADDR] <= AVL_WRITEDATA;
// 							end
// 				4'b1100 : 	begin
// 								LOCAL_REG[AVL_ADDR][31:16] <= AVL_WRITEDATA[31:16];
// 							end	
// 				4'b0011 : 	begin
// 								LOCAL_REG[AVL_ADDR][15:0] <= AVL_WRITEDATA[15:0];
// 							end	
// 				4'b1000 : 	begin
// 								LOCAL_REG[AVL_ADDR][31:24] <= AVL_WRITEDATA[31:24];
// 							end	
// 				4'b0100 : 	begin
// 								LOCAL_REG[AVL_ADDR][23:16] <= AVL_WRITEDATA[23:16];
// 							end	
// 				4'b0010 : 	begin
// 								LOCAL_REG[AVL_ADDR][15:8] <= AVL_WRITEDATA[15:8];
// 							end	
// 				4'b0001 : 	begin
// 								LOCAL_REG[AVL_ADDR][7:0] <= AVL_WRITEDATA[7:0];
// 							end	
// 				default : ;
// 			endcase
// 		end
// 	end
// end

always_ff @(posedge CLK or posedge RESET) begin
	if (RESET)
	begin
		for(int i =0; i < `PALETTE_REGS;i++)
			PALETTE[i] <= 32'b0;
	end
	else
	begin	// check if between 0x800 and 0x807(inclusive)
		if(AVL_WRITE & (AVL_ADDR[11]) & (AVL_ADDR[10:3] == 0))
		begin
			case (AVL_BYTE_EN)
				4'b1111 : 	begin
								PALETTE[AVL_ADDR[2:0]] <= AVL_WRITEDATA;
							end
				4'b1100 : 	begin
								PALETTE[AVL_ADDR[2:0]][31:16] <= AVL_WRITEDATA[31:16];
							end	
				4'b0011 : 	begin
								PALETTE[AVL_ADDR[2:0]][15:0] <= AVL_WRITEDATA[15:0];
							end	
				4'b1000 : 	begin
								PALETTE[AVL_ADDR[2:0]][31:24] <= AVL_WRITEDATA[31:24];
							end	
				4'b0100 : 	begin
								PALETTE[AVL_ADDR[2:0]][23:16] <= AVL_WRITEDATA[23:16];
							end	
				4'b0010 : 	begin
								PALETTE[AVL_ADDR[2:0]][15:8] <= AVL_WRITEDATA[15:8];
							end	
				4'b0001 : 	begin
								PALETTE[AVL_ADDR[2:0]][7:0] <= AVL_WRITEDATA[7:0];
							end	
				default : ;
			endcase
		end
	end
end


//handle drawing (may either be combinational or sequential - or both).
		
always_ff @ (posedge vga_clk)
begin
	if(blank)
	begin	// ~tilde remaps it from [7:0] to [0:7] - effecively 7-char_col
		case (f_rom_row[~char_col] ^ invert)	// current pixel ^ whether to invert
		1'b1	: 	begin 	// 1 indicates to use the fg color
						red <= FGD_R;
						green <= FGD_G;
						blue <= FGD_B;
					end
		1'b0	: 	begin 
						red <= BKG_R;
						green <= BKG_G;
						blue <= BKG_B;
					end
		endcase	
	end
	else	// blank is active-low - we blank it if its not-high
	begin
		red <= 4'b0;
		green <= 4'b0;
		blue <= 4'b0;
	end
end

always_comb
begin
	// (x>>3) mod 2: x>>3 tells us which (0-80) column, mod 2 tells us which pair of bytes in a 32-bit word
	// due to SRAM delay issues, may need to offset this later!
	case(vga_x[3])
		1'b1	: 	begin
						BYTE_X = BYTE_3;
						FGD_IDX = BYTE_2[7:4];
						BKG_IDX = BYTE_2[3:0];
						// curr_char = vga_ram_read[30:24]
						// invert = vga_ram_read[31];
						// curr_char = LOCAL_REG[vga_read_addr][30:24];
						// invert = LOCAL_REG[vga_read_addr][31];
					end
		1'b0 	: 	begin 
						BYTE_X = BYTE_1;
						FGD_IDX = BYTE_0[7:4];
						BKG_IDX = BYTE_0[3:0];
					end
	endcase	
end

// for 7.1:
// vga_read_addr = ((vga_y>> 2)*5) + (vgax_ahead >> 5);	// remap y 0-480 to 0-600, x 0-640 to 0-20
// assign vga_read_pos = (((vga_y>>4) * 80) + (vgax_ahead>>3))
// assign vga_read_addr = ((((vga_y>>4) * 80) + (vgax_ahead>>3))>>2);

// for 7.2:
// vga_read_addr = ((((vga_y>>4) * 80) + (vgax_ahead>>3))>>1);	// 2400 chars to 1200 locations
assign vga_read_addr = ((((vga_y>>4) * 80) + (vgax_ahead>>3))>>1);

assign char_scanline = vga_y[3:0];	// y mod 16 -> which scan-line of the character to display
assign char_col = vga_x[2:0];	// x mod 8 -> which col of character to display

// To work-around for the fact that SRAM is slow, and may occasionally lead to stale data:
// we "pre-fetch" the data by calculating the address that SRAM returns using vgax_head.
// (FIXES OCCASIONAL WRONG COLUMN - happens when, for example, x=31 is drawn with word 0 and fetches word 0
// but when word 0 data arrives, x=32 is being drawn, which is part of word 1 - so x=32 drawn with wrong word.
// pre-fetch fetches for word 1 at the very end of word 0, fixing this!
// how much prefetch is enough? trial and error says x=1, x=2 are both OK!)
// PREFETCH FOR X=0 DURING BLANKING INTERVAL! (FIXES x=0 being wrong)
// assign vgax_ahead = vga_x + 1;
always_comb
begin
	case(blank)	// blanking interval should encompass everything-not-on-screen! x=640 to x=799
		1'b0 	:	vgax_ahead = 0;	// blanking interval is active-low, prefetch for x=0
		1'b1 	: 	vgax_ahead = vga_x +1;	// prefetch normally (i.e. x+1)
	endcase
end

assign f_rom_addr = {BYTE_X[6:0],char_scanline};
assign invert = BYTE_X[7];

assign BYTE_0 = vga_ram_read[7:0];
assign BYTE_1 = vga_ram_read[15:8];
assign BYTE_2 = vga_ram_read[23:16];
assign BYTE_3 = vga_ram_read[31:24];

// calculate the FGD/BKG colors!
// 2 colors per location, so we need to modulo address and bit-bang
always_comb
begin
	case(FGD_IDX[0])
		1'b1	: 	begin	// odd multiple FGD_IDX is bits [23:13]
						FGD_R = PALETTE[FGD_IDX >> 1][24:21];
						FGD_G = PALETTE[FGD_IDX >> 1][20:17];
						FGD_B = PALETTE[FGD_IDX >> 1][16:13];
					end
		1'b0 	: 	begin 	// even multiples is bits[12:1]
						FGD_R = PALETTE[FGD_IDX >> 1][12:9];
						FGD_G = PALETTE[FGD_IDX >> 1][8:5];
						FGD_B = PALETTE[FGD_IDX >> 1][4:1];
					end
	endcase	
end

always_comb
begin
	case(BKG_IDX[0])
		1'b1	: 	begin	// odd multiple BKG_IDX is bits [23:13]
						BKG_R = PALETTE[BKG_IDX >> 1][24:21];
						BKG_G = PALETTE[BKG_IDX >> 1][20:17];
						BKG_B = PALETTE[BKG_IDX >> 1][16:13];
					end
		1'b0 	: 	begin 	// even multiples is bits[12:1]
						BKG_R = PALETTE[BKG_IDX >> 1][12:9];
						BKG_G = PALETTE[BKG_IDX >> 1][8:5];
						BKG_B = PALETTE[BKG_IDX >> 1][4:1];
					end
	endcase	
end
endmodule
