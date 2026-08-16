module tb;

    logic clk;
    logic reset;

    logic [7:0] data_in;
    logic tx_start;
    logic busy;

    logic tx;
    logic [7:0] data_out;
    logic valid;


    // --------------------------------
    // Transmitter
    // --------------------------------
    transmitter tx_inst (
        .clk      (clk),
        .data_in  (data_in),
        .reset    (reset),
        .tx_start (tx_start),
        .busy     (busy),
        .tx       (tx)
    );


    // --------------------------------
    // Receiver
    // --------------------------------
    reciever rx_inst (
        .clk      (clk),
        .rx       (tx),          // TX directly connected to RX
        .reset    (reset),
        .data_out (data_out),
        .valid    (valid)
    );


    // --------------------------------
    // 50 MHz clock
    // 20 ns period
    // --------------------------------
    always #10 clk = ~clk;


    // --------------------------------
    // Monitor
    // --------------------------------
    always @(posedge clk) begin

        if (tx_start)
            $display("TIME=%0t | START TX", $time);

        if (valid)
            $display("TIME=%0t | RECEIVED = %b",
                     $time, data_out);

    end


    // --------------------------------
    // Test
    // --------------------------------
    initial begin

        clk      = 0;
        reset    = 1;
        data_in  = 8'b10110010;
        tx_start = 0;


        // Reset
        #100;

        reset = 0;

        // Give the circuit some time
        #100;


        // Start transmission
        data_in  = 8'b10110010;
        tx_start = 1;

        // One clock pulse
        #20;
        tx_start = 0;


        // Wait for receiver
        wait(valid);


        $display("--------------------------------");
        $display("EXPECTED = 10110010");
        $display("RECEIVED = %b", data_out);
        $display("--------------------------------");


        if (data_out == 8'b10110010)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");


        #100;

        $finish;

    end

endmodule