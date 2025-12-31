# PCIe Gen 3 Transaction Layer Implementation

A SystemVerilog implementation of the PCIe Gen 3 Transaction Layer (TL) with support for memory and configuration space transactions, including a comprehensive UVM verification environment.

## Project Overview

This project implements the Transaction Layer of the PCIe Gen 3 protocol stack. The Transaction Layer is responsible for creating and processing Transaction Layer Packets (TLPs) for communication between PCIe devices.

### Supported Features

- **Memory Transactions:**
  - Memory Read (MRd)
  - Memory Write (MWr)

- **Configuration Transactions:**
  - Configuration Type 0 Read (CfgRd0)
  - Configuration Type 0 Write (CfgWr0)

## Architecture

### TX Path

The transmit path processes outgoing TLP requests through a four-stage pipeline:

```
User Interface → tl_hdr_gen → tl_payload_mux → tl_tx_queue_router → tl_tx_arb → DLL
```

#### TX Modules

1. **tl_hdr_gen** - Header Generation
   - Generates TLP headers for memory and configuration requests
   - Formats headers according to PCIe Gen 3 specifications

2. **tl_payload_mux** - Payload Multiplexer
   - Combines TLP headers with payload data
   - Manages data flow synchronization

3. **tl_tx_queue_router** - Queue Router
   - Routes TLPs to appropriate queues based on type and priority
   - Handles queue management and flow control

4. **tl_tx_arb** - Transmit Arbiter
   - Arbitrates between multiple TX queues
   - Ensures fair access to the Data Link Layer interface

### RX Path

The receive path parses incoming TLPs and routes them appropriately:

```
DLL → tl_rx_parser → [tl_hdr_gen | tl_cpl_engine]
                     ↓                    ↓
              Completion Required    Completion Received
```

#### RX Modules

1. **tl_rx_parser** - Receive Parser
   - Parses incoming TLPs from the Data Link Layer
   - Extracts header information and payload data
   - Identifies packet type and routing requirements

2. **tl_hdr_gen** - Header Generation (Completion Path)
   - Generates completion TLP headers in response to received requests
   - Triggered when received packet requires a completion

3. **tl_cpl_engine** - Completion Engine
   - Processes received completion packets
   - Matches completions to outstanding requests
   - Handles completion data delivery to requesters

### Supporting Modules

Additional modules in the design include:

- **cfg_space.sv** - Configuration Space implementation
- **tl_credit_mgr.sv** - Credit-based flow control management
- **tl_fifo.sv** - FIFO structures for buffering
- **tl_tag_table.sv** - Tag management for outstanding transactions
- **tl_top.sv** - Top-level integration module

## Verification Environment

The project includes a comprehensive UVM-based verification environment for functional verification of the Transaction Layer implementation.

### UVM Testbench Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     UVM Test                            │
├─────────────────────────────────────────────────────────┤
│                   UVM Environment                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ User Agent   │  │  DLL Agent   │  │ Memory Agent │   │
│  │              │  │              │  │              │   │
│  │ • Driver     │  │ • Driver     │  │ • Driver     │   │
│  │ • Monitor    │  │ • Monitor    │  │ • Monitor    │   │
│  │ • Sequencer  │  │ • Sequencer  │  │ • Sequencer  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │              Scoreboards                       │     │
│  │  • TX Scoreboard                               │     │
│  │  • RX Scoreboard                               │     │
│  │  • Completion Scoreboard                       │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │          Memory Model (RX Testing)             │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Verification Components

#### Agents

1. **User Agent** (`tl_user_agent.sv`)
   - Drives transactions from the user/application side
   - Monitors user interface responses
   - Provides sequence items for user-initiated transactions

2. **DLL Agent** (`tl_dll_agent.sv`)
   - Emulates the Data Link Layer interface
   - Monitors TLPs at the DLL boundary
   - Drives received TLPs into the RX path

3. **Memory Agent** (`mem_agent.sv`)
   - Manages memory access operations
   - Provides memory storage for testing
   - Responds to memory read/write requests

#### Test Sequences

- **TX Tests** (`tl_tx_test.sv`)
  - `tx_mem_read_seq.sv` - Memory read transaction sequences
  - `tx_mem_write_seq.sv` - Memory write transaction sequences
  - `tx_cfg_read_seq.sv` - Configuration read sequences
  - `tx_cfg_write_seq.sv` - Configuration write sequences

