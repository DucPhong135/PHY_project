import tl_pkg::*;      // bring in the typedefs

module tl_top #(
  parameter int TAG_W = 8,
  parameter int DEPTH = 256,
  parameter int FIFO_DEPTH = 32
)(
  // --- Clocks / Reset
  input  logic       clk,
  input  logic       rst_n,

  // --- DLL Side (to/from Data Link Layer)
  output tl_stream_t tl_tx_o,
  output logic       tl_tx_valid_o,
  input  logic       tl_tx_ready_i,

  input  tl_stream_t tl_rx_i,
  input  logic       tl_rx_valid_i,
  output logic       tl_rx_ready_o,

  input  tl_credit_t fc_update_i,
  input  logic       fc_valid_i,

  // --- User Side (application interface)
  input  tl_cmd_t    usr_cmd_i,
  input  logic       usr_cmd_valid_i,
  output logic       usr_cmd_ready_o,

  input  logic [127:0]  usr_wdata_i,
  input  logic       usr_wvalid_i,
  output logic       usr_wready_o,

  // Read response interface
  output logic [63:0]            usr_read_rp_addr_o,
  output logic [9:0]             usr_read_rp_length_o,
  output logic [3:0]             usr_first_be_o,
  output logic [3:0]             usr_last_be_o,
  output logic                   usr_read_rp_valid_o,
  input  logic                   usr_read_rp_ready_i,

  output logic [127:0]         usr_rdata_o,
  output logic                usr_reop_o,
  output logic                usr_rvalid_o,
  input  logic                usr_rready_i,


  // Config Read Completion (For verification purposes)
  output logic [TAG_W-1:0]       cfg_rd_tag_o,     // Tag of config read request
  output logic [31:0]            cfg_rd_data_o,    // Config read data (1 DW)
  output logic [2:0]             cfg_rd_status_o,  // Completion status
  output logic [7:0]             cfg_rd_bus_number_o,
  output logic [4:0]             cfg_rd_device_number_o,
  output logic [2:0]             cfg_rd_function_number_o,
  output logic                   cfg_rd_valid_o,   // Config read completion valid
  input  logic                   cfg_rd_ready_i,   // Config read completion ready
  
  // Config Write  (For verification purposes)
  output logic [TAG_W-1:0]       cfg_wr_tag_o,     // Tag of config write request
  output logic [2:0]             cfg_wr_status_o,  // Completion status
  output logic [7:0]             cfg_wr_bus_number_o,
  output logic [4:0]             cfg_wr_device_number_o,
  output logic [2:0]             cfg_wr_function_number_o,
  output logic                   cfg_wr_valid_o,   // Config write completion valid
  input  logic                   cfg_wr_ready_i,    // Config write completion ready

  // --- Memory Write Request Channel (for incoming MWr from EP)
  output memrq_t           memwr_req_o,       // Write request: addr, length, first_be, last_be
  output logic             memwr_req_valid_o, // Write request valid
  input  logic             memwr_req_ready_i, // Write request accepted

  // --- Memory Write Data Channel (for incoming MWr from EP)
  output logic [127:0]     memwr_data_o,        // Write data (128-bit per beat)
  output logic             memwr_data_valid_o,  // Write data valid
  input  logic             memwr_data_ready_i,  // Write data ready

  // --- Memory Read Request Channel (for incoming MRd from EP)
  output memrq_t           memrd_req_o,       // Read request: addr, length, first_be, last_be
  output logic             memrd_req_valid_o, // Read request valid
  input  logic             memrd_req_ready_i, // Read request accepted

  // --- Memory Read Data Channel (data returned from memory for MRd)
  input  logic [127:0]     memrd_data_i,        // Read data (128-bit per beat)
  input  logic             memrd_data_valid_i,  // Read data valid
  output logic             memrd_data_ready_o   // Ready to accept read data
);


  // -----------------------------------------------------------------
  // Internal Wires - Header Generator
  // -----------------------------------------------------------------
  logic [127:0]         hdr;
  logic                 hdr_valid, hdr_ready;
  logic                 is_posted, is_np, is_cpl;

  // -----------------------------------------------------------------
  // Internal Wires - Tag Table
  // -----------------------------------------------------------------
  logic [TAG_W-1:0]     alloc_tag;
  logic                 alloc_gnt;
  logic                 alloc_req;
  logic [63:0]          alloc_addr;
  logic [9:0]           alloc_len;
  logic [2:0]           alloc_attr;
  logic [4:0]           alloc_pkt_type;
  logic [2:0]           alloc_fmt;
  logic [3:0]           alloc_first_be;
  logic [3:0]           alloc_last_be;
  logic [7:0]           alloc_bus_number;
  logic [4:0]           alloc_device_number;
  logic [2:0]           alloc_function_number;

  logic [TAG_W-1:0]     lookup_tag;
  logic                 lookup_valid;
  logic                 lookup_ready;
  logic [15:0]          lookup_req_id;
  logic [63:0]          lookup_addr;
  logic [9:0]           lookup_len;
  logic [2:0]           lookup_attr;
  logic [2:0]           lookup_fmt;
  logic [4:0]           lookup_pkt_type;
  logic [3:0]           lookup_first_be;
  logic [3:0]           lookup_last_be;
  logic [7:0]           lookup_bus_number;
  logic [4:0]           lookup_device_number;
  logic [2:0]           lookup_function_number;

  logic [TAG_W-1:0]     free_tag;
  logic                 free_valid;
  logic                 free_ready;

  // -----------------------------------------------------------------
  // Internal Wires - Payload Mux to FIFOs
  // -----------------------------------------------------------------
  tl_stream_t           pkt_from_mux;
  logic                 pkt_from_mux_valid, pkt_from_mux_ready;
  
  tl_stream_t           pkt_to_fifo_p, pkt_to_fifo_np;
  logic                 pkt_to_fifo_p_valid, pkt_to_fifo_p_ready;
  logic                 pkt_to_fifo_np_valid, pkt_to_fifo_np_ready;

  // -----------------------------------------------------------------
  // Internal Wires - FIFOs to Arbiter
  // -----------------------------------------------------------------
  tl_stream_t           pkt_posted, pkt_np, pkt_cpl;
  logic                 pkt_posted_valid, pkt_posted_ready;
  logic                 pkt_np_valid,     pkt_np_ready;
  logic                 pkt_cpl_valid,    pkt_cpl_ready;

  // -----------------------------------------------------------------
  // Internal Wires - Completion Generator to FIFO
  // -----------------------------------------------------------------
  tl_stream_t           cpl_gen_pkt;
  logic                 cpl_gen_valid, cpl_gen_ready;

  // -----------------------------------------------------------------
  // Internal Wires - Credit Manager
  // -----------------------------------------------------------------
  logic                 ph_credit_ok, pd_credit_ok;
  logic                 nph_credit_ok, npd_credit_ok;
  logic                 cplh_credit_ok, cpld_credit_ok;

  logic                 ph_consume_v, pd_consume_v;
  logic                 nph_consume_v, npd_consume_v;
  logic                 cplh_consume_v, cpld_consume_v;
  logic [9:0]           ph_consume_dw, pd_consume_dw;
  logic [9:0]           nph_consume_dw, npd_consume_dw;
  logic [9:0]           cplh_consume_dw, cpld_consume_dw;

  // -----------------------------------------------------------------
  // Internal Wires - RX Parser
  // -----------------------------------------------------------------
  memrq_t               memwr_req;
  logic                 memwr_req_valid, memwr_req_ready;
  logic [127:0]         memwr_data;
  logic                 memwr_data_valid, memwr_data_ready;

  cpl_rx_t              cpl_pkt;
  logic                 cpl_valid, cpl_ready;

  cfg_req_t             cfg_req;
  logic                 cfg_req_valid, cfg_req_ready;

  cpl_gen_cmd_t         cpl_gen_cmd;
  logic                 cpl_gen_cmd_valid, cpl_gen_cmd_ready;


  // -----------------------------------------------------------------
  // Internal Wires - Config Space
  // -----------------------------------------------------------------
  logic [15:0]          requester_id;
  logic                 cfg_rd_en, cfg_wr_en;
  logic [9:0]           cfg_addr_dw;
  logic [31:0]          cfg_wdata, cfg_rdata;
  logic [3:0]           cfg_be;

  // -----------------------------------------------------------------
  // Sub-block Instances
  // -----------------------------------------------------------------

  // Tag Table - Manages outstanding read request tags
  tl_tag_table #(
    .TAG_W(TAG_W),
    .DEPTH(DEPTH)
  ) u_tag_table (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Allocation interface (from header generator)
    .alloc_req_i      (alloc_req),
    .alloc_req_id_i   (requester_id),  // Use requester_id from cfg_space
    .alloc_addr_i     (alloc_addr),
    .alloc_len_i      (alloc_len),
    .alloc_attr_i     (alloc_attr),
    .alloc_fmt_i      (alloc_fmt),
    .alloc_pkt_type_i (alloc_pkt_type),
    .alloc_first_be_i(alloc_first_be),
    .alloc_last_be_i (alloc_last_be),

    .alloc_bus_number_i     (alloc_bus_number),
    .alloc_device_number_i  (alloc_device_number),
    .alloc_function_number_i(alloc_function_number),

    .alloc_tag_o      (alloc_tag),
    .alloc_gnt_o      (alloc_gnt),
    
    // Lookup interface (from completion engine)
    .lookup_tag_i     (lookup_tag),
    .lookup_valid_i   (lookup_valid),
    .lookup_ready_o   (lookup_ready),
    .cpl_req_id_o     (lookup_req_id),
    .cpl_addr_o       (lookup_addr),
    .cpl_len_o        (lookup_len),
    .cpl_attr_o       (lookup_attr),
    .cpl_fmt_o        (lookup_fmt),
    .cpl_pkt_type_o   (lookup_pkt_type),
    .cpl_first_be_o   (lookup_first_be),
    .cpl_last_be_o    (lookup_last_be),

    .cpl_bus_number_o     (lookup_bus_number),
    .cpl_device_number_o  (lookup_device_number),
    .cpl_function_number_o(lookup_function_number),
    // Free interface (from completion engine)
    .free_tag_i       (free_tag),
    .free_valid_i     (free_valid),
    .free_ready_o     (free_ready)
  );

  // Header Generator - Creates TLP headers from user commands
  tl_hdr_gen #(
  ) u_hdr_gen (
    .clk              (clk),
    .rst_n            (rst_n),

    .REQUESTER_ID(requester_id),  // Configurable at runtime
    
    // User command input
    .cmd_i            (usr_cmd_i),
    .cmd_valid_i      (usr_cmd_valid_i),
    .cmd_ready_o      (usr_cmd_ready_o),
    
    // Tag allocation
    .tag_i            (alloc_tag),
    .tag_valid_i      (alloc_gnt),
    .tag_consume_o    (alloc_req),
    .tag_addr_o       (alloc_addr),
    .tag_len_o        (alloc_len),
    .tag_attr_o       (alloc_attr),
    .tag_pkt_type_o   (alloc_pkt_type),
    .tag_fmt_o        (alloc_fmt),
    .tag_first_be_o   (alloc_first_be),
    .tag_last_be_o    (alloc_last_be),

    .tag_bus_number_o     (alloc_bus_number),
    .tag_device_number_o  (alloc_device_number),
    .tag_function_number_o(alloc_function_number),
    
    // Header output
    .hdr_o            (hdr),
    .hdr_valid_o      (hdr_valid),
    .hdr_ready_i      (hdr_ready)
  );

  // Payload Mux - Combines headers with payload data
  tl_payload_mux u_payload_mux (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Write data input (updated interface)
    .wdata_i          (usr_wdata_i),
    .wdata_valid_i    (usr_wvalid_i),
    .wdata_ready_o    (usr_wready_o),
    .wdata_consumed_dw_o (),  // Not used currently
    
    // Header input
    .hdr_i            (hdr),
    .hdr_valid_i      (hdr_valid),
    .hdr_ready_o      (hdr_ready),
    
    // Packet output to TX queue router
    .tx_pkt_o         (pkt_from_mux),
    .tx_pkt_valid_o   (pkt_from_mux_valid),
    .tx_pkt_ready_i   (pkt_from_mux_ready)
  );

  // TX Queue Router - Routes packets to Posted/NP/Completion queues
  tl_tx_queue_router #(
    .QUEUE_DEPTH(FIFO_DEPTH)
  ) u_tx_queue_router (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Input from payload mux
    .pkt_i            (pkt_from_mux),
    .pkt_valid_i      (pkt_from_mux_valid),
    .pkt_ready_o      (pkt_from_mux_ready),
    
    // Output to Posted queue
    .pkt_posted_o     (pkt_to_fifo_p),
    .pkt_posted_valid_o(pkt_to_fifo_p_valid),
    .pkt_posted_ready_i(pkt_to_fifo_p_ready),
    
    // Output to Non-Posted queue
    .pkt_np_o         (pkt_to_fifo_np),
    .pkt_np_valid_o   (pkt_to_fifo_np_valid),
    .pkt_np_ready_i   (pkt_to_fifo_np_ready)
  );

  // Posted FIFO - Buffers posted packets (MWr, CfgWr)
  tl_fifo #(
    .DEPTH(FIFO_DEPTH)
  ) u_fifo_posted (
    .clk         (clk),
    .rst_n       (rst_n),

    .wr_data_i   (pkt_to_fifo_p),
    .wr_valid_i  (pkt_to_fifo_p_valid),
    .wr_ready_o  (pkt_to_fifo_p_ready),

    .rd_data_o   (pkt_posted),
    .rd_valid_o  (pkt_posted_valid),
    .rd_ready_i  (pkt_posted_ready)
  );

  // Non-Posted FIFO - Buffers non-posted packets (MRd, CfgRd)
  tl_fifo #(
    .DEPTH(FIFO_DEPTH)
  ) u_fifo_np (
    .clk         (clk),
    .rst_n       (rst_n),
    
    .wr_data_i   (pkt_to_fifo_np),
    .wr_valid_i  (pkt_to_fifo_np_valid),
    .wr_ready_o  (pkt_to_fifo_np_ready),

    .rd_data_o   (pkt_np),
    .rd_valid_o  (pkt_np_valid),
    .rd_ready_i  (pkt_np_ready)
  );

  // Completion FIFO - Buffers completion packets (Cpl/CplD)
  tl_fifo #(
    .DEPTH(FIFO_DEPTH)
  ) u_fifo_cpl (
    .clk         (clk),
    .rst_n       (rst_n),

    .wr_data_i   (cpl_gen_pkt),
    .wr_valid_i  (cpl_gen_valid),
    .wr_ready_o  (cpl_gen_ready),

    .rd_data_o   (pkt_cpl),
    .rd_valid_o  (pkt_cpl_valid),
    .rd_ready_i  (pkt_cpl_ready)
  );

  // Credit Manager - Tracks flow control credits
  tl_credit_mgr #(
    .PH_WIDTH(10),
    .PD_WIDTH(10),
    .NPH_WIDTH(10),
    .NPD_WIDTH(10),
    .CPLH_WIDTH(10),
    .CPLD_WIDTH(10)
  )
  u_credit_mgr (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Flow control updates from link partner
    .fc_update_i      (fc_update_i),
    .fc_valid_i       (fc_valid_i),
    
    // Credit consumption (from TX arbiter)
    .ph_consume_v_i   (ph_consume_v),
    .ph_consume_dw_i  (ph_consume_dw),
    .pd_consume_v_i   (pd_consume_v),
    .pd_consume_dw_i  (pd_consume_dw),
    
    .nph_consume_v_i  (nph_consume_v),
    .nph_consume_dw_i (nph_consume_dw),
    .npd_consume_v_i  (npd_consume_v),
    .npd_consume_dw_i (npd_consume_dw),
    
    .cplh_consume_v_i (cplh_consume_v),
    .cplh_consume_dw_i(cplh_consume_dw),
    .cpld_consume_v_i (cpld_consume_v),
    .cpld_consume_dw_i(cpld_consume_dw),
    
    // Credit availability outputs
    .ph_credit_ok_o   (ph_credit_ok),
    .pd_credit_ok_o   (pd_credit_ok),
    .nph_credit_ok_o  (nph_credit_ok),
    .npd_credit_ok_o  (npd_credit_ok),
    .cplh_credit_ok_o (cplh_credit_ok),
    .cpld_credit_ok_o (cpld_credit_ok)
  );

  // Completion Generator - Creates completion TLPs (for endpoint mode)
  tl_cpl_gen #(
    .TAG_W(TAG_W)
  ) u_cpl_gen (
    .clk              (clk),
    .rst_n            (rst_n),

    .requester_id_i   (requester_id),
    
    // Completion command input (from RX parser when MRd received)
    .cpl_cmd_i        (cpl_gen_cmd),
    .cpl_cmd_valid_i  (cpl_gen_cmd_valid),
    .cpl_cmd_ready_o  (cpl_gen_cmd_ready),
    
    // Credit check
    .credit_hdr_ok_i  (cplh_credit_ok),
    .credit_data_ok_i (cpld_credit_ok),

    // Memory Read Request Interface
    .memrd_rq_o       (memrd_req_o),
    .memrd_rq_valid_o (memrd_req_valid_o),
    .memrd_rq_ready_i (memrd_req_ready_i),

    // Memory Read Data Interface
    .memrd_data_i     (memrd_data_i),
    .memrd_data_valid_i(memrd_data_valid_i),
    .memrd_data_ready_o(memrd_data_ready_o),
    
    // Completion packet output
    .cpl_pkt_o        (cpl_gen_pkt),
    .cpl_pkt_valid_o  (cpl_gen_valid),
    .cpl_pkt_ready_i  (cpl_gen_ready)
  );

  // Config Space - PCIe configuration registers
  cfg_space #(
    .VENDOR_ID  (16'h1234),
    .DEVICE_ID  (16'hABCD),
    .CLASS_CODE (24'h010601),  // Bridge, PCI-to-PCI
    .REV_ID     (8'h01),
    .DEV_NUM    (5'd10),
    .FUNC_NUM   (3'd4)
  ) u_cfg_space (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Config access interface (from cfg_req decoder)
    .cfg_rd_en        (cfg_rd_en),
    .cfg_wr_en        (cfg_wr_en),
    .cfg_addr_dw      (cfg_addr_dw),
    .cfg_wdata        (cfg_wdata),
    .cfg_be           (cfg_be),
    
    // Requester ID output (used by header generator and completion generator)
    .requester_id_o   (requester_id),
    
    // Config read data output (for completion generation)
    .cfg_rdata        (cfg_rdata)
  );

  // Config Request Decoder - Converts cfg_req_t to cfg_space signals
  always_comb begin
    cfg_rd_en   = cfg_req_valid && cfg_req_ready && cfg_req.is_read;
    cfg_wr_en   = cfg_req_valid && cfg_req_ready && !cfg_req.is_read;
    cfg_addr_dw = cfg_req.reg_num;
    cfg_wdata   = cfg_req.data;
    cfg_be      = cfg_req.first_be;
  end

  // TX Arbiter - Arbitrates between Posted, Non-Posted, and Completion packets
  tl_tx_arb #(
    .PH_WIDTH(10),
    .PD_WIDTH(10),
    .NPH_WIDTH(10),
    .NPD_WIDTH(10),
    .CPLH_WIDTH(10),
    .CPLD_WIDTH(10)
  )
  u_tx_arb (
    .clk               (clk),
    .rst_n             (rst_n),
    
    // Posted packets
    .pkt_posted_i      (pkt_posted),
    .pkt_posted_valid_i(pkt_posted_valid),
    .pkt_posted_ready_o(pkt_posted_ready),
    
    // Non-Posted packets
    .pkt_np_i          (pkt_np),
    .pkt_np_valid_i    (pkt_np_valid),
    .pkt_np_ready_o    (pkt_np_ready),
    
    // Completion packets
    .pkt_cpl_i         (pkt_cpl),
    .pkt_cpl_valid_i   (pkt_cpl_valid),
    .pkt_cpl_ready_o   (pkt_cpl_ready),
    
    // Credit availability
    .ph_credit_ok_i    (ph_credit_ok),
    .pd_credit_ok_i    (pd_credit_ok),
    .nph_credit_ok_i   (nph_credit_ok),
    .npd_credit_ok_i   (npd_credit_ok),
    .cplh_credit_ok_i  (cplh_credit_ok),
    .cpld_credit_ok_i  (cpld_credit_ok),
    
    // Credit consumption outputs
    .ph_consume_v_o    (ph_consume_v),
    .ph_consume_dw_o   (ph_consume_dw),
    .pd_consume_v_o    (pd_consume_v),
    .pd_consume_dw_o   (pd_consume_dw),
    .nph_consume_v_o   (nph_consume_v),
    .nph_consume_dw_o  (nph_consume_dw),
    .npd_consume_v_o   (npd_consume_v),
    .npd_consume_dw_o  (npd_consume_dw),
    .cplh_consume_v_o  (cplh_consume_v),
    .cplh_consume_dw_o (cplh_consume_dw),
    .cpld_consume_v_o  (cpld_consume_v),
    .cpld_consume_dw_o (cpld_consume_dw),
    
    // TX output to DLL
    .tl_tx_o           (tl_tx_o),
    .tl_tx_valid_o     (tl_tx_valid_o),
    .tl_tx_ready_i     (tl_tx_ready_i)
  );

  // RX Parser - Parses incoming TLPs
  tl_rx_parser #(
    .TAG_W(TAG_W)
  ) u_rx_parser (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // RX input from DLL
    .tl_rx_i          (tl_rx_i),
    .tl_rx_valid_i    (tl_rx_valid_i),
    .tl_rx_ready_o    (tl_rx_ready_o),
    
    // Memory Write Request Interface
    .memwr_rq_o       (memwr_req_o),
    .memwr_rq_valid_o (memwr_req_valid_o),
    .memwr_rq_ready_i (memwr_req_ready_i),

    // Memory Write Data Interface
    .memwr_data_o       (memwr_data_o),
    .memwr_data_valid_o (memwr_data_valid_o),
    .memwr_data_ready_i (memwr_data_ready_i),
    
    // Completion command output (for incoming MRd - triggers cpl_gen)
    .cpl_cmd_o        (cpl_gen_cmd),
    .cpl_cmd_valid_o  (cpl_gen_cmd_valid),
    .cpl_cmd_ready_i  (cpl_gen_cmd_ready),
    
    // Completion output (active - RC receives completions from endpoints)
    .cpl_o            (cpl_pkt),
    .cpl_valid_o      (cpl_valid),
    .cpl_ready_i      (cpl_ready)
  );


  
  // Config request is NOT stubbed - it's processed by cfg_space through the decoder
  // (RC has its own config space that can be read/written by upstream devices)

  // Completion Engine - Processes received completions
  tl_cpl_engine #(
    .TAG_W(TAG_W)
  ) u_cpl_engine (
    .clk              (clk),
    .rst_n            (rst_n),
    
    // Completion input from RX parser
    .cpl_i            (cpl_pkt),
    .cpl_valid_i      (cpl_valid),
    .cpl_ready_o      (cpl_ready),
    
    // Tag table lookup
    .lookup_tag_o     (lookup_tag),
    .lookup_valid_o   (lookup_valid),
    .lookup_ready_i   (lookup_ready),
    .lookup_req_id_i  (lookup_req_id),
    .lookup_addr_i    (lookup_addr),
    .lookup_len_i     (lookup_len),
    .lookup_attr_i    (lookup_attr),
    .lookup_fmt_i     (lookup_fmt),
    .lookup_pkt_type_i(lookup_pkt_type),
    .lookup_first_be_i(lookup_first_be),
    .lookup_last_be_i (lookup_last_be),

    .lookup_bus_number_i     (lookup_bus_number),
    .lookup_device_number_i  (lookup_device_number),
    .lookup_function_number_i (lookup_function_number),

    // Tag table free
    .free_tag_o       (free_tag),
    .free_valid_o     (free_valid),
    .free_ready_i     (free_ready),
    
    // User read data output
    .usr_read_rp_addr_o (usr_read_rp_addr_o),
    .usr_read_rp_length_o (usr_read_rp_length_o),
    .usr_first_be_o    (usr_first_be_o),
    .usr_last_be_o     (usr_last_be_o),
    .usr_read_rp_valid_o (usr_read_rp_valid_o),
    .usr_read_rp_ready_i  (usr_read_rp_ready_i),


    .usr_rdata_o   (usr_rdata_o),
    .usr_reop_o    (usr_reop_o),
    .usr_rvalid_o  (usr_rvalid_o),
    .usr_rready_i  (usr_rready_i),

    .cfg_rd_tag_o     (cfg_rd_tag_o),
    .cfg_rd_data_o    (cfg_rd_data_o),
    .cfg_rd_status_o  (cfg_rd_status_o),
    .cfg_rd_bus_number_o     (cfg_rd_bus_number_o),
    .cfg_rd_device_number_o  (cfg_rd_device_number_o),
    .cfg_rd_function_number_o (cfg_rd_function_number_o),
    .cfg_rd_valid_o   (cfg_rd_valid_o),
    .cfg_rd_ready_i   (cfg_rd_ready_i),

    .cfg_wr_tag_o     (cfg_wr_tag_o),
    .cfg_wr_status_o  (cfg_wr_status_o),
    .cfg_wr_bus_number_o     (cfg_wr_bus_number_o),
    .cfg_wr_device_number_o  (cfg_wr_device_number_o),
    .cfg_wr_function_number_o (cfg_wr_function_number_o),
    .cfg_wr_valid_o   (cfg_wr_valid_o),
    .cfg_wr_ready_i   (cfg_wr_ready_i) 
  );

endmodule : tl_top
`default_nettype wire
