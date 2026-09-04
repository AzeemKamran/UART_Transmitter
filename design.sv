module transmitter (
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_start,
    input  logic [7:0] data_in,

    output logic       tx,
    output logic       busy
);

  typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
  } state_t;

  state_t state;

  logic [7:0] data_reg;
  logic [12:0] count;
  logic [2:0] index;


  always_ff @(posedge clk) begin

    if (reset) begin

      state    <= IDLE;
      data_reg <= 8'd0;
      count    <= 13'd0;
      index    <= 3'd0;
      tx       <= 1'b1;
      busy     <= 1'b0;

    end

    else begin

      case (state)

       
        IDLE: begin

          tx   <= 1'b1;
          busy <= 1'b0;
          count <= 13'd0;
          index <= 3'd0;

          if (tx_start) begin

            data_reg <= data_in;
            busy     <= 1'b1;
            state    <= START;
            tx       <= 1'b0;
            count    <= 13'd0;

          end

        end


      
        START: begin

          tx <= 1'b0;

          if (count == 13'd5207) begin

            count <= 13'd0;
            index <= 3'd0;
            state <= DATA;

          end

          else begin
            count <= count + 1'b1;
          end

        end


      
        DATA: begin

          tx <= data_reg[index];

          if (count == 13'd5207) begin

            count <= 13'd0;

            if (index == 3'd7) begin

              state <= STOP;

            end

            else begin

              index <= index + 1'b1;

            end

          end

          else begin
            count <= count + 1'b1;
          end

        end


        
        STOP: begin

          tx <= 1'b1;

          if (count == 13'd5207) begin

            count <= 13'd0;
            busy  <= 1'b0;
            state <= IDLE;

          end

          else begin
            count <= count + 1'b1;
          end

        end


        default: begin

          state <= IDLE;
          tx    <= 1'b1;
          busy  <= 1'b0;
          count <= 13'd0;
          index <= 3'd0;

        end

      endcase

    end

  end

endmodule