`ifndef TL_CMD_SEQ_ITEM_SV
`define TL_CMD_SEQ_ITEM_SV

class tl_cmd_seq_item extends uvm_sequence_item;
  
  //------------------------------------------------------------------
  // Command Fields (match tl_cmd_t)
  //------------------------------------------------------------------
  
  rand tl_pkg::tl_cmd_type_e trans_type;  // CMD_MEM, CMD_CFG, CMD_CPL
  rand bit [9:0]             length_dw;   // Length in DWs (1-1024)
  rand bit                   is_write;    // 1=Write, 0=Read (wr_en)
  rand bit [3:0]             first_be;    // First DW Byte Enable
  
  // Memory transaction fields
  rand bit [63:0]            addr;        // 64-bit byte address
  
  // Config transaction fields  
  rand bit [7:0]             cfg_bus;
  rand bit [4:0]             cfg_device;
  rand bit [2:0]             cfg_function;
  rand bit [9:0]             cfg_reg_num;
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  
  // Transaction type distribution
  constraint c_trans_type {
    trans_type dist {
      tl_pkg::CMD_MEM := 80,  // 80% memory
      tl_pkg::CMD_CFG := 20   // 20% config
    };
  }
  
  // Length constraints
  constraint c_length {
    // Config transactions are always 1 DW
    if (trans_type == tl_pkg::CMD_CFG) {
      length_dw == 1;
    }
    
    // Memory can be variable
    if (trans_type == tl_pkg::CMD_MEM) {
      length_dw dist {
        1       := 30,      // 30% single DW
        [2:4]   := 40,      // 40% small bursts
        [5:8]   := 20,      // 20% medium bursts
        [9:16]  := 10       // 10% large bursts
      };
    }
  }
  
  // Memory address constraints
  constraint c_mem_addr {
    if (trans_type == tl_pkg::CMD_MEM) {
      // Mostly aligned, some unaligned for testing
      addr[1:0] dist {
        2'b00 := 70,  // 70% DW-aligned
        2'b01 := 10,  // 10% byte+1
        2'b10 := 10,  // 10% byte+2
        2'b11 := 10   // 10% byte+3
      };
      
      // Reasonable address range
      addr[63:32] dist {
        [32'h0000_00FF : 32'h0000_0001] := 10,
        32'h0000_0000 := 90
      }; 
      addr[31:0] inside {[32'h0000_0000 : 32'hFFFF_FFFF]};
    }
  }
  
  // First DW Byte Enable
  constraint c_first_be {
    first_be != 4'b0000;  // At least one byte must be valid
    
    // For aligned addresses, all bytes typically valid
    if (trans_type == tl_pkg::CMD_MEM && addr[1:0] == 2'b00) {
      first_be == 4'b1111;
    }
    
    // For unaligned, mask based on offset
    if (trans_type == tl_pkg::CMD_MEM && addr[1:0] == 2'b01) {
      first_be == 4'b1110;
    }
    if (trans_type == tl_pkg::CMD_MEM && addr[1:0] == 2'b10) {
      first_be == 4'b1100;
    }
    if (trans_type == tl_pkg::CMD_MEM && addr[1:0] == 2'b11) {
      first_be == 4'b1000;
    }
    
    // Config: typically all bytes valid
    if (trans_type == tl_pkg::CMD_CFG) {
      first_be == 4'b1111;
    }
  }
  
  // Config BDF constraints
  constraint c_cfg_bdf {
    if (trans_type == tl_pkg::CMD_CFG) {
      cfg_bus inside {[0:15]};      // Limited bus range
      cfg_device inside {[0:31]};   // Valid device numbers
      cfg_function inside {[0:7]};  // Valid function numbers
      cfg_reg_num inside {[0:255]}; // Config space registers
      cfg_reg_num[1:0] == 2'b00;    // DW-aligned
    }
  }
  
  //------------------------------------------------------------------
  // UVM Automation Macros
  //------------------------------------------------------------------
  
  `uvm_object_utils_begin(tl_cmd_seq_item)
    `uvm_field_enum(tl_pkg::tl_cmd_type_e, trans_type, UVM_ALL_ON)
    `uvm_field_int(length_dw,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(is_write,     UVM_ALL_ON)
    `uvm_field_int(first_be,     UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(addr,         UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(cfg_bus,      UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(cfg_device,   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(cfg_function, UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(cfg_reg_num,  UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  
  function new(string name = "tl_cmd_seq_item");
    super.new(name);
  endfunction
  
  //------------------------------------------------------------------
  // Convert to tl_cmd_t (for driving DUT)
  //------------------------------------------------------------------
  
  function tl_pkg::tl_cmd_t to_tl_cmd();
    tl_pkg::tl_cmd_t cmd;
    
    cmd.type         = trans_type;
    cmd.len          = length_dw;
    cmd.wr_en        = is_write;
    cmd.be           = first_be;
    
    if (trans_type == tl_pkg::CMD_MEM) begin
      cmd.addr = addr;
    end
    else if (trans_type == tl_pkg::CMD_CFG) begin
      cmd.bus          = cfg_bus;
      cmd.device       = cfg_device;
      cmd.function_num = cfg_function;
      cmd.reg_num      = cfg_reg_num;
    end
    
    return cmd;
  endfunction
  
  //------------------------------------------------------------------
  // Utility: Create specific transaction types
  //------------------------------------------------------------------
  
  // Memory Write
  function void set_mem_write(bit [63:0] addr_val, int len_val);
    trans_type = tl_pkg::CMD_MEM;
    is_write   = 1'b1;
    addr       = addr_val;
    length_dw  = len_val;
    first_be   = 4'b1111;  // Default to all bytes
  endfunction
  
  // Memory Read
  function void set_mem_read(bit [63:0] addr_val, int len_val);
    trans_type = tl_pkg::CMD_MEM;
    is_write   = 1'b0;
    addr       = addr_val;
    length_dw  = len_val;
    first_be   = 4'b1111;
  endfunction
  
  // Config Write
  function void set_cfg_write(bit [7:0] bus, bit [4:0] dev, bit [2:0] func, bit [9:0] reg_num);
    trans_type   = tl_pkg::CMD_CFG;
    is_write     = 1'b1;
    cfg_bus      = bus;
    cfg_device   = dev;
    cfg_function = func;
    cfg_reg_num  = reg_num;
    length_dw    = 10'd1;
    first_be     = 4'b1111;
  endfunction
  
  // Config Read
  function void set_cfg_read(bit [7:0] bus, bit [4:0] dev, bit [2:0] func, bit [9:0] reg_num);
    trans_type   = tl_pkg::CMD_CFG;
    is_write     = 1'b0;
    cfg_bus      = bus;
    cfg_device   = dev;
    cfg_function = func;
    cfg_reg_num  = reg_num;
    length_dw    = 10'd1;
    first_be     = 4'b1111;
  endfunction

endclass : tl_cmd_seq_item

`endif // TL_CMD_SEQ_ITEM_SV