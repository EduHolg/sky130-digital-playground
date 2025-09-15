`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 000 Basic logic gates (bundle)
//////////////////////////////////////////////////////////////////////////////////
module gates_basic(
  input  wire a, b,
  output wire y_and, y_or, y_xor, y_nand, y_nor, y_not_a
);
  assign y_and  = a & b;
  assign y_or   = a | b;
  assign y_xor  = a ^ b;
  assign y_nand = ~(a & b);
  assign y_nor  = ~(a | b);
  assign y_not_a= ~a;
endmodule
//////////////////////////////////////////////////////////////////////////////////
// 001 Replaced block: 8-bit counter
//////////////////////////////////////////////////////////////////////////////////
module counter8 #(
  parameter N = 8
)(
  input  wire clk,
  input  wire rst_n,   // active-low reset
  input  wire en,      // count enable
  output reg  [N-1:0] q
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= {N{1'b0}};
    else if (en) q <= q + 1'b1;
  end
endmodule
//////////////////////////////////////////////////////////////////////////////////
// 010 PWM (counter + comparator)
//////////////////////////////////////////////////////////////////////////////////
module pwm #(parameter N=8)(
  input  wire clk, rst_n,
  input  wire [N-1:0] duty,
  output reg  pwm_out
);
  reg [N-1:0] cnt;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= {N{1'b0}};
    else        cnt <= cnt + 1'b1;
  end
  always @(*) pwm_out = (cnt < duty);
endmodule

//////////////////////////////////////////////////////////////////////////////////
// 011 HEX to 7-Segment (active-low segments option)
//////////////////////////////////////////////////////////////////////////////////
module hex7seg(
  input  wire [3:0] x,
  output reg  [6:0] seg // {a,b,c,d,e,f,g}, 1=ON (set invert if needed)
);
  always @(*) begin
    case (x)
      4'h0: seg=7'b1111110;
      4'h1: seg=7'b0110000;
      4'h2: seg=7'b1101101;
      4'h3: seg=7'b1111001;
      4'h4: seg=7'b0110011;
      4'h5: seg=7'b1011011;
      4'h6: seg=7'b1011111;
      4'h7: seg=7'b1110000;
      4'h8: seg=7'b1111111;
      4'h9: seg=7'b1111011;
      4'hA: seg=7'b1110111;
      4'hB: seg=7'b0011111;
      4'hC: seg=7'b1001110;
      4'hD: seg=7'b0111101;
      4'hE: seg=7'b1001111;
      4'hF: seg=7'b1000111;
      default: seg=7'b0000000;
    endcase
  end
endmodule
//////////////////////////////////////////////////////////////////////////////////
// 100 Mini-ALU (4-bit)
//////////////////////////////////////////////////////////////////////////////////
module mini_alu4(
  input  wire [3:0] a, b,
  input  wire [2:0] op,   // 000 add,001 sub,010 AND,011 OR,100 XOR,101 NOTA,110 PASSA,111 PASSB
  output reg  [3:0] y,
  output wire       carry_or_borrow
);
  wire [4:0] addv = {1'b0,a} + {1'b0,b};
  wire [4:0] subv = {1'b0,a} + {1'b0,~b} + 5'b00001;
  assign carry_or_borrow = (op==3'b000) ? addv[4] :
                           (op==3'b001) ? ~subv[4] : 1'b0;
  always @(*) begin
    case (op)
      3'b000: y = addv[3:0];
      3'b001: y = subv[3:0];
      3'b010: y = a & b;
      3'b011: y = a | b;
      3'b100: y = a ^ b;
      3'b101: y = ~a;
      3'b110: y = a;
      3'b111: y = b;
      default:y = 4'h0;
    endcase
  end
endmodule
//////////////////////////////////////////////////////////////////////////////////
// 101 Synchronous FDC
//////////////////////////////////////////////////////////////////////////////////
module fdc_sincronico(
    input wire VCO, clk, reset,
    output reg [4:0] D_out
);
    wire [4:0] count, q1, q2;

    counter counter_1(.clk(VCO), .reset(reset), .count(count));
    register register_1(.clk(clk), .reset(reset), .d(count), .q(q1));
    register register_2(.clk(clk), .reset(reset), .d(q1), .q(q2));

    always @* 
        D_out = q1 - q2;
endmodule
module counter(
    input wire clk, reset,
    output reg [4:0] count
);
    always @(posedge clk) begin
        if (reset) 
            count <= 5'd0;
        else 
            count <= count + 1;
        end
endmodule

module register(
    input wire clk, reset,
    input wire [4:0] d,
    output reg [4:0] q
);
    always @(posedge clk) begin
        if (reset) 
            q <= 5'd0;
        else 
            q <= d;
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////
// 110 16 x 8 RAM, synchronous read, 2-cycle pipelined WE
//////////////////////////////////////////////////////////////////////////////////

module RAM (
  input        clk,
  input        we,
  input  [3:0] add,
  input  [3:0] data_in,
  output reg [3:0] data_out
);
  reg [3:0] mem [0:15];
  reg we_s, we_ss;
  always @(posedge clk) begin
    data_out <= mem[add];
    we_s     <= we;
    we_ss    <= we_s;
  end

  always @(posedge clk) begin
    if (we_ss)
      mem[add] <= data_in;
  end
endmodule

//////////////////////////////////////////////////////////////////////////////////
// 111 Single-module version of direccionales 
//////////////////////////////////////////////////////////////////////////////////

// ========================== controller (fixed) =========================
module controller (
  input  [1:0] dir,   // 00=off, 01=left, 10=right, 11=both
  input        clk,
  output reg [1:0] left,
  output reg [1:0] right
);
  // state cycles: 01 -> 10 -> 11 -> 01 ...
  reg [1:0] state;

  // pequeño generador de secuencia cíclica de 3 pasos
  always @(posedge clk) begin
    if (dir == 2'b00) begin
      state <= 2'b00;               // apagado
    end else if (state == 2'b00) begin
      state <= 2'b01;               // arranque en 01
    end else if (state == 2'b01) begin
      state <= 2'b10;
    end else if (state == 2'b10) begin
      state <= 2'b11;
    end else begin
      state <= 2'b01;
    end
  end

  // routing según dirección
  always @* begin
    left  = 2'b00;
    right = 2'b00;
    case (dir)
      2'b01: begin left  = state; right = 2'b00; end // solo izquierda
      2'b10: begin left  = 2'b00; right = state; end // solo derecha
      2'b11: begin left  = state; right = state; end // ambos (hazard progresivo)
      default: begin left = 2'b00; right = 2'b00; end
    endcase
  end
endmodule

// ============================ decoder ==========================
module decoder (
  input  [1:0] in,
  output reg [2:0] out
);
  always @* begin
    case (in)
      2'b00: out = 3'b000;
      2'b01: out = 3'b001;
      2'b10: out = 3'b011;
      2'b11: out = 3'b111;
      default: out = 3'b000;
    endcase
  end
endmodule


// ======================= direccionales ===================
module direccionales (
  input        clk,
  input  [1:0] dir,
  output [2:0] izq,
  output [2:0] der
);
  wire [1:0] node2;   // left  state after controller
  wire [1:0] node3;   // right state after controller

  controller controller1(.dir(dir), .clk(clk), .left(node2), .right(node3));
  decoder    decoder1  (.in(node2), .out(izq));
  decoder    decoder2  (.in(node3), .out(der));
endmodule