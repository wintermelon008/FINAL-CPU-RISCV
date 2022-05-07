`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/05/06 15:20:23
// Design Name: 
// Module Name: IM_UNIT
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
    ================================   IM_UNIT module   ================================
    Author:         Wintermelon
    Last Edit:      2022.5.6

    This is the Instruction Memory unit
    With Interrupt programs
    With Instruction Memory
*/

module IM_UNIT(
    input clk,
// DATA
    input [15:0] imu_addr,
    output [31:0] imu_dout,

// DEBUG
    input [11:0] debug_addr,
    output [31:0] debug_dout
);

// Suppose the interrupt program starts at x0---

    wire [31:0] interrupt_is, im_dout;
    wire [31:0] interrupt_debug_dout, im_debug_dout;
    wire [31:0] im_din, im_debug_addr;

    wire imu_dout_mux_sel;

    assign im_din = (imu_addr - 16'h3000) >> 2;
    assign im_debug_addr = debug_addr;

    assign imu_dout_mux_sel = (imu_addr[15:12] == 4'h0) ? 1'b1 : 1'b0;

    Instruction_MEM im (
        .clk(clk),
        .add_1(im_din),
        .data_1(32'b0),
        .we_1(1'b0),
        .radd_2(im_debug_addr),
        .out_1(im_dout), 
        .out_2(user_debug_dout)
    );

    MUX2 #(32) debug_dout_mux(
        .data1(im_debug_dout),
        .data2(32'b0),
        .sel(1'b0),
        .out(debug_dout)
    );

    MUX2 #(32) imu_dout_mux(
        .data1(im_dout),
        .data2(interrupt_is),
        .sel(imu_dout_mux_sel),
        .out(imu_dout)
    );
endmodule
