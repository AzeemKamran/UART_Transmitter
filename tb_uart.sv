`timescale 1ns / 1ps

// Testbench for the UART transmitter + receiver.
//
// Two receivers are used:
//   dut_rx    - connected straight to the transmitter (loopback)
//   manual_rx - driven by the testbench so we can send bad frames,
//               glitches and slightly wrong baud rates

module tb_uart;

  localparam int BIT_CLKS = 5208;

  logic clk = 1'b0;
  logic reset;

  // transmitter side
  logic       tx_start;
  logic [7:0] data_in;
  logic       tx;
  logic       busy;

  // loopback receiver
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       rx_ferr;

  // manual receiver
  logic       manual_line = 1'b1;
  logic [7:0] m_data;
  logic       m_valid;
  logic       m_ferr;

  always #10 clk = ~clk;   // 50 MHz

  transmitter dut_tx (
      .clk     (clk),
      .reset   (reset),
      .tx_start(tx_start),
      .data_in (data_in),
      .tx      (tx),
      .busy    (busy)
  );

  receiver dut_rx (
      .clk        (clk),
      .reset      (reset),
      .rx         (tx),
      .data_out   (rx_data),
      .data_valid (rx_valid),
      .frame_error(rx_ferr)
  );

  receiver manual_rx (
      .clk        (clk),
      .reset      (reset),
      .rx         (manual_line),
      .data_out   (m_data),
      .data_valid (m_valid),
      .frame_error(m_ferr)
  );


  // ------------------------------------------------------------
  // scoreboard for the loopback path
  // ------------------------------------------------------------
  logic [7:0] expected[$];
  int checks = 0;
  int errors = 0;
  int bytes_received = 0;

  always @(posedge clk) begin
    if (rx_valid) begin
      bytes_received++;
      if (expected.size() == 0) begin
        $display("[%0t] ERROR: receiver gave 0x%02h but nothing was expected", $time, rx_data);
        errors++;
      end
      else begin
        logic [7:0] exp;
        exp = expected.pop_front();
        checks++;
        if (rx_data !== exp) begin
          $display("[%0t] ERROR: expected 0x%02h, got 0x%02h", $time, exp, rx_data);
          errors++;
        end
      end
    end
    if (rx_ferr) begin
      $display("[%0t] ERROR: loopback receiver flagged a framing error", $time);
      errors++;
    end
  end


  // counters for the manual receiver
  int m_valid_count = 0;
  int m_ferr_count  = 0;
  logic [7:0] m_last_data;

  always @(posedge clk) begin
    if (m_valid) begin
      m_valid_count++;
      m_last_data = m_data;
    end
    if (m_ferr) m_ferr_count++;
  end


  // ------------------------------------------------------------
  // helper tasks
  // ------------------------------------------------------------
  task automatic check(input string name, input bit ok);
    checks++;
    if (!ok) begin
      errors++;
      $display("  FAIL: %s", name);
    end
    else begin
      $display("  pass: %s", name);
    end
  endtask

  // start one byte on the transmitter (waits if it is still busy)
  task automatic send_byte(input logic [7:0] b);
    while (busy) @(posedge clk);
    expected.push_back(b);
    @(posedge clk);
    data_in  <= b;
    tx_start <= 1'b1;
    @(posedge clk);
    tx_start <= 1'b0;
    // busy goes high one clock after tx_start, wait for that
    @(posedge clk);
  endtask

  // wait until everything sent has been received
  task automatic wait_for_all(input int max_clks);
    int waited = 0;
    while (expected.size() != 0 && waited < max_clks) begin
      @(posedge clk);
      waited++;
    end
  endtask

  // drive a frame onto manual_line by hand
  task automatic bit_bang(input logic [7:0] b, input logic stop_bit, input int bit_clks);
    manual_line = 1'b0;                    // start
    repeat (bit_clks) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      manual_line = b[i];
      repeat (bit_clks) @(posedge clk);
    end
    manual_line = stop_bit;                // stop
    repeat (bit_clks) @(posedge clk);
    manual_line = 1'b1;
    repeat (bit_clks) @(posedge clk);      // some idle time before the next one
  endtask


  // ------------------------------------------------------------
  // main test
  // ------------------------------------------------------------
  logic [7:0] directed[$] = '{8'h00, 8'hFF, 8'hA5, 8'h5A, 8'h55, 8'hAA, 8'h01, 8'h80, 8'h3C};
  time t_fall, t_rise;
  int  start_clks;
  int  before_valid, before_ferr;

  initial begin
    $dumpfile("uart.vcd");
    $dumpvars(0, tb_uart);

    tx_start = 1'b0;
    data_in  = 8'd0;
    reset    = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
    repeat (5) @(posedge clk);

    // ---- test 1: measure the bit width coming out of the transmitter
    $display("\nTest 1: transmitter bit timing");
    expected.push_back(8'hFF);
    @(posedge clk);
    data_in  <= 8'hFF;
    tx_start <= 1'b1;
    @(posedge clk);
    tx_start <= 1'b0;
    @(negedge tx);
    t_fall = $time;
    @(posedge tx);                         // 0xFF has a single low bit: the start bit
    t_rise = $time;
    start_clks = (t_rise - t_fall) / 20;
    $display("  start bit lasts %0d clocks (nominal %0d)", start_clks, BIT_CLKS);
    check("start bit within 1 clock of nominal",
          start_clks >= BIT_CLKS - 1 && start_clks <= BIT_CLKS + 1);
    wait_for_all(20 * BIT_CLKS);

    // ---- test 2: directed values through the loopback
    $display("\nTest 2: directed bytes, TX -> RX loopback");
    foreach (directed[i]) begin
      send_byte(directed[i]);
      wait_for_all(20 * BIT_CLKS);
    end
    check("all directed bytes received", expected.size() == 0);

    // ---- test 3: random bytes back to back (no gap between frames)
    $display("\nTest 3: 30 random bytes back to back");
    for (int i = 0; i < 30; i++) begin
      send_byte($urandom_range(0, 255));
    end
    wait_for_all(40 * BIT_CLKS);
    check("all random bytes received in order", expected.size() == 0);

    // ---- test 4: bad stop bit should raise frame_error, not data_valid
    $display("\nTest 4: framing error");
    before_valid = m_valid_count;
    before_ferr  = m_ferr_count;
    bit_bang(8'hA5, 1'b0, BIT_CLKS);
    check("frame_error pulsed",        m_ferr_count  == before_ferr + 1);
    check("data_valid stayed low",     m_valid_count == before_valid);

    // good frame right after the bad one, receiver must recover
    before_valid = m_valid_count;
    before_ferr  = m_ferr_count;
    bit_bang(8'hC3, 1'b1, BIT_CLKS);
    check("recovers after framing error", m_valid_count == before_valid + 1);
    check("recovered byte is correct",    m_last_data == 8'hC3);
    check("no extra frame_error",         m_ferr_count == before_ferr);

    // ---- test 5: short glitch on the idle line is ignored
    $display("\nTest 5: glitch rejection");
    before_valid = m_valid_count;
    before_ferr  = m_ferr_count;
    manual_line = 1'b0;
    repeat (300) @(posedge clk);           // much shorter than half a bit
    manual_line = 1'b1;
    repeat (3 * BIT_CLKS) @(posedge clk);
    check("glitch ignored (no data_valid)", m_valid_count == before_valid);
    check("glitch ignored (no frame_error)", m_ferr_count == before_ferr);

    // ---- test 6: sender baud rate slightly off (about +-2%)
    $display("\nTest 6: baud rate tolerance");
    before_valid = m_valid_count;
    bit_bang(8'h96, 1'b1, 5100);           // 2% fast
    check("2% fast sender received",  m_valid_count == before_valid + 1 && m_last_data == 8'h96);
    before_valid = m_valid_count;
    bit_bang(8'h69, 1'b1, 5312);           // 2% slow
    check("2% slow sender received",  m_valid_count == before_valid + 1 && m_last_data == 8'h69);

    // ---- test 7: reset in the middle of a frame
    $display("\nTest 7: reset in the middle of a frame");
    expected.delete();
    expected.push_back(8'h77);
    @(posedge clk);
    data_in  <= 8'h77;
    tx_start <= 1'b1;
    @(posedge clk);
    tx_start <= 1'b0;
    repeat (4 * BIT_CLKS) @(posedge clk);
    reset = 1'b1;
    repeat (3) @(posedge clk);
    reset = 1'b0;
    expected.delete();                     // the interrupted byte is gone
    repeat (3 * BIT_CLKS) @(posedge clk);
    send_byte(8'h4E);
    wait_for_all(20 * BIT_CLKS);
    check("works normally after reset", expected.size() == 0);

    // ---- summary
    $display("\n-----------------------------------");
    $display("checks: %0d   errors: %0d", checks, errors);
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("TESTS FAILED");
    $display("-----------------------------------");
    $finish;
  end


  // watchdog so a hung design does not run forever
  initial begin
    #2_000_000_000;
    $display("TIMEOUT: simulation took too long");
    $finish;
  end

endmodule
