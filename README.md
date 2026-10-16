# UART Transmitter and Receiver (SystemVerilog)

A UART transmitter and receiver written in SystemVerilog, both built as simple FSMs. The design uses the common 8N1 format (8 data bits, no parity, 1 stop bit, LSB first), runs on a 50 MHz clock at 9600 baud, and is checked with a self-checking loopback testbench.

Verified in simulation with Icarus Verilog. It has not been synthesized or run on a physical FPGA yet.

## Files

| File | What it is |
|------|------------|
| `transmitter.sv` | UART transmitter |
| `receiver.sv` | UART receiver |
| `tb_uart.sv` | Self-checking testbench (transmitter wired to receiver) |

## Frame format

```
idle  start  D0  D1  D2  D3  D4  D5  D6  D7  stop  idle
 1      0    LSB ------------------------ MSB  1     1
```

Each bit lasts 5208 clock cycles (50 MHz / 9600 baud = 5208.3, about 0.006% error).

## Transmitter

FSM states: `IDLE -> START -> DATA -> STOP`.

| Port | Dir | Description |
|------|-----|-------------|
| `clk` | in | 50 MHz clock |
| `reset` | in | Synchronous reset, active high |
| `tx_start` | in | Pulse high for one clock in `IDLE` to send `data_in` |
| `data_in[7:0]` | in | Byte to send |
| `tx` | out | Serial output, idles high |
| `busy` | out | High while a frame is being sent |

`tx_start` is ignored while `busy` is high.

## Receiver

FSM states: `IDLE -> START -> DATA -> STOP`.

| Port | Dir | Description |
|------|-----|-------------|
| `clk` | in | 50 MHz clock |
| `reset` | in | Synchronous reset, active high |
| `rx` | in | Serial input |
| `data_out[7:0]` | out | Last received byte |
| `data_valid` | out | One clock pulse when a good byte is ready |
| `frame_error` | out | One clock pulse when the stop bit was low |

The baud rate is set with the `CLKS_PER_BIT` parameter (default 5208).

How it receives a byte:

1. **Input sync.** `rx` goes through two flip-flops before it is used, because it is asynchronous to the clock.
2. **Start detection.** When the line goes low, the receiver waits half a bit and checks the line is still low. A shorter pulse is treated as a glitch and ignored.
3. **Sampling.** Each data bit is sampled once per bit period, which lands near the middle of the bit, away from the edges.
4. **Stop bit.** If the stop bit is high, `data_out` is updated and `data_valid` pulses. If it is low, `frame_error` pulses instead and the byte is dropped.

## Simulation

Requires [Icarus Verilog](https://github.com/steveicarus/iverilog) 11 or newer (tested with 12.0).

```bash
iverilog -g2012 -o sim.out transmitter.sv receiver.sv tb_uart.sv
vvp sim.out
```

It takes about 15 seconds. A passing run ends with:

```
checks: 54   errors: 0
ALL TESTS PASSED
```

The testbench also writes `uart.vcd`, which can be opened in GTKWave:

```bash
gtkwave uart.vcd
```

### What the testbench checks

| Test | What it covers |
|------|----------------|
| 1 | Bit timing of the transmitter (start bit width) |
| 2 | Nine directed bytes (`00`, `FF`, `A5`, `5A`, `55`, `AA`, `01`, `80`, `3C`) through TX to RX |
| 3 | 30 random bytes sent back to back with no gap |
| 4 | Bad stop bit gives `frame_error` and no `data_valid`, then the next good frame is received |
| 5 | A short glitch on the idle line is ignored |
| 6 | Sender running 2% fast and 2% slow is still received correctly |
| 7 | Reset in the middle of a frame, then normal operation |

The loopback checks use a queue of expected bytes, so order and values are both verified. To make sure the testbench can actually fail, I also broke the receiver on purpose (reversed bit order) and confirmed it reported errors.

## Notes and limitations

- The transmitter's start bit lasts 5209 clocks while the other bits last 5208. The difference is 0.02% of a bit and the receiver is not affected.
- The baud rate in `transmitter.sv` is hardcoded (5207 as the terminal count). The receiver uses a parameter.
- No parity bit, no FIFO, and no oversampling. The receiver samples once per bit.
- Not yet synthesized or tested on hardware.

## Possible next steps

- Run through an open-source synthesis flow (Yosys + nextpnr) and record utilization and timing.
- Put it on a real FPGA board and talk to a PC through a USB-serial adapter.
- Make the transmitter baud rate a parameter like the receiver.
