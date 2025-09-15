`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_digital_playground user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

`ifndef COCOTB_SIM
  // ---------------- Standalone self-check (no cocotb) ----------------
  // Generate a 100 MHz clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    // Defaults
    ena    = 1'b1;
    ui_in  = 8'h00;
    uio_in = 8'h00;

    // Reset low for a few cycles
    rst_n = 1'b0;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;

    // MODE = 001 (counter), EN bit3 = 1  -> ui_in = 0b1001 = 9
    ui_in = 8'd9;

    // Count 15 rising edges
    repeat (15) @(posedge clk);

    // Check that counter == 15
    if (uo_out !== 8'd15) begin
      $display("ERROR: expected 15, got %0d (uo_out=%0h) at t=%0t", uo_out, uo_out, $time);
      $fatal;
    end else begin
      $display("PASS: counter reached 15 as expected at t=%0t", $time);
    end

    $finish;
  end
`endif

endmodule
