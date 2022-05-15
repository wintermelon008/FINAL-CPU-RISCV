`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/03/28 10:40:19
// Design Name: 
// Module Name: Data_MEM
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
    ================================   Data_MEM module   ================================
    Author:         Wintermelon
    Last Edit:      2022.4.20

    This is the data memory.
    Use 4096 x 32bit dist RAM


*/

module Data_MEM(
    input clk,
    input [31:0] add_1,
    input [31:0] data_1,
    input we_1,
    input [2:0] mode,

    input [14:0] radd_2,    // debug
    output reg [11:0] out_1, out_2,

    output reg dm_error
);


// Below is the DMU_mode list
    localparam BY_WORD = 3'h0;
    localparam BY_HALF = 3'h1;
    localparam BY_HALF_U = 3'h2;
    localparam BY_BYTE = 3'h3;
    localparam BY_BYTE_U = 4'h4;


wire dm_we, stack_we;
wire [31:0] dm_dout, stack_dout;
wire [31:0] screen_dout, stack_debug_dout;
wire [14:0] dm_addr, screen_addr;
wire [7:0] stack_addr, stack_debug_addr;

reg [31:0] din, dout;


wire [31:0] dm_din, stack_din;

// assign dm_we = (add_1 < 16'h2C00 && we_1 == 1'b1) ? 1'b1 : 1'b0;
assign dm_we = we_1;
// assign stack_we = (add_1[15:10] == 6'b001011 && we_1 == 1'b1) ? 1'b1 : 1'b0;

assign dm_addr = add_1[14:0];
assign screen_addr = radd_2[14:0];

assign dm_din = din[11:0];

// assign stack_addr = ((add_1 - 16'h2C00) >> 2);
// assign stack_debug_addr = radd_2[7:0];
// assign stack_din = din;

    // data_mem data_m (
    //     .a(dm_addr),        // input wire [11 : 0] a
    //     .d(dm_din),        // input wire [31 : 0] d
    //     .dpra(screen_addr),  // input wire [11 : 0] dpra
    //     .clk(clk),    // input wire clk
    //     .we(dm_we),      // input wire we
    //     .spo(dm_dout),    // output wire [31 : 0] spo
    //     .dpo(screen_dout)    // output wire [31 : 0] dpo
    // );

//     data_mem your_instance_name (
//   .a(a),        // input wire [14 : 0] a
//   .d(d),        // input wire [11 : 0] d
//   .dpra(dpra),  // input wire [14 : 0] dpra
//   .clk(clk),    // input wire clk
//   .we(we),      // input wire we
//   .spo(spo),    // output wire [11 : 0] spo
//   .dpo(dpo)    // output wire [11 : 0] dpo
// );

screen_data dm_block (
    .clka(clk),    // input wire clka
    .wea(dm_we),      // input wire [0 : 0] wea
    .addra(dm_addr),  // input wire [14 : 0] addra
    .dina(dm_din),    // input wire [11 : 0] dina
    .douta(dm_dout),

    .clkb(slow_clk),    // input wire clkb
    .enb(1'b1),
    .addrb(screen_addr),  // input wire [14 : 0] addrb
    .web(1'b0),
    .dinb(12'b0),
    .doutb(screen_dout),  // output wire [11 : 0] doutb

);
//   .clka(clka),    // input wire clka
//   .wea(wea),      // input wire [0 : 0] wea
//   .addra(addra),  // input wire [14 : 0] addra
//   .dina(dina),    // input wire [11 : 0] dina
//   .douta(douta),  // output wire [11 : 0] douta

//   .clkb(clkb),    // input wire clkb
//   .enb(enb),      // input wire enb
//   .web(web),      // input wire [0 : 0] web
//   .addrb(addrb),  // input wire [14 : 0] addrb
//   .dinb(dinb),    // input wire [11 : 0] dinb
//   .doutb(doutb)  // output wire [11 : 0] doutb

    // user_stack stack_m (
    //     .a(stack_addr),        // input wire [7 : 0] a
    //     .d(stack_din),        // input wire [31 : 0] d
    //     .dpra(stack_debug_addr),  // input wire [7 : 0] dpra
    //     .clk(clk),    // input wire clk
    //     .we(stack_we),      // input wire we
    //     .spo(stack_dout),    // output wire [31 : 0] spo
    //     .dpo(stack_debug_dout)    // output wire [31 : 0] dpo
    // );

always @(*) begin
    // store data
    din = data_1;
    case (mode)
        BY_WORD: begin
            din = data_1;
        end

        BY_HALF: begin
            if (data_1[15] == 1'b1)
                din = {{16{1'b1}}, {data_1[15:0]}};
            else
                din = {{16{1'b0}}, {data_1[15:0]}};
        end

        BY_BYTE: begin
            if (data_1[7] == 1'b1)
                din = {{24{1'b1}}, {data_1[7:0]}};
            else
                din = {{24{1'b0}}, {data_1[7:0]}};
        end

    endcase
end

always @(*) begin
    // load data
    out_1 = dout;
    case (mode)
        BY_WORD: begin
            out_1 = dout;
        end

        BY_BYTE: begin
            if (dout[7] == 1'b1)
                out_1 = {{24{1'b1}}, {dout[7:0]}};
            else
                out_1 = {{24{1'b0}}, {dout[7:0]}};
        end

        BY_BYTE_U: begin
            out_1 = {{24'b0}, {dout[7:0]}};
        end

        BY_HALF: begin
            if (dout[15] == 1'b1)
                out_1 = {{16{1'b1}}, {dout[15:0]}};
            else
                out_1 = {{16{1'b0}}, {dout[15:0]}};
        end

        BY_HALF_U: begin
            out_1 = {{16'b0}, {dout[15:0]}};
        end
    endcase
end

// User data: From 0x0000 - 0x2BFC (2816 x 32bit) 
//         00 0000 0000 0000 00 -> 0000 0000 0000
//         00 1010 1111 1111 00 -> 1010 1111 1111

// User stack: From 0x2C00 - 0x2FFC (256 x 32bit)
//         0010 11 0000 0000 00 -> 0000 0000
//         0010 11 1111 1111 00 -> 1111 1111

always @(*) begin
    dm_error = 1'b0;
    dout = dm_dout;
    // if (add_1[15:10] == 6'b001011) begin// stack
    //     dout = stack_dout;
    // end
    // else if (add_1 < 16'h2C00) begin    // user data
    //     dout = dm_dout;
    // end
    // else begin
    //     dout = 32'h0;
        // if (we_1)
        //     dm_error = 1'b1;
        // access error
//    end
end

always @(*) begin

    out_2 = screen_dout;

end


endmodule