- **RX Tests** (`tl_rx_test.sv`)
  - `rx_memory_seq.sv` - RX path memory transaction testing
  - Uses memory model for request handling

- **Completion Tests** (`tl_cpl_test.sv`)
  - `cpl_sequence.sv` - Completion generation and matching
  - Uses mailbox for interactive sequence coordination
  - Tests completion routing and data integrity

#### Scoreboards

Automated checking is implemented through three specialized scoreboards:

1. **TX Scoreboard** (`tx_scoreboard.sv`)
   - Verifies correct TLP generation on TX path
   - Checks header formatting and payload integrity
   - Validates protocol compliance

2. **RX Scoreboard** (`rx_scoreboard.sv`)
   - Monitors received TLP parsing
   - Verifies routing decisions
   - Checks data delivery to appropriate endpoints

3. **Completion Scoreboard** (`cpl_scoreboard.sv`)
   - Tracks outstanding requests
   - Matches completions to requests
   - Verifies completion data correctness

#### Memory Model

- **Memory Model** (`tl_memory_model.sv`)
  - Simulates system memory for RX path testing
  - Handles memory read/write operations
  - Provides predictable responses for verification

#### Interactive Sequences

The verification environment uses mailbox-based communication for completion sequences:
- Enables coordination between request generation and completion handling
- Supports complex test scenarios with dynamic request-completion matching
- Facilitates out-of-order completion testing

## Directory Structure

```
.
├── common/
│   └── tl_pkg.sv                    # Common package definitions
│
├── tl/
│   ├── Src/                         # RTL Source Files
│   │   ├── tl_top.sv               # Top-level module
│   │   ├── cfg_space.sv            # Configuration space
│   │   ├── tl_hdr_gen.sv           # Header generation
│   │   ├── tl_payload_mux.sv       # Payload multiplexer
│   │   ├── tl_tx_queue_router.sv   # TX queue router
│   │   ├── tl_tx_arb.sv            # TX arbiter
│   │   ├── tl_rx_parser.sv         # RX parser
│   │   ├── tl_cpl_engine.sv        # Completion engine
│   │   ├── tl_cpl_gen.sv           # Completion generator
│   │   ├── tl_credit_mgr.sv        # Credit manager
│   │   ├── tl_fifo.sv              # FIFO structures
│   │   └── tl_tag_table.sv         # Tag management
│   │
│   └── Verification/                # UVM Testbench
│       ├── uvm_top.sv              # UVM top module
│       ├── tl_tb.sv                # Testbench
│       ├── tl_uvm_pkg.sv           # UVM package
│       │
│       ├── tl_user_agent.sv        # User agent
│       ├── tl_user_driver.sv
│       ├── tl_user_monitor.sv
│       ├── tl_user_sequencer.sv
│       ├── tl_user_seq_item.sv
│       ├── tl_user_if.sv
│       ├── tl_user_env.sv
│       │
│       ├── tl_dll_agent.sv         # DLL agent
│       ├── tl_dll_driver.sv
│       ├── tl_dll_monitor.sv
│       ├── tl_dll_sequencer.sv
│       ├── tl_dll_if.sv
│       ├── tl_dll_env.sv
│       │
│       ├── mem_agent.sv            # Memory agent
│       ├── mem_monitor.sv
│       ├── mem_seq_item.sv
│       ├── mem_storage.sv
│       ├── mem_if.sv
│       ├── mem_env.sv
│       │
│       ├── tl_tx_test.sv           # TX tests
│       ├── tx_mem_read_seq.sv
│       ├── tx_mem_write_seq.sv
│       ├── tx_cfg_read_seq.sv
│       ├── tx_cfg_write_seq.sv
│       ├── tx_seq.sv
│       │
│       ├── tl_rx_test.sv           # RX tests
│       ├── rx_memory_seq.sv
│       ├── rx_seq.sv
│       │
│       ├── tl_cpl_test.sv          # Completion tests
│       ├── cpl_sequence.sv
│       ├── cpl_scoreboard.sv
│       ├── tl_cpl_agent.sv
│       │
│       ├── tx_scoreboard.sv        # Scoreboards
│       ├── rx_scoreboard.sv
│       │
│       └── tl_memory_model.sv      # Memory model
│
└── SerDes_project/                  # Simulation project files
    └── SerDes_project.xpr          # Vivado/simulator project
```

