#==============================================================================
# PCIe Transaction Layer - Vivado Synthesis Script
#==============================================================================

# Configuration
set RUN_IMPLEMENTATION 0   ;# Set to 1 to run implementation after synthesis
set RUN_BITSTREAM 0        ;# Set to 1 to generate bitstream (requires implementation)
set NUM_JOBS 8             ;# Number of parallel jobs for synthesis/implementation
set TARGET_PART "xc7k70tfbv676-1"  ;# Target FPGA part number (update as needed)

# Project paths
set PROJECT_ROOT [file normalize [file dirname [info script]]]
set COMMON_DIR "${PROJECT_ROOT}/common"
set SRC_DIR "${PROJECT_ROOT}/tl/Src"
set PROJECT_NAME "tl_synth_project"
set PROJECT_DIR "${PROJECT_ROOT}/${PROJECT_NAME}"
set PROJECT_FILE "${PROJECT_DIR}/${PROJECT_NAME}.xpr"

# Output directories
set REPORTS_DIR "${PROJECT_ROOT}/synth_reports"
set CHECKPOINT_DIR "${PROJECT_ROOT}/checkpoints"
file mkdir $REPORTS_DIR
file mkdir $CHECKPOINT_DIR

#==============================================================================
# Helper Functions
#==============================================================================

proc banner {msg} {
    puts "\n======================================"
    puts "  $msg"
    puts "======================================\n"
}

proc save_reports {run_name phase} {
    global REPORTS_DIR
    set phase_dir "${REPORTS_DIR}/${phase}"
    file mkdir $phase_dir
    
    banner "Saving ${phase} Reports"
    
    # Timing reports
    if {[catch {
        report_timing_summary -file "${phase_dir}/timing_summary.rpt" \
            -max_paths 10 -delay_type max
    }]} {
        puts "Warning: Timing summary report failed"
    }
    
    # Utilization report
    if {[catch {
        report_utilization -file "${phase_dir}/utilization.rpt" -hierarchical
    }]} {
        puts "Warning: Utilization report failed"
    }
    
    # Power report
    if {[catch {
        report_power -file "${phase_dir}/power.rpt"
    }]} {
        puts "Warning: Power report failed"
    }
    
    # Clock interaction report (post-implementation)
    if {$phase == "implementation"} {
        if {[catch {
            report_clock_interaction -file "${phase_dir}/clock_interaction.rpt"
        }]} {
            puts "Warning: Clock interaction report failed"
        }
        
        report_drc -file "${phase_dir}/drc.rpt"
    }
    
    puts "Reports saved to: ${phase_dir}"
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

#==============================================================================
# Main Synthesis Flow
#==============================================================================

banner "Vivado Synthesis Flow"
puts "Project: $PROJECT_FILE"
puts "Number of jobs: $NUM_JOBS"
puts "Run Implementation: $RUN_IMPLEMENTATION"
puts "Generate Bitstream: $RUN_BITSTREAM\n"

# Create or open project
if {[file exists $PROJECT_FILE]} {
    banner "Opening Existing Vivado Project"
    open_project $PROJECT_FILE
    puts "Project opened successfully"
} else {
    banner "Creating New Vivado Project"
    create_project $PROJECT_NAME $PROJECT_DIR -part $TARGET_PART -force
    puts "Project created successfully"
    
    # Add common package file
    banner "Adding Common Package"
    if {![file exists "${COMMON_DIR}/tl_pkg.sv"]} {
        puts "ERROR: File not found: ${COMMON_DIR}/tl_pkg.sv"
        exit 1
    }
    add_files -fileset sources_1 "${COMMON_DIR}/tl_pkg.sv"
    puts "Added tl_pkg.sv"
    
    # Add design files
    banner "Adding Design Files"
    foreach file $DESIGN_FILES {
        if {![file exists $file]} {
            puts "ERROR: File not found: $file"
            exit 1
        }
        set filename [file tail $file]
        add_files -fileset sources_1 $file
        puts "Added: $filename"
    }
    puts "All design files added successfully"
    
    # Set top module
    set_property top tl_top [current_fileset]
    puts "Top module set to: tl_top"
}

# Update compile order (in case files were added/modified)
banner "Updating Compile Order"
update_compile_order -fileset sources_1

# Reset synthesis run
banner "Resetting Synthesis Run"
reset_run synth_1
puts "Synthesis run reset"

#==============================================================================
# Synthesis
#==============================================================================

banner "Starting Synthesis"
puts "This may take several minutes...\n"

if {[catch {
    launch_runs synth_1 -jobs $NUM_JOBS
    wait_on_run synth_1
} result]} {
    puts "ERROR: Synthesis launch failed"
    puts $result
    exit 1
}

# Check synthesis status
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    puts "Status: $synth_status"
    puts "Progress: $synth_progress"
    exit 1
}

