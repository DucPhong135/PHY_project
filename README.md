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


### Simulation Results

Test results and coverage reports will be generated in the simulation output directory. Scoreboards provide automatic pass/fail indication for each test scenario.

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


