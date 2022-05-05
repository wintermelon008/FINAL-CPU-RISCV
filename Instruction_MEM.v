`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/03/28 10:40:19
// Design Name: 
// Module Name: Instruction_MEM
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
    ================================   Instruction_MEM module   ================================
    Author:         Wintermelon
    Last Edit:      2022.4.20

    This is the instruction memory.
    Use 256x32bit dist RAM
*/


module Instruction_MEM(
    input clk,
    input [11:0] add_1,
    input [31:0] data_1,
    input we_1,
    input [11:0] radd_2,
    output [31:0] out_1, out_2
);

    is_mem is_m (
    .a(add_1),        // input wire [11 : 0] a
    .d(data_1),        // input wire [31 : 0] d
    .dpra(radd_2),  // input wire [11 : 0] dpra
    .clk(clk),    // input wire clk
    .we(we_1),      // input wire we
    .spo(out_1),    // output wire [31 : 0] spo
    .dpo(out_2)    // output wire [31 : 0] dpo
    );
    
endmodule
