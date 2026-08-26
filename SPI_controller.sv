interface spi_bus;
  
  logic sclk;
  logic cs;
  logic mosi;
  logic miso;
  
   modport master (
        output sclk,
        output mosi,
        output cs,
        input  miso
    );

    modport slave (
        input  sclk,
        input  mosi,
        input  cs,
        output miso
    );
  
endinterface

module spi_master(
    spi_bus.master bus,
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic [7:0] tx_data
);

  typedef enum logic [1:0] {
    IDLE,
    TRANSFER
  } state_t;

  state_t state;

  logic [7:0] data;
  logic [2:0] index;

  always_ff @(posedge clk) begin

    if (reset) begin
      state    <= IDLE;
      data     <= 8'b0;
      index    <= 3'd7;

      bus.cs   <= 1'b1;
      bus.sclk <= 1'b0;
      bus.mosi <= 1'b0;
    end

    else begin

      case (state)

        IDLE: begin
          bus.cs   <= 1'b1;
          bus.sclk <= 1'b0;

          if (start) begin
            state    <= TRANSFER;
            data     <= tx_data;
            index    <= 3'd7;

            bus.cs   <= 1'b0;
            bus.mosi <= tx_data[7];
          end
        end

        TRANSFER: begin

          // Rising edge: slave samples current MOSI
          if (bus.sclk == 1'b0) begin
            bus.sclk <= 1'b1;
          end

          // Falling edge: prepare next bit
          else begin
            bus.sclk <= 1'b0;

            if (index == 0) begin
              state    <= IDLE;
              bus.cs   <= 1'b1;
              bus.mosi <= 1'b0;
            end
            else begin
              index    <= index - 1;
              bus.mosi <= data[index - 1];
            end
          end

        end

        default: begin
          state    <= IDLE;
          data     <= 8'b0;
          index    <= 3'd7;
          bus.cs   <= 1'b1;
          bus.sclk <= 1'b0;
          bus.mosi <= 1'b0;
        end

      endcase

    end
  end

endmodule


module spi_slave(
    spi_bus.slave bus,
    input logic reset
);

  logic [7:0] data;
  logic [2:0] index;

  always_ff @(posedge bus.sclk or posedge reset) begin

    if (reset) begin
        data  <= 8'b0;
        index <= 3'd7;
    end

    else if (!bus.cs) begin
        data[index] <= bus.mosi;

        if (index != 0)
            index <= index - 1;
    end

end

endmodule



module tb;

    logic clk;
    logic reset;
    logic start;
    logic [7:0] tx_data;

    spi_bus bus();

    spi_master master (
        .bus     (bus),
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .tx_data (tx_data)
    );

    spi_slave slave (
        .bus   (bus),
        .reset (reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        reset   = 1;
        start   = 0;
        tx_data = 8'b0;

        #20;
        reset = 0;

        #20;

        tx_data = 8'b11111111;

        start = 1;
        #10;
        start = 0;

        wait (bus.cs == 1);
        #1;

        if (slave.data == tx_data)
            $display("PASS: TX = %b, RX = %b",
                     tx_data, slave.data);
        else
            $display("FAIL: TX = %b, RX = %b",
                     tx_data, slave.data);

        $finish;

    end

endmodule