## Generated SDC file "FP-ZUOFU-BASIC.out.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Thu May 04 01:50:41 2023"

##
## DEVICE  "10M50DAF484C7G"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {MAX10_CLK1_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {MAX10_CLK1_50}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {u0|sdram_pll|sd1|pll7|clk[0]} -source [get_pins {u0|sdram_pll|sd1|pll7|inclk[0]}] -duty_cycle 50/1 -multiply_by 1 -master_clock {MAX10_CLK1_50} [get_pins {u0|sdram_pll|sd1|pll7|clk[0]}] 
create_generated_clock -name {u0|sdram_pll|sd1|pll7|clk[2]} -source [get_pins {u0|sdram_pll|sd1|pll7|inclk[0]}] -duty_cycle 50/1 -multiply_by 2 -phase -36/1 -master_clock {MAX10_CLK1_50} [get_pins {u0|sdram_pll|sd1|pll7|clk[2]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {MAX10_CLK1_50}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {MAX10_CLK1_50}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {MAX10_CLK1_50}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {MAX10_CLK1_50}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {MAX10_CLK1_50}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {MAX10_CLK1_50}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {MAX10_CLK1_50}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {MAX10_CLK1_50}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