## Running Simulations

### Prerequisites

Before running simulations, ensure you have:
- **Xilinx Vivado** installed and in your system PATH
- **Vivado Xsim simulator** available
- **UVM library** installed with Vivado (included by default)
- TCL interpreter (included with Vivado)

### Command-Line Simulation with TCL Script

The project includes `run_sim.tcl` for automated command-line simulation without opening the Vivado GUI.

#### Basic Usage

```bash
vivado -mode batch -source run_sim.tcl
```

Or using Vivado's TCL shell:

```bash
vivado -mode tcl -source run_sim.tcl
```

#### Configuration Options

Edit the `run_sim.tcl` file to configure the simulation before running:

```tcl
set TEST_NAME "tl_cpl_test"  ;# Options: tl_tx_test, tl_rx_test, tl_cpl_test
set UVM_VERBOSITY "UVM_LOW"  ;# Options: UVM_LOW, UVM_MEDIUM, UVM_HIGH, UVM_DEBUG
```

**Available Tests:**
- `tl_tx_test` - Tests the transmit path (memory read/write, config read/write)
- `tl_rx_test` - Tests the receive path (memory transaction handling)
- `tl_cpl_test` - Tests completion generation and matching

**Verbosity Levels:**
- `UVM_LOW` - Minimal output (recommended for regression)
- `UVM_MEDIUM` - Moderate detail
- `UVM_HIGH` - Detailed transaction information
- `UVM_DEBUG` - Full debug output

#### What the Script Does

The `run_sim.tcl` script automates the complete simulation flow:
1. Compiles the common package (`tl_pkg.sv`)
2. Compiles all RTL design files
3. Compiles UVM verification files
4. Elaborates the design
5. Runs the specified test
6. Generates simulation logs

#### Output Location

Simulation outputs are generated in the `sim_output/` directory:
- `<TEST_NAME>_sim.log` - Simulation log file
- Compiled libraries and elaborated snapshots

#### Example: Running Different Tests

```bash
# Run TX path test
# Edit run_sim.tcl: set TEST_NAME "tl_tx_test"
vivado -mode batch -source run_sim.tcl

# Run RX path test
# Edit run_sim.tcl: set TEST_NAME "tl_rx_test"
vivado -mode batch -source run_sim.tcl

# Run completion test with high verbosity
# Edit run_sim.tcl: set TEST_NAME "tl_cpl_test"
#                   set UVM_VERBOSITY "UVM_HIGH"
vivado -mode batch -source run_sim.tcl
```

### Simulation Results

Test results will be generated in the simulation output directory. Scoreboards provide automatic pass/fail indication for each test scenario.

## Running Synthesis

### Prerequisites

Before running synthesis, ensure you have:
- **Xilinx Vivado** installed and in your system PATH
- Appropriate FPGA part license (if targeting specific device)
- TCL interpreter (included with Vivado)

### Command-Line Synthesis with TCL Script

The project includes `run_synth.tcl` for automated command-line synthesis without opening the Vivado GUI.

#### Basic Usage

```bash
vivado -mode batch -source run_synth.tcl
```

Or using Vivado's TCL shell:

```bash
vivado -mode tcl -source run_synth.tcl
```

#### Configuration Options

Edit the `run_synth.tcl` file to configure the synthesis flow before running:

```tcl
set RUN_IMPLEMENTATION 0   ;# Set to 1 to run implementation after synthesis
set RUN_BITSTREAM 0        ;# Set to 1 to generate bitstream (requires implementation)
set NUM_JOBS 8             ;# Number of parallel jobs for synthesis/implementation
set TARGET_PART "xc7k325tffg900-2"  ;# Target FPGA part number
```

**Configuration Parameters:**
- `RUN_IMPLEMENTATION` - Set to `1` to automatically run implementation (place & route) after synthesis
- `RUN_BITSTREAM` - Set to `1` to generate programming bitstream (requires implementation)
- `NUM_JOBS` - Number of parallel threads for synthesis and implementation (adjust based on your CPU)
- `TARGET_PART` - Target FPGA device part number (update for your specific hardware)

