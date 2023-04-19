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

## DATE    "Wed Apr 19 03:11:21 2023"

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

create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {MAX10_CLK1_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {MAX10_CLK1_50}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {u0|sdram_pll|sd1|pll7|clk[2]} -source [get_pins {u0|sdram_pll|sd1|pll7|inclk[0]}] -duty_cycle 50/1 -multiply_by 2 -phase 324 -master_clock {MAX10_CLK1_50} [get_pins {u0|sdram_pll|sd1|pll7|clk[2]}] 
create_generated_clock -name {u0|sdram_pll|sd1|pll7|clk[0]} -source [get_pins {u0|sdram_pll|sd1|pll7|inclk[0]}] -duty_cycle 50/1 -multiply_by 1 -master_clock {MAX10_CLK1_50} [get_pins {u0|sdram_pll|sd1|pll7|clk[0]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {MAX10_CLK1_50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {altera_reserved_tck}] -rise_to [get_clocks {altera_reserved_tck}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {altera_reserved_tck}] -fall_to [get_clocks {altera_reserved_tck}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {altera_reserved_tck}] -rise_to [get_clocks {altera_reserved_tck}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {altera_reserved_tck}] -fall_to [get_clocks {altera_reserved_tck}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -rise_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {MAX10_CLK1_50}] -fall_to [get_clocks {u0|sdram_pll|sd1|pll7|clk[0]}] -hold 0.100  
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
# suppose +- 100 ps skew
# Board Delay (Data) + Propagation Delay - Board Delay (Clock)
# max 5.4(max) +0.4(trace delay) +0.1 = 5.9
# min 2.7(min) +0.4(trace delay) -0.1 = 3.0
set_input_delay -max -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] 5.9 [get_ports DRAM_DQ*]
set_input_delay -min -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] 3.0 [get_ports DRAM_DQ*]

set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {KEY[0]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {KEY[1]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[0]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[1]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[2]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[3]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[4]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[5]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[6]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[7]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[8]}]
set_input_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  1.000 [get_ports {SW[9]}]


#**************************************************************
# Set Output Delay
#**************************************************************
# suppose +- 100 ps skew
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)
# max 1.5+0.1 =1.6
# min -0.8-0.1 = 0.9
set_output_delay -max -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] 1.6  [get_ports {DRAM_DQ* DRAM_*DQM}]
set_output_delay -min -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] -0.9 [get_ports {DRAM_DQ* DRAM_*DQM}]
set_output_delay -max -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] 1.6  [get_ports {DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_CKE DRAM_CS_N}]
set_output_delay -min -clock [get_clocks {u0|sdram_pll|sd1|pll7|clk[2]}] -0.9 [get_ports {DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_CKE DRAM_CS_N}]

set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX0[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX1[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX2[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX3[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX4[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {HEX5[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[0]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[1]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[2]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[3]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[4]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[5]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[6]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[7]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[8]}]
set_output_delay -add_delay  -clock [get_clocks {MAX10_CLK1_50}]  0.000 [get_ports {LEDR[9]}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
set_false_path -to [get_ports {LED*}]
set_false_path -from [get_ports {KEY*}] 
set_false_path -from [get_ports {DRAM_DQ*}] 
set_false_path -from [get_ports {SW*}] 
set_false_path -from [get_ports {altera_reserved*}] 
set_false_path -to [get_ports {DRAM_ADDR*}]
set_false_path -to [get_ports {DRAM_BA*}]
set_false_path -to [get_ports {DRAM_CAS_N}]
set_false_path -to [get_ports {DRAM_CLK}]
set_false_path -to [get_ports {DRAM_CS_N}]
set_false_path -to [get_ports {DRAM_DQ*}]
set_false_path -to [get_ports {DRAM_LDQM}]
set_false_path -to [get_ports {DRAM_RAS_N}]
set_false_path -to [get_ports {DRAM_UDQM}]
set_false_path -to [get_ports {DRAM_WE_N}]
set_false_path -to [get_ports {altera_reserved*}]
set_false_path -to [get_ports {HEX*}]
set_false_path -to [get_ports {ARDUINO_IO*}]
set_false_path -to [get_ports {ARDUINO_RESET_N}]
set_false_path -from [get_ports {ARDUINO_IO*}] 
set_false_path -to [get_ports {VGA*}]
set_false_path -to [get_pins -nocase -compatibility_mode {*|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain*|clrn}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_oci_break:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci_break|break_readreg*}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr*}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug|*resetlatch}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr[33]}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug|monitor_ready}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr[0]}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug|monitor_error}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr[34]}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_ocimem:the_ZFsoc_nios2_gen2_0_cpu_nios2_ocimem|*MonDReg*}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr*}]
set_false_path -from [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_tck:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_tck|*sr*}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_sysclk:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_sysclk|*jdo*}]
set_false_path -from [get_keepers {sld_hub:*|irf_reg*}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_wrapper|ZFsoc_nios2_gen2_0_cpu_debug_slave_sysclk:the_ZFsoc_nios2_gen2_0_cpu_debug_slave_sysclk|ir*}]
set_false_path -from [get_keepers {sld_hub:*|sld_shadow_jsm:shadow_jsm|state[1]}] -to [get_keepers {*ZFsoc_nios2_gen2_0_cpu:*|ZFsoc_nios2_gen2_0_cpu_nios2_oci:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci|ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug:the_ZFsoc_nios2_gen2_0_cpu_nios2_oci_debug|monitor_go}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************

set_max_delay -from [get_registers {*altera_avalon_st_clock_crosser:*|in_data_buffer*}] -to [get_registers {*altera_avalon_st_clock_crosser:*|out_data_buffer*}] 100.000
set_max_delay -from [get_registers *] -to [get_registers {*altera_avalon_st_clock_crosser:*|altera_std_synchronizer_nocut:*|din_s1}] 100.000


#**************************************************************
# Set Minimum Delay
#**************************************************************

set_min_delay -from [get_registers {*altera_avalon_st_clock_crosser:*|in_data_buffer*}] -to [get_registers {*altera_avalon_st_clock_crosser:*|out_data_buffer*}] -100.000
set_min_delay -from [get_registers *] -to [get_registers {*altera_avalon_st_clock_crosser:*|altera_std_synchronizer_nocut:*|din_s1}] -100.000


#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Net Delay
#**************************************************************

set_net_delay -max 2.000 -from [get_registers {*altera_avalon_st_clock_crosser:*|in_data_buffer*}] -to [get_registers {*altera_avalon_st_clock_crosser:*|out_data_buffer*}]
set_net_delay -max 2.000 -from [get_registers *] -to [get_registers {*altera_avalon_st_clock_crosser:*|altera_std_synchronizer_nocut:*|din_s1}]
