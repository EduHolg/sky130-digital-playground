`timescale 1ns/1ps
`default_nettype none

module tb;

  // DUT I/O
  reg  [7:0] ui_in;
  wire [7:0] uo_out;
  reg  [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg        ena;
  reg        clk;
  reg        rst_n;

  // Instantiate DUT
  tt_um_digital_playground dut (
    .ui_in (ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena   (ena),
    .clk   (clk),
    .rst_n (rst_n)
  );

  // 50 MHz system clock
  initial clk = 1'b0;
  always #10 clk = ~clk; // 20 ns period

  // Reset task
  task reset_dut;
    begin
      rst_n = 1'b0;
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      @(posedge clk);
    end
  endtask

  // Mode constants (must match DUT)
  localparam MODE_GATES = 3'b000;
  localparam MODE_MXD   = 3'b001; // mux2 + demux1to4
  localparam MODE_PWM   = 3'b010;
  localparam MODE_HEX7  = 3'b011;
  localparam MODE_ALU   = 3'b100;
  localparam MODE_FDC   = 3'b101;
  localparam MODE_RAM   = 3'b110;
  localparam MODE_DIR   = 3'b111;

  task set_mode(input [2:0] m);
    begin
      ui_in[2:0] = m;     // ui_in[2:0] are EXCLUSIVE for the mode
      @(posedge clk);
    end
  endtask

  // -------- 000: GATES (a,b on uio_in[1:0])
  task test_gates;
    reg a,b;
    begin
      $display("\n[TEST] GATES");
      set_mode(MODE_GATES);

      // clean inputs except the bits we drive
      uio_in = 8'h00;

      a=0; b=0; drive_gates_and_check(a,b);
      a=0; b=1; drive_gates_and_check(a,b);
      a=1; b=0; drive_gates_and_check(a,b);
      a=1; b=1; drive_gates_and_check(a,b);
    end
  endtask

  task drive_gates_and_check(input a, input b);
    reg [7:0] exp;
    begin
      uio_in[0] = a;
      uio_in[1] = b;
      @(posedge clk);

      // DUT mapping: {00, ~a, NOR, NAND, XOR, OR, AND}
      exp = 8'h00;
      exp[0] = a & b;
      exp[1] = a | b;
      exp[2] = a ^ b;
      exp[3] = ~(a & b);
      exp[4] = ~(a | b);
      exp[5] = ~a;

      if (uo_out !== exp)
        $display("ERROR[GATES] a=%0d b=%0d got=%b exp=%b", a,b,uo_out,exp);
      else
        $display("OK   [GATES] a=%0d b=%0d -> %b", a,b,uo_out);
    end
  endtask

  // -------- 001: MUX/DEMUX (data on uio_in; selects ui_in[3], ui_in[5:4])
  task test_mux_demux;
    begin
      $display("\n[TEST] MUX/DEMUX");
      set_mode(MODE_MXD);

      uio_in = 8'h00;
      uio_in[0]=0; uio_in[1]=1; uio_in[2]=1;

      // sel_mux=0 -> y_mux=0; sel_demux=0 -> 0001
      ui_in[3]=0;          // sel_mux
      ui_in[5:4]=2'd0;     // sel_demux
      @(posedge clk);
      if (uo_out[0]!==1'b0 || uo_out[4:1]!==4'b0001)
        $display("ERROR[MXD] case1 got y_mux=%b y_demux=%b", uo_out[0], uo_out[4:1]);
      else
        $display("OK   [MXD] case1");

      // sel_mux=1 -> y_mux=1; sel_demux=2 -> 0100
      ui_in[3]=1;
      ui_in[5:4]=2'd2;
      @(posedge clk);
      if (uo_out[0]!==1'b1 || uo_out[4:1]!==4'b0100)
        $display("ERROR[MXD] case2 got y_mux=%b y_demux=%b", uo_out[0], uo_out[4:1]);
      else
        $display("OK   [MXD] case2");
    end
  endtask

  // -------- 010: PWM (duty on uio_in[7:0])
  task test_pwm;
    integer i, highc;
    reg [7:0] duty;
    begin
      $display("\n[TEST] PWM");
      set_mode(MODE_PWM);

      duty = 8'hAA;           // 170
      uio_in = duty;          // duty lives on uio_in, NOT ui_in
      @(posedge clk);

      highc = 0;
      for (i=0;i<256;i=i+1) begin
        @(posedge clk);
        if (uo_out[0]) highc = highc + 1;
      end

      if (highc !== duty)
        $display("ERROR[PWM] measured=%0d expected=%0d", highc, duty);
      else
        $display("OK   [PWM] duty=%0d measured %0d/256", duty, highc);
    end
  endtask

  // -------- 011: HEX7SEG (nibble on uio_in[3:0])
  task test_hex7;
    reg [6:0] exp;
    begin
      $display("\n[TEST] HEX7SEG");
      set_mode(MODE_HEX7);

      uio_in = 8'h00;
      uio_in[3:0] = 4'hA;
      @(posedge clk);

      exp = 7'b1110111;
      if (uo_out[6:0] !== exp)
        $display("ERROR[HEX7] got=%b exp=%b", uo_out[6:0], exp);
      else
        $display("OK   [HEX7] A -> %b", uo_out[6:0]);
    end
  endtask

  // -------- 100: MINI ALU4 (a,b on uio_in; op on ui_in[5:3])
  task test_alu;
    reg [3:0] a,b,exp_y;
    reg [2:0] op;
    reg       exp_flag;
    begin
      $display("\n[TEST] MINI_ALU4");
      set_mode(MODE_ALU);

      a = 4'd9; b = 4'd7; op = 3'b000;   // add
      uio_in[3:0] = a;
      uio_in[7:4] = b;
      ui_in[5:3]  = op;                  // op uses ui_in[5:3]; ui_in[2:0] already MODE_ALU
      @(posedge clk);

      exp_y   = 4'd0;
      exp_flag= 1'b1;
      if (uo_out[3:0] !== exp_y || uo_out[4] !== exp_flag)
        $display("ERROR[ALU] add got y=%h flag=%b exp y=%h flag=%b",
                  uo_out[3:0], uo_out[4], exp_y, exp_flag);
      else
        $display("OK   [ALU] 9+7 -> y=0, carry=1");
    end
  endtask

  // -------- 101: FDC (temporary VCO on uio_in[0])
  task test_fdc;
    reg [7:0] snap1, snap2;
    integer k;
    begin
      $display("\n[TEST] FDC (synchronous)");
      set_mode(MODE_FDC);

      // drive only the VCO bit here
      uio_in[0] = 1'b0;
      fork
        begin : vco_drive
          for (k=0; k<800; k=k+1) begin
            #7 uio_in[0] = ~uio_in[0];
          end
        end
        begin : observe
          repeat (8)  @(posedge clk);
          snap1 = {3'b000, uo_out[4:0]};
          repeat (16) @(posedge clk);
          snap2 = {3'b000, uo_out[4:0]};
        end
      join

      if (snap1 == snap2)
        $display("WARN [FDC] value unchanged (%0d); check VCO/clk ratio", snap1);
      else
        $display("OK   [FDC] observed change %0d -> %0d", snap1, snap2);
    end
  endtask

  // -------- 110: RAM (WE on ui_in[7], addr on ui_in[6:3], data on uio_in[3:0])
  task test_ram;
    reg [3:0] addr, din, dout;
    begin
      $display("\n[TEST] RAM 16x4");
      set_mode(MODE_RAM);

      addr = 4'd3; din = 4'hA;
      uio_in[3:0] = din;      // data
      ui_in[6:3]  = addr;     // address
      ui_in[7]    = 1'b1;     // WE
      @(posedge clk);
      // allow 2-cycle WE pipeline inside RAM
      repeat (3) @(posedge clk);
      ui_in[7]    = 1'b0;     // deassert WE
      @(posedge clk);

      // read back
      ui_in[6:3] = addr;
      @(posedge clk);         // sync read is registered
      dout = uo_out[3:0];
      if (dout !== din)
        $display("ERROR[RAM] addr=%0d got=%h exp=%h", addr, dout, din);
      else
        $display("OK   [RAM] addr=%0d read=%h", addr, dout);
    end
  endtask

  // -------- 111: Direccionales (dir on ui_in[4:3])
  task test_direccionales;
    reg [2:0] a1,a2;
    begin
      $display("\n[TEST] DIRECCIONALES");
      set_mode(MODE_DIR);

      ui_in[4:3] = 2'b01; // left
      @(posedge clk); a1 = uo_out[2:0];
      @(posedge clk); a2 = uo_out[2:0];
      if (a1===a2)
        $display("WARN [DIR] left pattern unchanged (%b -> %b)", a1, a2);
      else
        $display("OK   [DIR] left toggles (%b -> %b)", a1, a2);

      ui_in[4:3] = 2'b10; @(posedge clk);
      $display("INFO [DIR] right  izq=%b der=%b", uo_out[2:0], uo_out[6:4]);

      ui_in[4:3] = 2'b11; @(posedge clk);
      $display("INFO [DIR] both   izq=%b der=%b", uo_out[2:0], uo_out[6:4]);
    end
  endtask

  // Test sequence
  initial begin
    // (XSim writes WDB; VCD calls are optional)
    $dumpfile("tt_playground_tb.vcd");
    $dumpvars(0, tb);

    ena   = 1'b1;
    ui_in = 8'h00;
    uio_in= 8'h00;

    reset_dut;

    test_gates();
    test_mux_demux();
    test_pwm();
    test_hex7();
    test_alu();
    test_fdc();
    test_ram();
    test_direccionales();

    $display("\nAll tests completed.");
    #200;
    $finish;
  end

endmodule

`default_nettype wire
