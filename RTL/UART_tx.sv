module transmitter(
  input logic clk,
  input logic [7:0]data_in,
  input logic reset,
  input tx_start,
  output busy,
  output tx
);
  logic [12:0] count;
  logic [2:0] index;
  typedef enum {idle , start, data, stop} state_t;
  state_t state;
  logic [7:0] data_reg;
  always @(posedge clk) begin
    
    if(reset) begin
      count <= 0;
      index <= 0;
      state <= idle;
      tx <= 1;
    end
    else begin
      if (state != idle)
          count <= count + 1;

      if(state == idle && tx_start) begin
        state <= start;
        data_reg <= data_in;
        busy <= 1;
      end


      if(state == idle)
        tx <= 1;

      if(state == start && count < 5207)
        tx <= 0;
      if(state == start && count == 5207) begin
        state <= data;
        count <= 0;
      end

      if(state == data)
        tx <= data_reg[index];

      if(state == data && count == 5207) begin
        count <= 0;
               if(index == 7) begin
                index <= 0;
                state <= stop;
              end
              else
                index <= index+1;
              end
      end

      if(state == stop) begin
        tx <= 1;
        
        if(count == 5207) begin
          count <= 0;
          state <= idle;
          busy <= 0;
        end
      end
  end
  
endmodule