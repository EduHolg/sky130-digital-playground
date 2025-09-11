//////////////////////////////////////////////////////////////////////////////////
// TOP
//////////////////////////////////////////////////////////////////////////////////
/*
 * Copyright (c) 2025 Eduardo Holguin
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=drive, 0=input/hi-Z)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // -------------------------
  // Mode select (exclusive)
  // -------------------------
  wire [2:0] mode = ui_in[2:0];
  localparam MODE_GATES = 3'b000;
  localparam MODE_MXD   = 3'b001; // mux2 + demux1to4
  localparam MODE_PWM   = 3'b010;
  localparam MODE_HEX7  = 3'b011;
  localparam MODE_ALU   = 3'b100;
  localparam MODE_FDC   = 3'b101;
  localparam MODE_RAM   = 3'b110;
  localparam MODE_DIR   = 3'b111;

  // -------------------------
  // Submodules
  // -------------------------

  // 000: Basic logic gates (a,b from uio_in[1:0])
  wire g_and, g_or, g_xor, g_nand, g_nor, g_not_a;
  gates_basic u_gates (
    .a(uio_in[0]), .b(uio_in[1]),
    .y_and(g_and), .y_or(g_or), .y_xor(g_xor),
    .y_nand(g_nand), .y_nor(g_nor), .y_not_a(g_not_a)
  );

  // 001: Combined 2:1 MUX + 1:4 DEMUX
  wire        y_mux;
  wire [3:0]  y_demux;
  mux2_demux1to4 u_mxd (
    .d0       (uio_in[0]),
    .d1       (uio_in[1]),
    .sel_mux  (ui_in[3]),
    .y_mux    (y_mux),
    .din_demux(uio_in[2]),
    .sel_demux(ui_in[5:4]),
    .y_demux  (y_demux)
  );

  // 010: PWM (duty from uio_in)
  wire pwm_o;
  pwm #(.N(8)) u_pwm (
    .clk    (clk),
    .rst_n  (rst_n),
    .duty   (uio_in[7:0]),
    .pwm_out(pwm_o)
  );

  // 011: HEX to 7-seg (nibble from uio_in[3:0])
  wire [6:0] seg7;
  hex7seg u_hex (
    .x  (uio_in[3:0]),
    .seg(seg7)
  );

  // 100: Mini ALU4 (a,b from uio_in; op from ui_in[5:3])
  wire [3:0] alu_y;
  wire       alu_flag;
  mini_alu4 u_alu (
    .a (uio_in[3:0]),
    .b (uio_in[7:4]),
    .op(ui_in[5:3]),
    .y (alu_y),
    .carry_or_borrow(alu_flag)
  );

  // 101: Synchronous FDC (VCO from uio_in[0], system clk/reset)
  wire [4:0] fdc_y;
  fdc_sincronico u_fdc (
    .VCO  (uio_in[0]),
    .clk  (clk),
    .reset(~rst_n),   // module expects active-high reset
    .D_out(fdc_y)
  );

  // 110: 16x4 RAM (sync read, pipelined WE)
  wire [3:0] ram_q;
  RAM u_ram (
    .clk     (clk),
    .we      (ui_in[7]),     // WE on ui_in[7]
    .add     (ui_in[6:3]),   // Address on ui_in[6:3]
    .data_in (uio_in[3:0]),  // Data input from uio_in
    .data_out(ram_q)
  );

  // 111: Direccionales (dir from ui_in[4:3])
  wire [2:0] dir_izq, dir_der;
  direccionales u_dir (
    .clk (clk),
    .dir (ui_in[4:3]),
    .izq (dir_izq),
    .der (dir_der)
  );

  // -------------------------
  // Output muxing (all unused bits forced to 0)
  // -------------------------
  reg [7:0] uo_out_r;
  reg [7:0] uio_out_r;
  reg [7:0] uio_oe_r;

  always @* begin
    // Default: everything zero/tri-stated
    uo_out_r  = 8'h00;
    uio_out_r = 8'h00;
    uio_oe_r  = 8'h00;

    case (mode)
      MODE_GATES: begin
        // {MSB..LSB} = {00, ~a, NOR, NAND, XOR, OR, AND}
        uo_out_r = {2'b00, g_not_a, g_nor, g_nand, g_xor, g_or, g_and};
      end

      MODE_MXD: begin
        // [7:5]=0, [4:1]=y_demux, [0]=y_mux
        uo_out_r = {3'b000, y_demux, y_mux};
      end

      MODE_PWM: begin
        // [7:1]=duty from uio_in, [0]=pwm
        uo_out_r = {uio_in[7:1], pwm_o};
      end

      MODE_HEX7: begin
        // [7]=0, [6:0]=seven-seg code
        uo_out_r = {1'b0, seg7};
      end

      MODE_ALU: begin
        // [7:5]=0, [4]=flag, [3:0]=y
        uo_out_r = {3'b000, alu_flag, alu_y};
      end

      MODE_FDC: begin
        // [7:5]=0, [4:0]=fdc_y
        uo_out_r = {3'b000, fdc_y};
      end

      MODE_RAM: begin
        // [7:4]=0, [3:0]=ram_q
        uo_out_r = {4'b0000, ram_q};
      end

      MODE_DIR: begin
        // [7]=0, [6:4]=der, [3]=0, [2:0]=izq
        uo_out_r = {1'b0, dir_der, 1'b0, dir_izq};
      end

      default: begin
        // keep zeros
        uo_out_r = 8'h00;
      end
    endcase
  end

  // Drive pads
  assign uo_out  = uo_out_r;
  assign uio_out = uio_out_r; // never driven in this design
  assign uio_oe  = uio_oe_r;  // keep all bidirs as inputs

  // Unused
  wire _unused = &{ena, 1'b0};

endmodule
