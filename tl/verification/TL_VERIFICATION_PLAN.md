# TL Verification Plan - Vivado UVM Compatible

## 1. Verification Scope

### Design Under Test
- **Module:** Transaction Layer (TL) implementation
- **Key Components:**
  - `tl_hdr_gen` - TX header generation
  - `tl_rx_parser` - RX TLP parsing
  - `tl_tag_table` - Tag management
  - `tl_credit_mgr` - Credit flow control

### Verification Goals
- Verify correct TLP header generation for Memory and Config transactions
- Verify RX parser correctly decodes incoming TLPs
- Verify credit-based flow control
- Verify tag allocation and tracking
- Verify byte enable generation

---

## 2. UVM Components (Vivado Compatible)

### 2.1 Core UVM Classes to Use
Only using classes well-supported in Vivado xsim:

✅ **Supported:**
- `uvm_sequence_item` - Transaction base class
- `uvm_sequence` - Stimulus sequences
- `uvm_driver` - Protocol driver
- `uvm_monitor` - Signal monitor
- `uvm_agent` - Agent container
- `uvm_env` - Environment
- `uvm_test` - Test base class
- `uvm_config_db` - Configuration database

⚠️ **Avoid/Simplify:**
- `uvm_tlm_fifo` - Use simple queues instead
- Complex `uvm_analysis_port` chains - Keep minimal
- `uvm_reg` package - Not needed for this design
- Factory overrides - Keep simple

### 2.2 Testbench Architecture

```
┌─────────────────────────────────────────────┐
│           tl_base_test (uvm_test)           │
│  ┌───────────────────────────────────────┐  │
│  │        tl_env (uvm_env)               │  │
│  │  ┌─────────────┐  ┌─────────────┐     │  │
│  │  │ cmd_agent   │  │ tlp_agent   │     |  │
│  │  │ (TX)        │  │ (RX)        │     │  │
│  │  └─────────────┘  └─────────────┘     │  │
│  │  ┌─────────────────────────────┐      │  │
│  │  │   scoreboard (simple)       │      │  │
│  │  └─────────────────────────────┘      │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
                   ↓
          ┌─────────────────┐
          │   DUT: tl_top   │
          └─────────────────┘
```

---

## 3. Test Scenarios

### 3.1 TX Path Tests (Priority: HIGH)

#### Test 1: Basic Memory Write
**Objective:** Verify 32-bit Memory Write header generation
- Send MemWr command (addr=0x1000, len=1, data=0xDEADBEEF)
- Check header: Fmt/Type=0x40, Length=1, is_posted=1
- Verify first DW data packing in hdr_o[31:0]
- Check byte enables for aligned access

#### Test 2: Basic Memory Read  
**Objective:** Verify 32-bit Memory Read header generation
- Send MemRd command (addr=0x2000, len=1)
- Check header: Fmt/Type=0x00, Length=1, is_posted=0
- Verify tag allocation and insertion
- Check byte enables

#### Test 3: 64-bit Address Operations
**Objective:** Verify 4DW header generation
- Send MemWr with 64-bit address
- Check header: Fmt/Type=0x60
- Send MemRd with 64-bit address  
- Check header: Fmt/Type=0x20

#### Test 4: Unaligned Accesses
**Objective:** Verify byte enables for all alignments
- Test address offsets: 0, 1, 2, 3
- Verify First DW BE calculated correctly
- For single DW (len=1): verify Last DW BE = 0x0

#### Test 5: Config Transactions
**Objective:** Verify Config Read/Write headers
- Send CfgRd (bus/dev/func encoding)
- Check header: Fmt/Type=0x04
- Send CfgWr
- Check header: Fmt/Type=0x44

#### Test 6: Multi-DW Transfers
**Objective:** Verify payload length handling
- Send MemWr with len=4
- Verify length field in header
- Check byte enables for multi-DW

#### Test 7: Credit Flow Control
**Objective:** Verify FSM respects credit signals
- De-assert ph_credit_ok_i
- Send MemWr command
- Verify header not sent until credits available
- Restore credits, verify header transmission

---

### 3.2 RX Path Tests (Priority: HIGH)

#### Test 8: Completion without Data (Cpl)
**Objective:** Verify Cpl parsing
- Drive Cpl header on tl_rx_i
- Verify cpl_o fields: tag, status, byte_count
- Check has_data=0

