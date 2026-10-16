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
 

module receiver #(
    parameter int CLKS_PER_BIT = 5208
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,

    output logic [7:0] data_out,
    output logic       data_valid,
    output logic       frame_error
);

  typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
  } state_t;

  state_t state;

  logic [7:0]  shift_reg;
  logic [12:0] count;
  logic [2:0]  index;

  // rx comes from outside the clock domain, so pass it through
  // two flops before using it
  logic rx_meta;
  logic rx_sync;

  always_ff @(posedge clk) begin
    if (reset) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
    end
    else begin
      rx_meta <= rx;
      rx_sync <= rx_meta;
    end
  end


  always_ff @(posedge clk) begin

    if (reset) begin

      state       <= IDLE;
      shift_reg   <= 8'd0;
      count       <= 13'd0;
      index       <= 3'd0;
      data_out    <= 8'd0;
      data_valid  <= 1'b0;
      frame_error <= 1'b0;

    end

    else begin

      // pulses go low again unless set below
      data_valid  <= 1'b0;
      frame_error <= 1'b0;

      case (state)

        IDLE: begin

          count <= 13'd0;
          index <= 3'd0;

          if (rx_sync == 1'b0) begin
            state <= START;
          end

        end


        START: begin

          if (count == (CLKS_PER_BIT / 2) - 1) begin

            count <= 13'd0;

            if (rx_sync == 1'b0) begin
              state <= DATA;      // real start bit
            end
            else begin
              state <= IDLE;      // it was just a glitch
            end

          end

          else begin
            count <= count + 1'b1;
          end

        end


        DATA: begin

          if (count == CLKS_PER_BIT - 1) begin

            count <= 13'd0;
            shift_reg[index] <= rx_sync;

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

          if (count == CLKS_PER_BIT - 1) begin

            count <= 13'd0;
            state <= IDLE;

            if (rx_sync == 1'b1) begin
              data_out   <= shift_reg;
              data_valid <= 1'b1;
            end
            else begin
              frame_error <= 1'b1;
            end

          end

          else begin
            count <= count + 1'b1;
          end

        end


        default: begin
          state <= IDLE;
        end

      endcase

    end

  end

endmodule
