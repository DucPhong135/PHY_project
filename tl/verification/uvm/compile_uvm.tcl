#------------------------------------------------------------------
# UVM Testbench Compilation Script
#------------------------------------------------------------------

# Set the project directory
set proj_dir [pwd]
set common_dir "${proj_dir}/common"
set rtl_dir "${proj_dir}/tl"
set uvm_dir "${proj_dir}/tl/verification/uvm"

puts "========================================="
puts "Compiling UVM Testbench for TL Design"
puts "========================================="

#------------------------------------------------------------------
# Step 1: Compile Design Package (from common directory)
#------------------------------------------------------------------
puts "\n(Step 1) Compiling Design Package..."
read_verilog -sv ${common_dir}/tl_pkg.sv

#------------------------------------------------------------------
# Step 2: Compile RTL Design Files
#------------------------------------------------------------------
puts "\n(Step 2) Compiling RTL Design Files..."
read_verilog -sv ${rtl_dir}/tl_hdr_gen.sv
read_verilog -sv ${rtl_dir}/tl_rx_parser.sv
read_verilog -sv ${rtl_dir}/tl_tag_table.sv
read_verilog -sv ${rtl_dir}/tl_credit_mgr.sv
read_verilog -sv ${rtl_dir}/tl_fifo.sv
read_verilog -sv ${rtl_dir}/tl_top.sv

#------------------------------------------------------------------
# Step 3: Compile UVM Interfaces
#------------------------------------------------------------------
puts "\n(Step 3) Compiling UVM Interfaces..."
read_verilog -sv ${uvm_dir}/tl_user_if.sv
read_verilog -sv ${uvm_dir}/tl_dll_if.sv

#------------------------------------------------------------------
# Step 4: Compile UVM Package (All Components)
#------------------------------------------------------------------
puts "\n(Step 4) Compiling UVM Package..."
read_verilog -sv ${uvm_dir}/tl_uvm_pkg.sv

#------------------------------------------------------------------
# Step 5: Compile Testbench Top
#------------------------------------------------------------------
puts "\n(Step 5) Compiling Testbench Top..."
read_verilog -sv ${uvm_dir}/uvm_top.sv

#------------------------------------------------------------------
# Step 6: Elaborate Design
#------------------------------------------------------------------
puts "\n(Step 6) Elaborating Design..."
synth_design -top uvm_top -part xc7a35tcpg236-1

puts "\n========================================="
puts "Compilation Complete!"
puts "========================================="