#### Test 9: Completion with Data (CplD)
**Objective:** Verify CplD parsing and data extraction
- Drive CplD header with first data DW
- Verify cpl_o fields populated
- Check has_data=1
- Verify data[31:0] captured

#### Test 10: Multi-beat CplD
**Objective:** Verify streaming completion data
- Drive CplD with byte_count > 4
- Send multiple data beats
- Verify byte_count tracking

#### Test 11: Completion Status Codes
**Objective:** Verify status field parsing
- Test status=000 (Successful Completion)
- Test status=001 (Unsupported Request)
- Verify status field in cpl_o

---

### 3.3 System Tests (Priority: MEDIUM)

#### Test 12: Back-to-Back Commands
**Objective:** Verify continuous operation
- Send 10 consecutive MemWr commands
- Verify all headers generated correctly

#### Test 13: Mixed Transaction Types
**Objective:** Verify proper handling of different TLP types
- Interleave MemRd, MemWr, CfgRd
- Verify correct header generation for each

#### Test 14: Random Transaction Stream
**Objective:** Stress test with randomized inputs
- Randomize: addr, len, data, transaction type
- Run 50-100 transactions
- Verify all pass

---

## 4. UVM Sequences (To Be Implemented)

### Base Sequence Class
```systemverilog
class tl_base_seq extends uvm_sequence #(tl_transaction);
  `uvm_object_utils(tl_base_seq)
  
  // Helper tasks
  task send_mem_write(...);
  task send_mem_read(...);
  task send_cfg_read(...);
endclass
```

### Test Sequences
1. `tl_single_write_seq` - Single MemWr
2. `tl_single_read_seq` - Single MemRd
3. `tl_unaligned_seq` - All address alignments
4. `tl_random_seq` - Randomized transactions
5. `tl_back2back_seq` - Continuous stream

---

## 5. Verification Metrics

### 5.1 Functional Coverage (Manual Tracking)

**Transaction Types:**
- [ ] Memory Write 32-bit
- [ ] Memory Write 64-bit
- [ ] Memory Read 32-bit
- [ ] Memory Read 64-bit
- [ ] Config Read
- [ ] Config Write
- [ ] Completion (Cpl)
- [ ] Completion with Data (CplD)

**Address Alignments:**
- [ ] Offset = 0 (aligned)
- [ ] Offset = 1
- [ ] Offset = 2
- [ ] Offset = 3

**Payload Lengths:**
- [ ] Single DW (len=1)
- [ ] 2-4 DW
- [ ] 5-16 DW
- [ ] 17-64 DW

**FSM States (tl_hdr_gen):**
- [ ] FSM_IDLE
- [ ] FSM_DECODE
- [ ] FSM_WAIT_TAG
- [ ] FSM_GEN_HDR
- [ ] FSM_SEND_HDR
- [ ] FSM_WAIT_CRED

**Credit Scenarios:**
- [ ] All credits available
- [ ] Posted header credit blocked
- [ ] Non-posted header credit blocked
- [ ] Credit restoration

### 5.2 Code Coverage
- Target: >90% line coverage (automated by xsim)
- Use: `xsim -cov_db_name coverage.ucdb`

---

## 6. Scoreboard Checking Strategy

### Simple Self-Checking Approach
Since complex TLM analysis ports can be problematic in Vivado:

**Method 1: Direct Monitoring**
```systemverilog
class tl_scoreboard extends uvm_scoreboard;
  // Simple queues
  tl_transaction exp_queue[$];
  
  // Direct monitoring
  task check_header(tl_header_item hdr);
    // Compare with expected
  endtask
endclass
```

**Checks to Implement:**
1. **Header Format Check**
   - Fmt/Type field matches transaction type
   - Length field correct
   - Requester ID matches configuration

2. **Byte Enable Check**
   - First DW BE based on address[1:0]
   - Last DW BE = 0x0 for single DW

3. **Address Check**
   - Address properly encoded
   - 32-bit vs 64-bit format

4. **Credit Protocol Check**
   - Headers only sent when credits available
   - FSM behavior matches credit state

5. **Tag Management Check**
   - Tags allocated for non-posted
   - Tags not used for posted

---

## 7. Running Tests in Vivado

### Compilation Order
```tcl
# 1. Compile UVM library (built into Vivado)
# 2. Compile DUT
read_verilog -sv tl/common/tl_pkg.sv
read_verilog -sv tl/tl_hdr_gen.sv
read_verilog -sv tl/tl_rx_parser.sv
# ... other DUT files

