`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/05/05 23:04:25
// Design Name: 
// Module Name: FAST_DIV
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
    ================================  FAST_DIV module   ================================
    Author:         Wintermelon
    Last Edit:      2022.5.6

    This is a simple but fast divide calculate module
*/

module FAST_DIV(
    input clk,  // 100 Mhz

    input [31:0] number1,
    input [31:0] number2, 

    output [31:0] ans,
    output [31:0] remind,
    output ans_ready
);

wire [63:0] dout;
assign ans = dout[63:32];
assign remind = dout[31:0];

div_gen_0 divider (
  .aclk(clk),                                       // input wire aclk
  .s_axis_divisor_tvalid(1'b1),                     // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(number2),                   // input wire [31 : 0] s_axis_divisor_tdata

  .s_axis_dividend_tvalid(1'b1),                    // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(number1),                  // input wire [31 : 0] s_axis_dividend_tdata

  .m_axis_dout_tvalid(ans_ready),                   // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(dout)                          // output wire [63 : 0] m_axis_dout_tdata
);
endmodule