banner "Synthesis Completed Successfully"
puts "Status: $synth_status"
puts "Progress: $synth_progress\n"

# Open synthesized design
open_run synth_1

# Save synthesis reports
save_reports synth_1 "synthesis"

# Save synthesis checkpoint
set synth_dcp "${CHECKPOINT_DIR}/post_synth.dcp"
write_checkpoint -force $synth_dcp
puts "Synthesis checkpoint saved: $synth_dcp"

#==============================================================================
# Implementation (Optional)
#==============================================================================

if {$RUN_IMPLEMENTATION} {
    banner "Starting Implementation"
    puts "This may take several minutes...\n"
    
    # Reset implementation run
    reset_run impl_1
    
    if {[catch {
        launch_runs impl_1 -jobs $NUM_JOBS
        wait_on_run impl_1
    } result]} {
        puts "ERROR: Implementation launch failed"
        puts $result
        exit 1
    }
    
    # Check implementation status
    set impl_status [get_property STATUS [get_runs impl_1]]
    set impl_progress [get_property PROGRESS [get_runs impl_1]]
    
    if {$impl_status != "route_design Complete!"} {
        puts "ERROR: Implementation failed!"
        puts "Status: $impl_status"
        puts "Progress: $impl_progress"
        exit 1
    }
    
    banner "Implementation Completed Successfully"
    puts "Status: $impl_status"
    puts "Progress: $impl_progress\n"
    
    # Open implemented design
    open_run impl_1
    
    # Save implementation reports
    save_reports impl_1 "implementation"
    
    # Save implementation checkpoint
    set impl_dcp "${CHECKPOINT_DIR}/post_route.dcp"
    write_checkpoint -force $impl_dcp
    puts "Implementation checkpoint saved: $impl_dcp"
    
    # Check timing
    set wns [get_property SLACK [get_timing_paths]]
    if {$wns < 0} {
        puts "\nWARNING: Timing not met! WNS = $wns ns"
    } else {
        puts "\nTiming met! WNS = $wns ns"
    }
}

#==============================================================================
# Bitstream Generation (Optional)
#==============================================================================

if {$RUN_IMPLEMENTATION && $RUN_BITSTREAM} {
    banner "Generating Bitstream"
    
    if {[catch {
        launch_runs impl_1 -to_step write_bitstream -jobs $NUM_JOBS
        wait_on_run impl_1
    } result]} {
        puts "ERROR: Bitstream generation failed"
        puts $result
        exit 1
    }
    
    # Check if bitstream was generated
    set bit_status [get_property STATUS [get_runs impl_1]]
    if {$bit_status != "write_bitstream Complete!"} {
        puts "ERROR: Bitstream generation incomplete"
        puts "Status: $bit_status"
        exit 1
    }
    
    banner "Bitstream Generated Successfully"
    
    # Copy bitstream to project root
    set bit_file [lindex [glob -nocomplain "${PROJECT_DIR}/SerDes_project.runs/impl_1/*.bit"] 0]
    if {$bit_file != ""} {
        set dest_bit "${PROJECT_ROOT}/design.bit"
        file copy -force $bit_file $dest_bit
        puts "Bitstream copied to: $dest_bit"
    }
}

# Close project
close_project

#==============================================================================
# Summary
#==============================================================================

banner "Synthesis Flow Complete"
puts "Results:"
puts "  - Reports: $REPORTS_DIR"
puts "  - Checkpoints: $CHECKPOINT_DIR"

if {$RUN_IMPLEMENTATION} {
    puts "\nImplementation Summary:"
    puts "  - Status: $impl_status"
    if {[info exists wns]} {
        puts "  - WNS: $wns ns"
    }
}

if {$RUN_BITSTREAM && [file exists "${PROJECT_ROOT}/design.bit"]} {
    puts "\nBitstream: ${PROJECT_ROOT}/design.bit"
}

puts "\n"
