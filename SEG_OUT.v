`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/03/27 23:23:56
// Design Name: 
// Module Name: seg_out
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
    ================================   SEG_OUT module   ================================
    Author:         Wintermelon
    Last Edit:      2022.3.27

    This module will output the data on Seven-segment display. 
*/

module SEG_OUT(
    input clk,
    input rstn,
    input [31:0] data,      // The data ready to output
    output reg [7:0] an,    // Connecting segments display
    output reg [6:0] seg    // Connecting segments display
);

    // Some used variables
    reg [2:0] seg_cnt;
    reg [3:0] seg_data;
    reg [16:0] clk400;

    initial begin
        seg_cnt <= 0;
        clk400 <= 0;
    end

    always @(posedge clk or negedge rstn) begin
        if (rstn == 0) begin
            clk400 <= 0;
            seg_cnt <= 0;
        end
        else begin
            if (clk400 > 'd49999) begin
                clk400 = 'b0;
                if (seg_cnt == 'd7) begin
                    seg_cnt <= 'b0;
                end
                else
                    seg_cnt <= seg_cnt + 'b1;
            end
            else begin
                clk400 <= clk400 + 'b1;
            end
        end
    end
    
    always @(*) begin
        case (seg_cnt)
             'd0: begin an <= 8'b11111110; seg_data <= data[3:0]; end
             'd1: begin an <= 8'b11111101; seg_data <= data[7:4]; end
             'd2: begin an <= 8'b11111011; seg_data <= data[11:8]; end
             'd3: begin an <= 8'b11110111; seg_data <= data[15:12]; end
             'd4: begin an <= 8'b11101111; seg_data <= data[19:16]; end
             'd5: begin an <= 8'b11011111; seg_data <= data[23:20]; end
             'd6: begin an <= 8'b10111111; seg_data <= data[27:24]; end
             'd7: begin an <= 8'b01111111; seg_data <= data[31:28]; end
        endcase   
        case (seg_data)
            4'h0: seg <= 7'b0000001;  //0
            4'h1: seg <= 7'b1001111;  //1
            4'h2: seg <= 7'b0010010;  //2
            4'h3: seg <= 7'b0000110;  //3
            4'h4: seg <= 7'b1001100;  //4
            4'h5: seg <= 7'b0100100;  //5
            4'h6: seg <= 7'b0100000;  //6
            4'h7: seg <= 7'b0001111;  //7
            4'h8: seg <= 7'b0000000;  //8
            4'h9: seg <= 7'b0000100;  //9
            4'ha: seg <= 7'b0001000;  //A
            4'hb: seg <= 7'b1100000;  //B
            4'hc: seg <= 7'b0110001;  //C
            4'hd: seg <= 7'b1000010;  //D
            4'he: seg <= 7'b0110000;  //E
            4'hf: seg <= 7'b0111000;  //F


            default: seg <= 7'b0000001;
        endcase
    end
endmodule