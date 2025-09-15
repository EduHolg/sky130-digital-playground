//////////////////////////////////////////////////////////////////////////////////
// TOP
//////////////////////////////////////////////////////////////////////////////////
/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_digital_playground (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=drive, 0=input/hi-Z)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Mode select (exclusive)
  wire [2:0] mode = ui_in[2:0];
  localparam MODE_GATES = 3'b000;
  localparam MODE_CNT   = 3'b001; // was MODE_MXD
  localparam MODE_PWM   = 3'b010;
  localparam MODE_HEX7  = 3'b011;
  localparam MODE_ALU   = 3'b100;
  localparam MODE_FDC   = 3'b101;
  localparam MODE_RAM   = 3'b110;
  localparam MODE_DIR   = 3'b111;

  // 000: Basic logic gates
  wire g_and, g_or, g_xor, g_nand, g_nor, g_not_a;
  gates_basic u_gates (
    .a(uio_in[0]), .b(uio_in[1]),
    .y_and(g_and), .y_or(g_or), .y_xor(g_xor),
    .y_nand(g_nand), .y_nor(g_nor), .y_not_a(g_not_a)
  );

  // 001: 8-bit counter (enable on ui_in[3])
  wire [7:0] cnt8_q;
  counter8 u_cnt8 (
    .clk (clk),
    .rst_n(rst_n),
    .en  (ui_in[3]),
    .q   (cnt8_q)
  );

  // 010: PWM
  wire pwm_o;
  pwm #(.N(8)) u_pwm (
    .clk    (clk),
    .rst_n  (rst_n),
    .duty   (uio_in[7:0]),
    .pwm_out(pwm_o)
  );

  // 011: HEX to 7-seg
  wire [6:0] seg7;
  hex7seg u_hex (.x(uio_in[3:0]), .seg(seg7));

  // 100: Mini ALU4
  wire [3:0] alu_y; wire alu_flag;
  mini_alu4 u_alu (
    .a (uio_in[3:0]),
    .b (uio_in[7:4]),
    .op(ui_in[5:3]),
    .y (alu_y),
    .carry_or_borrow(alu_flag)
  );

  // 101: Synchronous FDC
  wire [4:0] fdc_y;
  fdc_sincronico u_fdc (
    .VCO  (uio_in[0]),
    .clk  (clk),
    .reset(~rst_n),
    .D_out(fdc_y)
  );

  // 110: 16x4 RAM
  wire [3:0] ram_q;
  RAM u_ram (
    .clk     (clk),
    .we      (ui_in[7]),
    .add     (ui_in[6:3]),
    .data_in (uio_in[3:0]),
    .data_out(ram_q)
  );

  // 111: Direccionales
  wire [2:0] dir_izq, dir_der;
  direccionales u_dir (
    .clk (clk),
    .dir (ui_in[4:3]),
    .izq (dir_izq),
    .der (dir_der)
  );

  // Outputs
  reg [7:0] uo_out_r, uio_out_r, uio_oe_r;
  always @* begin
    uo_out_r  = 8'h00;
    uio_out_r = 8'h00;
    uio_oe_r  = 8'h00;
    case (mode)
      MODE_GATES: uo_out_r = {2'b00, g_not_a, g_nor, g_nand, g_xor, g_or, g_and};
      MODE_CNT  : uo_out_r = cnt8_q;                       // <- counter on outputs
      MODE_PWM  : uo_out_r = {uio_in[7:1], pwm_o};
      MODE_HEX7 : uo_out_r = {1'b0, seg7};
      MODE_ALU  : uo_out_r = {3'b000, alu_flag, alu_y};
      MODE_FDC  : uo_out_r = {3'b000, fdc_y};
      MODE_RAM  : uo_out_r = {4'b0000, ram_q};
      MODE_DIR  : uo_out_r = {1'b0, dir_der, 1'b0, dir_izq};
      default   : uo_out_r = 8'h00;
    endcase
  end

  assign uo_out  = uo_out_r;
  assign uio_out = uio_out_r;
  assign uio_oe  = uio_oe_r;

  wire _unused = &{ena, 1'b0};
endmodule
