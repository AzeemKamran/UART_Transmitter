module reciever(
    input  logic       clk,
    input  logic       rx,
    input  logic       reset,
    output logic [7:0] data_out,
    output logic       valid
);

    typedef enum {idle, start, data, stop} state_t;
    state_t state;

    logic [12:0] count;
    logic [2:0]  index;

    always @(posedge clk) begin

        if (reset) begin
            state    <= idle;
            count    <= 0;
            index    <= 0;
            data_out <= 0;
            valid    <= 0;
        end

        else begin

            // valid is a one-clock pulse
            valid <= 0;

            // baud counter
            if (state != idle)
                count <= count + 1;

            // Detect start bit
            if (state == idle && !rx) begin
                state <= start;
            end

            // Check middle of start bit
            if (state == start && count == 2604) begin

                count <= 0;

                if (rx)
                    state <= idle;     // false start
                else
                    state <= data;     // valid start
            end

            // Sample data bits
            if (state == data && count == 5207) begin

                data_out[index] <= rx;
                count <= 0;

                if (index == 7) begin
                    index <= 0;
                    state <= stop;
                end
                else begin
                    index <= index + 1;
                end

            end

            // Check stop bit
            if (state == stop && count == 5207) begin

                count <= 0;
                state <= idle;

                if (rx)
                    valid <= 1;

            end

        end
    end

endmodule
