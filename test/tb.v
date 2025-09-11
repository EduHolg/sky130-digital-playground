`default_nettype none
`timescale 1ns / 1ps

module tb();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    // Initialize inputs
    clk   = 0;
    rst_n = 1;
    ena   = 1;
    ui_in = 8'b0000_1000; // ui_in[3] = 0, ui_in[0] = 1
    uio_in = 8'h00;       // avoid Xs on bidirectional inputs

    // Generate pulse signals for ui_in[1] and ui_in[2]
    repeat (10) begin // Simulate for 10 time units
      #5 clk = ~clk;         // Toggle clock every 5 time units
      #1 ui_in[1] = 1;       // Set ui_in[1] high for 1 time unit
      #1 ui_in[1] = 0;       // Set ui_in[1] low for 1 time unit
      #1 ui_in[2] = ~ui_in[2]; // Toggle ui_in[2] every 1 time unit
    end

    #10; // Wait for 10 time units
  end

  // Wire up the inputs and outputs:
  reg        clk;
  reg        rst_n;
  reg        ena;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Replace with your module name:
  tt_um_digital_playground dut (

    // Include power ports for the Gate Level test (TinyTapeout convention):
`ifdef GL_TEST
    .VPWR(1'b1),
    .VGND(1'b0),
`endif

    .ui_in  (ui_in),    // Dedicated inputs
    .uo_out (uo_out),   // Dedicated outputs
    .uio_in (uio_in),   // IOs: Input path
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe (uio_oe),   // IOs: Enable path (1=output)
    .ena    (ena),      // enable - goes high when design is selected
    .clk    (clk),      // clock
    .rst_n  (rst_n)     // active-low reset
  );

endmodule
