#==============================================================================
# PCIe Transaction Layer - Vivado Xsim Simulation Script
#==============================================================================

# Configuration
set TEST_NAME "tl_cpl_test"  ;# Options: tl_tx_test, tl_rx_test, tl_cpl_test
set UVM_VERBOSITY "UVM_HIGH"  ;# Options: UVM_LOW, UVM_MEDIUM, UVM_HIGH, UVM_DEBUG

# Project paths
set PROJECT_ROOT [file normalize [file dirname [info script]]]
set COMMON_DIR "${PROJECT_ROOT}/common"
set SRC_DIR "${PROJECT_ROOT}/tl/Src"
set VERIF_DIR "${PROJECT_ROOT}/tl/Verification"

# Simulation output directory
set SIM_DIR "${PROJECT_ROOT}/sim_output"
file mkdir $SIM_DIR

#==============================================================================
# Helper Functions
#==============================================================================

proc banner {msg} {
    puts "\n======================================"
    puts "  $msg"
    puts "======================================\n"
}

#==============================================================================
# File Lists in Compilation Order
#==============================================================================

set DESIGN_FILES [list \
    "${SRC_DIR}/tl_fifo.sv" \
    "${SRC_DIR}/tl_credit_mgr.sv" \
    "${SRC_DIR}/tl_tag_table.sv" \
    "${SRC_DIR}/cfg_space.sv" \
    "${SRC_DIR}/tl_hdr_gen.sv" \
    "${SRC_DIR}/tl_payload_mux.sv" \
    "${SRC_DIR}/tl_tx_queue_router.sv" \
    "${SRC_DIR}/tl_tx_arb.sv" \
    "${SRC_DIR}/tl_cpl_gen.sv" \
    "${SRC_DIR}/tl_cpl_engine.sv" \
    "${SRC_DIR}/tl_rx_parser.sv" \
    "${SRC_DIR}/tl_top.sv" \
]

set VERIF_FILES [list \
    "${VERIF_DIR}/tl_user_if.sv" \
    "${VERIF_DIR}/tl_dll_if.sv" \
    "${VERIF_DIR}/mem_if.sv" \
    "${VERIF_DIR}/tl_uvm_pkg.sv" \
    "${VERIF_DIR}/uvm_top.sv" \
]

#==============================================================================
# Main Compilation and Simulation Flow
#==============================================================================

banner "Vivado Xsim Simulation Flow"
puts "Test Name: $TEST_NAME"
puts "Verbosity: $UVM_VERBOSITY"
puts "Output Dir: $SIM_DIR\n"

# Change to simulation directory
cd $SIM_DIR

# Step 1: Compile common package
banner "Compiling Common Package"
if {[catch {exec xvlog -sv -work xil_defaultlib "${COMMON_DIR}/tl_pkg.sv"} result]} {
    puts "ERROR: Failed to compile tl_pkg.sv"
    puts $result
    exit 1
}
puts "tl_pkg.sv compiled successfully"

# Step 2: Compile design files
banner "Compiling Design Files"
foreach file $DESIGN_FILES {
    if {![file exists $file]} {
        puts "ERROR: File not found: $file"
        exit 1
    }
    set filename [file tail $file]
    puts "Compiling: $filename"
    if {[catch {exec xvlog -sv -work xil_defaultlib $file} result]} {
        puts "ERROR: Failed to compile $filename"
        puts $result
        exit 1
    }
}
puts "All design files compiled successfully"

# Step 3: Compile verification files
banner "Compiling Verification Files"
foreach file $VERIF_FILES {
    if {![file exists $file]} {
        puts "ERROR: File not found: $file"
        exit 1
    }
    set filename [file tail $file]
    puts "Compiling: $filename"
    if {[catch {exec xvlog -sv -L uvm -work xil_defaultlib $file} result]} {
        puts "ERROR: Failed to compile $filename"
        puts $result
        exit 1
    }
}
puts "All verification files compiled successfully"

# Step 4: Elaborate
banner "Elaborating Design"
if {[catch {exec xelab -debug typical -timescale 1ns/1ps -top xil_defaultlib.top -snapshot tb_snapshot -L uvm} result]} {
    puts "ERROR: Elaboration failed"
    puts $result
    exit 1
}
puts "Elaboration completed successfully"

# Step 5: Run simulation
banner "Running Simulation: $TEST_NAME"
set sim_cmd [list xsim tb_snapshot \
    -testplusarg "UVM_TESTNAME=$TEST_NAME" \
    -testplusarg "UVM_VERBOSITY=$UVM_VERBOSITY" \
    -runall \
    -log ${TEST_NAME}_sim.log]

if {[catch {exec {*}$sim_cmd} result]} {
    # Xsim may return non-zero even on success, check log for actual errors
    if {[string match "*ERROR*" $result] || [string match "*FATAL*" $result]} {
        puts "Simulation encountered errors:"
        puts $result
        exit 1
    }
}

puts "Simulation completed"
puts "\nSimulation log: ${SIM_DIR}/${TEST_NAME}_sim.log"

# Return to project root
cd $PROJECT_ROOT

banner "Simulation Complete"