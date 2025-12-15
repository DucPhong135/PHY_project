class rx_memory_seq extends uvm_sequence #(tl_tlp_seq_item);
    `uvm_object_utils(rx_memory_seq);
 
    // Parameters
    int unsigned num_transactions = 1;
    rand bit [31:0] default_addr;
 
    // Constructor
    function new(string name = "rx_memory_seq");
        super.new(name);
        num_transactions = 10;
        default_addr = 32'h0000_0000;
    endfunction : new
 
    // Body task
    virtual task body();
        int offset = 0;
        void'(std::randomize(default_addr) with {
            default_addr[1:0] == 2'b00;  // DW aligned
            default_addr < 32'h1000_0000;
        });
        `uvm_info("RX_MEM_SEQ", $sformatf("Default Address for RX Memory Seq: 0x%0h", default_addr), UVM_LOW);
        `uvm_info("RX_MEM_SEQ", "Start testing for 4DW request type", UVM_LOW);
        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset);
                length inside {4, 8};
            })
            offset += 64; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 5;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 5;
            })
            
            offset += 32;
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 6;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 6;
            })

            offset += 32;
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 7;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 7;
            })

            offset += 32; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 1);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 1);
                length inside {4, 8};
            })
            offset += 64; // Increment address for next transaction

            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 2);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 2);
                length inside {4, 8};
            })

            offset += 64; // Increment address for next transaction

            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 3);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 3);
                length inside {4, 8};
            })

            offset += 64; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 1);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 1);
                length inside {[1:3]};
            })
            offset += 64;

            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 2);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 2);
                length inside {[1:3]};
            })
            offset += 64;

            `uvm_do_with(req, {
                fmt == 3'b011; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 3);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b001; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 3);
                length inside {[1:3]};
            })
            offset += 64;
        end

        `uvm_info("RX_MEM_SEQ", "Start testing for 3DW request type", UVM_LOW);
        void '(std::randomize(default_addr) with {
            default_addr[1:0] == 2'b00;  // DW aligned
            default_addr > 32'h1000_0000;
            default_addr < 32'h2000_0000;
        });

        `uvm_info("RX_MEM_SEQ", $sformatf("Default Address for RX Memory Seq: 0x%0h", default_addr), UVM_LOW);

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset);
                length inside {4, 8};
            })
            offset += 64; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 5;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 5;
            })
            
            offset += 32;
            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 6;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 6;
            })

            offset += 32;
            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 7;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset);
                length == 7;
            })

            offset += 32; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 1);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 1);
                length inside {4, 8};
            })
            offset += 64; // Increment address for next transaction

            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 2);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 2);
                length inside {4, 8};
            })

            offset += 64; // Increment address for next transaction

            `uvm_do_with(req, {
                fmt == 3'b010; // 3DW Header with data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 3);
                length == 8;
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 3DW Header without data
                pkt_type == 5'b00000; // Memory Request Type
                address == (default_addr + offset + 3);
                length inside {4, 8};
            })

            offset += 64; // Increment address for next transaction
        end

        repeat (num_transactions) begin
            `uvm_do_with(req, {
                fmt == 3'b010; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 1);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 1);
                length inside {[1:3]};
            })
            offset += 64;

            `uvm_do_with(req, {
                fmt == 3'b010; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 2);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 2);
                length inside {[1:3]};
            })
            offset += 64;

            `uvm_do_with(req, {
                fmt == 3'b010; // 4DW Header with data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 3);
                length inside {[5:7]};
            })

            `uvm_do_with(req, {
                fmt == 3'b000; // 4DW Header without data
                pkt_type == 5'b00000;
                address == (default_addr + offset + 3);
                length inside {[1:3]};
            })
            offset += 64;
        end
    endtask : body

endclass : rx_memory_seq