module tl_cpl_engine 
import tl_pkg::*;
#(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  input  cpl_rx_t        cpl_i,
  input  logic                   cpl_valid_i,
  output logic                   cpl_ready_o,

  output logic [TAG_W-1:0]       lookup_tag_o,
  output logic                   lookup_valid_o,
  input  logic                   lookup_ready_i,
  
  input  logic [15:0]            lookup_req_id_i,   
  input  logic [63:0]            lookup_addr_i,     
  input  logic [9:0]             lookup_len_i,      
  input  logic [2:0]             lookup_attr_i,    
  input  logic [2:0]             lookup_fmt_i,      
  input  logic [4:0]             lookup_pkt_type_i, 
  input  logic [3:0]             lookup_first_be_i,
  input  logic [3:0]             lookup_last_be_i,

  input  logic [7:0]             lookup_bus_number_i,
  input  logic [4:0]             lookup_device_number_i,
  input  logic [2:0]             lookup_function_number_i,

  // Tag Table free interface
  output logic [TAG_W-1:0]       free_tag_o,
  output logic                   free_valid_o,
  input  logic                   free_ready_i,

  // Returned data to user application
  output logic [63:0]            usr_read_rp_addr_o,       
  output logic [9:0]             usr_read_rp_length_o,
  output logic [3:0]             usr_first_be_o,
  output logic [3:0]             usr_last_be_o,
  output logic                   usr_read_rp_valid_o,
  input  logic                   usr_read_rp_ready_i,

  output logic [127:0]           usr_rdata_o,  
  output logic                   usr_reop_o,
  output logic                   usr_rvalid_o,
  input  logic                   usr_rready_i,

  
  output logic [TAG_W-1:0]       cfg_rd_tag_o,
  output logic [31:0]            cfg_rd_data_o,
  output logic [2:0]             cfg_rd_status_o,  
  output logic [7:0]             cfg_rd_bus_number_o,
  output logic [4:0]             cfg_rd_device_number_o,
  output logic [2:0]             cfg_rd_function_number_o,
  output logic                   cfg_rd_valid_o,
  input  logic                   cfg_rd_ready_i,
  
  output logic [TAG_W-1:0]       cfg_wr_tag_o,
  output logic [2:0]             cfg_wr_status_o,  
  output logic [7:0]             cfg_wr_bus_number_o,
  output logic [4:0]             cfg_wr_device_number_o,
  output logic [2:0]             cfg_wr_function_number_o,
  output logic                   cfg_wr_valid_o,  
  input  logic                   cfg_wr_ready_i    
);

  // Completion processing state machine
  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    LOOKUP  = 3'd1,
    CHECK   = 3'd2,
    SEND_READ_HDR = 3'd3,
    SEND_READ_DATA = 3'd4,
    CFG_CPL  = 3'd5,
    ERROR   = 3'd6
  } state_t;

  state_t state, next_state;

  cpl_rx_t cpl_reg;

  logic [15:0]            lookup_req_id_reg;
  logic [63:0]            lookup_addr_reg;
  logic [9:0]             lookup_len_reg;
  logic [2:0]             lookup_attr_reg;
  logic [2:0]             lookup_fmt_reg;
  logic [4:0]             lookup_pkt_type_reg;
  logic [3:0]             lookup_first_be_reg;
  logic [3:0]             lookup_last_be_reg;
  logic [7:0]             lookup_bus_number_reg;
  logic [4:0]             lookup_device_number_reg;
  logic [2:0]             lookup_function_number_reg;



  logic [9:0] dw_count;      
  logic [9:0] total_dw;        
  logic       last_dw;       


  logic [31:0] data_buffer; 

  logic [31:0] current_dw;



  logic is_cfg_req;
  assign is_cfg_req = (lookup_pkt_type_reg == 5'b00100);

  logic is_cfg_rd_cpl;
  assign is_cfg_rd_cpl = is_cfg_req && (lookup_fmt_reg == 3'b000);
  logic is_cfg_wr_cpl;
  assign is_cfg_wr_cpl = is_cfg_req && (lookup_fmt_reg == 3'b010);

  logic [9:0] remaining_dw;
  assign remaining_dw = total_dw - dw_count;
  assign last_beat = (remaining_dw <= 10'd4);

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state <= IDLE;
    end
    else begin
      state <= next_state;
    end
  end


  always_comb begin
    next_state = state;
      case (state)
        IDLE: begin
          if(cpl_valid_i) begin
            next_state = LOOKUP;
          end
          else begin
            next_state = IDLE;
          end
        end
        LOOKUP: begin
          if (lookup_ready_i) begin 
            next_state = CHECK;
          end
        end
        CHECK: begin
          if(lookup_req_id_reg == cpl_reg.requester_id && cpl_reg.status == CPL_SUCCESS) begin
            if(is_cfg_req) begin
              next_state = CFG_CPL;  
            end
            else begin
              if(cpl_reg.lower_addr == lookup_addr_reg[6:0]) begin
                next_state = SEND_READ_HDR;
              end
              else begin
                next_state = ERROR;
              end
            end
          end
          else begin
            next_state = ERROR;
          end
        end
        SEND_READ_HDR: begin
          if(usr_read_rp_ready_i && usr_read_rp_valid_o) begin
            next_state = SEND_READ_DATA;
          end
          else begin
            next_state = SEND_READ_HDR;
          end
        end
        SEND_READ_DATA: begin
          if(last_beat && usr_rvalid_o && usr_rready_i) begin
            next_state = IDLE;
          end
          else begin
            next_state = SEND_READ_DATA;
          end
        end
        CFG_CPL: begin
          if (is_cfg_rd_cpl && cfg_rd_ready_i) begin
            next_state = IDLE;
          end
          else if (is_cfg_wr_cpl && cfg_wr_ready_i) begin
            next_state = IDLE;
          end
          else begin
            next_state = CFG_CPL;
          end
        end
        ERROR: begin
          next_state = IDLE;
        end
        default: begin
          next_state = IDLE;
        end
      endcase
  end

  always_comb begin
    cpl_ready_o = 1'b0;
    case (state)
      IDLE: begin
        cpl_ready_o = 1'b1;
      end
      SEND_READ_DATA: begin
        cpl_ready_o = usr_rready_i && (remaining_dw > 1);
      end
      default: begin
        cpl_ready_o = 1'b0;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      cpl_reg <= '0;
    end
    else begin
      if(state == IDLE && next_state == LOOKUP) begin
        cpl_reg <= cpl_i;
      end
    end
  end

  always_comb begin
    if(state == LOOKUP) begin
      lookup_tag_o   = cpl_reg.tag;
      lookup_valid_o = 1'b1;
    end
    else begin
      lookup_tag_o   = '0;
      lookup_valid_o = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      lookup_req_id_reg   <= '0;
      lookup_addr_reg     <= '0;
      lookup_len_reg      <= '0;
      lookup_attr_reg     <= '0;
      lookup_fmt_reg      <= '0;
      lookup_pkt_type_reg <= '0;
      lookup_first_be_reg <= '0;
      lookup_last_be_reg  <= '0;
      lookup_bus_number_reg     <= '0;
      lookup_device_number_reg  <= '0;
      lookup_function_number_reg<= '0;
    end
    else if(state == LOOKUP && next_state == CHECK) begin
      lookup_req_id_reg   <= lookup_req_id_i;
      lookup_addr_reg     <= lookup_addr_i;
      lookup_len_reg      <= lookup_len_i;
      lookup_attr_reg     <= lookup_attr_i;
      lookup_fmt_reg      <= lookup_fmt_i;
      lookup_pkt_type_reg <= lookup_pkt_type_i;
      lookup_first_be_reg <= lookup_first_be_i;
      lookup_last_be_reg  <= lookup_last_be_i;
      lookup_bus_number_reg     <= lookup_bus_number_i;
      lookup_device_number_reg  <= lookup_device_number_i;
      lookup_function_number_reg<= lookup_function_number_i;
    end
  end


  always_comb begin
    usr_read_rp_addr_o = lookup_addr_reg;
    usr_read_rp_length_o = lookup_len_reg;
    usr_first_be_o    = lookup_first_be_reg;
    usr_last_be_o     = lookup_last_be_reg;
    usr_read_rp_valid_o = (state == SEND_READ_HDR) && (usr_read_rp_ready_i);
  end


always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      dw_count     <= '0;
      total_dw     <= '0;
      data_buffer  <= '0;
    end
    else begin
      case (state)
        CHECK: begin
          if(lookup_req_id_reg == cpl_reg.requester_id && cpl_reg.status == CPL_SUCCESS && !is_cfg_req) begin
            total_dw     <= lookup_len_reg;
            dw_count     <= '0;
            data_buffer  <= cpl_reg.data[31:0];
          end
        end
        
        SEND_READ_DATA: begin
          if(usr_rvalid_o && usr_rready_i) begin
            if(!last_beat) begin
              data_buffer <= cpl_i.data[127:96];
              dw_count <= dw_count + 10'd4;
            end
            else begin
              dw_count <= total_dw;
              data_buffer <= 32'b0;
            end
          end
        end
        default: begin
          dw_count     <= dw_count;
          total_dw     <= total_dw;
          data_buffer  <= data_buffer;
        end
      endcase
    end
  end



  always_comb begin
    case (remaining_dw)
      10'd1: begin
        usr_rdata_o = {96'b0, data_buffer[31:0]};
      end
      10'd2: begin
        usr_rdata_o = {64'b0, cpl_i.data[31:0], data_buffer[31:0]};
      end
      10'd3: begin
        usr_rdata_o = {32'b0, cpl_i.data[63:0], data_buffer[31:0]};
      end
      default: begin
        usr_rdata_o = {cpl_i.data[95:0], data_buffer[31:0]};
      end
    endcase
    usr_reop_o   = last_beat;
    if(state == SEND_READ_DATA && remaining_dw > 1) begin
      usr_rvalid_o = usr_rready_i && cpl_valid_i;  
    end
    else if(state == SEND_READ_DATA && remaining_dw == 1) begin
      usr_rvalid_o = usr_rready_i;  
    end
    else begin
      usr_rvalid_o = 1'b0;
    end
  end





  assign cfg_rd_tag_o    = cpl_reg.tag;
  assign cfg_rd_data_o   = cpl_reg.data[31:0];
  assign cfg_rd_status_o = cpl_reg.status;
  assign cfg_rd_bus_number_o     = lookup_bus_number_reg;
  assign cfg_rd_device_number_o  = lookup_device_number_reg;
  assign cfg_rd_function_number_o= lookup_function_number_reg;
  assign cfg_rd_valid_o  = (state == CFG_CPL) && (is_cfg_rd_cpl);

  assign cfg_wr_tag_o    = cpl_reg.tag;
  assign cfg_wr_status_o = cpl_reg.status;
  assign cfg_wr_bus_number_o     = lookup_bus_number_reg;
  assign cfg_wr_device_number_o  = lookup_device_number_reg;
  assign cfg_wr_function_number_o= lookup_function_number_reg;
  assign cfg_wr_valid_o  = (state == CFG_CPL) && (is_cfg_wr_cpl);


  assign free_tag_o   = cpl_reg.tag;
  assign free_valid_o = (((state == SEND_READ_DATA) && last_beat && usr_rvalid_o && usr_rready_i) ||
                        ((state == CFG_CPL) && cfg_rd_valid_o && cfg_rd_ready_i) ||
                        ((state == CFG_CPL) && cfg_wr_valid_o && cfg_wr_ready_i)) && free_ready_i;
endmodule