#### What the Script Does

The `run_synth.tcl` script automates the complete synthesis flow:
1. Creates or opens the Vivado project (`tl_synth_project`)
2. Adds the common package file (`common/tl_pkg.sv`)
3. Adds all RTL design files from `tl/Src/`
4. Sets `tl_top` as the top-level module
5. Updates compile order
6. Runs synthesis with multi-threading
7. Generates comprehensive reports (timing, utilization, power)
8. Optionally runs implementation and generates bitstream
9. Saves design checkpoints for incremental flows

#### Source Files Synthesized

The script synthesizes the following files in order:
- `common/tl_pkg.sv` - Common package definitions
- `tl/Src/tl_fifo.sv`
- `tl/Src/tl_credit_mgr.sv`
- `tl/Src/tl_tag_table.sv`
- `tl/Src/cfg_space.sv`
- `tl/Src/tl_hdr_gen.sv`
- `tl/Src/tl_payload_mux.sv`
- `tl/Src/tl_tx_queue_router.sv`
- `tl/Src/tl_tx_arb.sv`
- `tl/Src/tl_cpl_gen.sv`
- `tl/Src/tl_cpl_engine.sv`
- `tl/Src/tl_rx_parser.sv`
- `tl/Src/tl_top.sv` (top module)

#### Output Directories and Files

Synthesis outputs are organized in the following directories:

```
.
├── tl_synth_project/           # Vivado project directory
│   ├── tl_synth_project.xpr   # Vivado project file
│   └── ...                    # Project database and cache files
│
├── synth_reports/             # Synthesis reports
│   ├── synthesis/            # Post-synthesis reports
│   │   ├── timing_summary.rpt    # Timing analysis
│   │   ├── utilization.rpt       # Resource utilization
│   │   └── power.rpt             # Power estimation
│   └── implementation/       # Post-implementation reports (if enabled)
│       ├── timing_summary.rpt
│       ├── utilization.rpt
│       ├── power.rpt
│       ├── clock_interaction.rpt
│       └── drc.rpt              # Design Rule Check results
│
├── checkpoints/              # Design checkpoints
│   ├── post_synth.dcp       # Post-synthesis checkpoint
│   └── post_route.dcp       # Post-route checkpoint (if implementation enabled)
│
└── design.bit               # Programming bitstream (if bitstream generation enabled)
```

**Key Output Files:**
- **Timing Reports** - Shows timing paths, slack, and whether timing constraints are met
- **Utilization Reports** - Details resource usage (LUTs, FFs, BRAMs, DSPs)
- **Power Reports** - Estimates power consumption
- **Design Checkpoints (.dcp)** - Allows resuming synthesis/implementation from saved state
- **Bitstream (.bit)** - Programming file for FPGA configuration

#### Example: Running Synthesis Only

```bash
# Ensure configuration in run_synth.tcl:
# set RUN_IMPLEMENTATION 0
# set RUN_BITSTREAM 0
vivado -mode batch -source run_synth.tcl
```

#### Example: Running Complete Flow (Synthesis + Implementation + Bitstream)

```bash
# Edit run_synth.tcl:
# set RUN_IMPLEMENTATION 1
# set RUN_BITSTREAM 1
vivado -mode batch -source run_synth.tcl
```

### Synthesis Results

After synthesis completes:
- Check `synth_reports/synthesis/timing_summary.rpt` for timing analysis
- Review `synth_reports/synthesis/utilization.rpt` for resource usage
- If implementation was run, check WNS (Worst Negative Slack) in the console output:
  - WNS ≥ 0: Timing constraints met ✓
  - WNS < 0: Timing constraints not met (requires optimization)

## Design Constraints

- PCIe Gen 3 compliant TLP formatting
- 32-bit and 64-bit addressing support
- Credit-based flow control
- Out-of-order completion support

## Future Enhancements

Potential areas for expansion:
- AXI compatible interface for easier integration with ARM-based systems
- Support for additional TLP types (I/O, Message)
- Configuration Type 1 transactions
- Error injection and recovery
- Performance monitoring counters
- Power management support
- Virtual channel support

## References

- PCI Express Base Specification Revision 3.0
- Universal Verification Methodology (UVM) 1.2 User's Guide


