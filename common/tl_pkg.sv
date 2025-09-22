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

  //----------------------------------------------------------------
  // User-bus command channel (example: AXI-Lite-like)
  //----------------------------------------------------------------
  typedef struct packed {
    logic [63:0] addr;   // byte address
    logic [9:0]  len;    // in DW (1-1024)
    logic        wr_en;  // 1 = write, 0 = read
    logic [3:0]  be;     // byte enable
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

endpackage : tl_pkg
