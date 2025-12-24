class mem_storage;
  
  byte mem[bit[63:0]];
  
  function void write(bit[63:0] addr, bit[127:0] data, bit[15:0] be);
    for (int i = 0; i < 16; i++) begin
      if (be[i]) begin
        mem[addr + i] = data[i*8 +: 8];
      end
    end
  endfunction
  
  function bit[127:0] read(bit[63:0] addr, bit[15:0] be = 16'hFFFF);
    bit[127:0] result = '0;
    for (int i = 0; i < 16; i++) begin
      if (be[i]) begin
        if (mem.exists(addr + i))
          result[i*8 +: 8] = mem[addr + i];
        else
          result[i*8 +: 8] = 8'hFF;
      end
    end
    return result;
  endfunction
  

  function bit[15:0] calc_beat_be(
    int beat_num,      
    int total_dws,     
    bit[3:0] first_be, // Byte enables for first DW
    bit[3:0] last_be   // Byte enables for last DW
  );
    bit[15:0] be = 16'h0000;
    
    for (int dw = 0; dw < 4; dw++) begin 
      int abs_dw = beat_num * 4 + dw;    
      
      if (total_dws == 1) begin
        if (abs_dw == 0)
          be[dw*4 +: 4] = first_be;
        else
          be[dw*4 +: 4] = 4'b0000;
      end else begin
        if (abs_dw == 0)
          be[dw*4 +: 4] = first_be;        
        else if (abs_dw == total_dws - 1)
          be[dw*4 +: 4] = last_be;          
        else if (abs_dw < total_dws)
          be[dw*4 +: 4] = 4'b1111;         
        else
          be[dw*4 +: 4] = 4'b0000;       
      end
    end
    
    return be;
  endfunction
  
endclass