# 3. Compile testbench
read_verilog -sv verification/tl_if.sv
read_verilog -sv verification/tl_uvm_pkg.sv
read_verilog -sv verification/tb_top.sv
```

### Run Simulation
```tcl
# Set top
set_property top tb_top [get_filesets sim_1]

# Launch with UVM
set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} -objects [get_filesets sim_1]

launch_simulation

# Run specific test
run all
# Or: xsim ... +UVM_TESTNAME=tl_single_write_test
```

### Enable Coverage
```tcl
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg COVERAGE} -objects [get_filesets sim_1]
```

---

## 8. Test Development Phases

### Phase 1: Foundation (Week 1)
- [ ] Create interface (tl_if.sv)
- [ ] Create transaction class (tl_transaction)
- [ ] Create base sequence (tl_base_seq)
- [ ] Create simple driver (tl_cmd_driver)
- [ ] Create simple monitor (tl_hdr_monitor)

### Phase 2: Basic Tests (Week 2)
- [ ] Test 1: Single MemWr
- [ ] Test 2: Single MemRd
- [ ] Test 3: Config transactions
- [ ] Simple scoreboard

### Phase 3: Advanced Tests (Week 3)
- [ ] Unaligned access tests
- [ ] Multi-DW tests
- [ ] Credit flow control tests
- [ ] RX path tests

### Phase 4: Coverage & Debug (Week 4)
- [ ] Add functional coverage
- [ ] Run regression
- [ ] Debug failures
- [ ] Document results

---

## 9. Expected Results

### Pass Criteria
- ✅ All directed tests pass
- ✅ Random test runs 100 transactions without errors
- ✅ No protocol violations detected
- ✅ All functional coverage bins hit
- ✅ Code coverage >90%

### Typical Test Output
```
UVM_INFO @ 0: reporter [RNTST] Running test tl_single_write_test...
UVM_INFO @ 20ns: tl_driver [DRIVE] Sending MemWr addr=0x1000
UVM_INFO @ 28ns: tl_monitor [MON] Header: fmt_type=0x40 posted=1
UVM_INFO @ 28ns: tl_scoreboard [CHECK] Header format: PASS
UVM_INFO @ 28ns: tl_scoreboard [CHECK] Byte enables: PASS
UVM_INFO @ 100ns: reporter [TEST] Test PASSED
```

---

## 10. Known Vivado UVM Limitations

### What Works Well:
- Basic sequence_item, sequence, driver, monitor
- uvm_config_db for interface passing
- Simple agents and environments
- Basic reporting (UVM_INFO, UVM_WARNING, UVM_ERROR)

### What to Avoid:
- Complex factory overrides
- Deep analysis port hierarchies
- uvm_reg package (register abstraction)
- Some advanced TLM features
- Excessive use of uvm_callbacks

### Workarounds:
- Use simple queues instead of TLM FIFOs
- Direct function calls instead of complex analysis ports
- Manual configuration instead of heavy factory usage
- Simple inheritance instead of callbacks

---

## 11. Debugging Tips

### Enable UVM Debug
```bash
xsim tb_top -testplusarg UVM_VERBOSITY=UVM_HIGH
```

### Check Interface Connection
```systemverilog
initial begin
  if (!uvm_config_db#(virtual tl_if)::get(this, "", "vif", vif))
    `uvm_fatal("NO_VIF", "Virtual interface not set!")
end
```

### Add Waveforms
```tcl
log_wave -recursive /tb_top/*
```

---

## 12. File Structure

```
tl/verification/
├── README.md                    # This verification plan
├── tl_if.sv                     # Interface (to be created)
├── tl_uvm_pkg.sv               # UVM package (to be created)
├── tb_top.sv                    # Testbench top (to be created)
└── sequences/                   # (future)
    ├── tl_base_seq.sv
    ├── tl_single_write_seq.sv
    └── tl_random_seq.sv
```

---

## Summary

This plan focuses on:
- ✅ **Simple** - Core UVM features only
- ✅ **Vivado-compatible** - Tested UVM subset
- ✅ **Practical** - 14 test cases covering key functionality
- ✅ **Achievable** - Can be implemented incrementally

**Next Step:** Create the interface file (`tl_if.sv`) and basic transaction class.

---

**Version:** 1.0  
**Date:** November 17, 2025  
**Status:** Ready for implementation
