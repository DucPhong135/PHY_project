package tl_pkg;

  //----------------------------------------------------------------
  // Link-side streaming record (to / from DLL)
  //----------------------------------------------------------------
  typedef struct packed {
    logic [127:0] data;   // 128-bit TLP/DLLP payload
    logic         sop;    // start-of-packet
    logic         eop;    // end-of-packet
    logic  [3:0]  be;     // byte-enable for final DW (optional)
    logic         is_dllp;// 1 = DLLP, 0 = TLP
  } tl_stream_t;


  typedef struct packed {
    logic [1:0]  hdr_dw;    // 3 or 4 DW
    logic [11:0] data_dw;   // payload length in DW
    logic        has_data;  // 1 = TLP has data
  } tl_meta_t;



  //----------------------------------------------------------------
  // User-bus command channel (example: AXI-Lite-like)
  //----------------------------------------------------------------
typedef enum logic [1:0] {
  CMD_MEM  = 2'b00,  // Memory Read/Write
  CMD_CFG  = 2'b01,  // Config Read/Write (Type 0)
  CMD_CPL  = 2'b10   // Completion (separate struct usually, but reserved here)
} tl_cmd_type_e;

typedef struct packed {
  // Transaction type
  tl_cmd_type_e type;    

  // Common fields
  logic [9:0]  len;       // Length in DWs (1–1024)
  logic        wr_en;     // 1 = Write, 0 = Read
  logic [3:0]  be;        // Byte enables (FirstDWBE/LastDWBE)

  // Memory-specific
  logic [63:0] addr;      // Byte address (used if type = CMD_MEM)

  // Config-specific (BDF + register number)
  logic [7:0]  bus;       // Bus Number
  logic [4:0]  device;    // Device Number
  logic [2:0]  function_num;  // Function Number
  logic [9:0]  reg_num;   // Config register number (DWORD aligned)
} tl_cmd_t;


  //----------------------------------------------------------------
  // User-bus data channel
  //----------------------------------------------------------------
  typedef struct packed {
    logic [127:0] data;  // write data or read response
    logic         last;  // end-of-burst
  } tl_data_t;

  //----------------------------------------------------------------
  // Flow-control credit vector (PH/PD/NPH/NPD/CPLH/CPLD)
  //----------------------------------------------------------------
  typedef struct packed {
    logic [11:0] ph;
    logic [11:0] pd;
    logic [7:0]  nph;
    logic [11:0] npd;
    logic [7:0]  cplh;
    logic [11:0] cpld;
  } tl_credit_t;

  //----------------------------------------------------------------
  // Completion command (for completion generation)
  //----------------------------------------------------------------
  localparam int TAG_W = 8; // Default tag width if not overridden
typedef enum logic [2:0] {
  CPL_SUCCESS = 3'd0, // Successful Completion
  CPL_UR      = 3'd1, // Unsupported Request
  CPL_CA      = 3'd2  // Configuration Accessed
} tl_cpl_status_e;

typedef struct packed {
  logic [15:0] requester_id;
  logic [TAG_W-1:0] tag;
  logic [11:0] byte_count;
  logic [6:0]  lower_addr;
  tl_cpl_status_e  cpl_status; // SC=0, UR=1, CA=2
  logic        has_data;   // 1 = CplD, 0 = Cpl
  logic [255:0] data;      // completion payload (optional)
} cpl_gen_cmd_t;



endpackage : tl_pkg
